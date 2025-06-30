import json
import os
import boto3
from datetime import datetime
import uuid

# Initialize AWS clients
# Make sure your Lambda execution role has permissions for Bedrock and DynamoDB
bedrock_runtime = boto3.client(service_name='bedrock-runtime', region_name='us-east-1') # Adjust region if needed
dynamodb = boto3.resource('dynamodb', region_name='us-east-1') # Adjust region if needed

# Retrieve environment variables
DYNAMODB_TABLE_NAME = os.environ.get('DYNAMODB_TABLE_NAME')
BEDROCK_MODEL_ID = os.environ.get('BEDROCK_MODEL_ID')

# Ensure environment variables are set
if not DYNAMODB_TABLE_NAME:
    raise ValueError("DYNAMODB_TABLE_NAME environment variable is not set.")
if not BEDROCK_MODEL_ID:
    raise ValueError("BEDROCK_MODEL_ID environment variable is not set.")

table = dynamodb.Table(DYNAMODB_TABLE_NAME)

def retrieve_conversation_history(chat_id): # Changed parameter name to chat_id
    """
    Retrieves conversation history for a given chat ID from DynamoDB.
    History is ordered by timestamp.
    """
    try:
        response = table.query(
            KeyConditionExpression=boto3.dynamodb.conditions.Key('chat_id').eq(chat_id), # Use chat_id
            ProjectionExpression='timestamp, role, content', # Only fetch necessary attributes
            ScanIndexForward=True # Sort by timestamp ascending
        )
        # Filter out any items that don't have 'role' or 'content'
        history = [
            {'role': item['role'], 'content': item['content']}
            for item in response.get('Items', [])
            if 'role' in item and 'content' in item
        ]
        print(f"Retrieved history for chat {chat_id}: {history}")
        return history
    except Exception as e:
        print(f"Error retrieving conversation history: {e}")
        return []

def store_conversation_turn(chat_id, role, content): # Changed parameter name to chat_id
    """
    Stores a single conversation turn (user or AI) in DynamoDB.
    """
    try:
        item = {
            'chat_id': chat_id, # Use chat_id as the partition key
            'messageId': str(uuid.uuid4()), # Unique ID for each message
            'timestamp': datetime.now().isoformat(), # ISO 8601 format for easy sorting
            'role': role,
            'content': content
        }
        table.put_item(Item=item)
        print(f"Stored turn: Chat: {chat_id}, Role: {role}, Content: {content[:50]}...") # Log first 50 chars
    except Exception as e:
        print(f"Error storing conversation turn: {e}")

def build_prompt(user_message, history):
    """
    Builds the prompt for the Bedrock model, incorporating conversation history.
    This example uses a simple turn-based history. For more complex models,
    you might need to format it as a list of messages.
    """
    # Example for Anthropic Claude models (Messages API format)
    # If using a different model (e.g., Titan), adjust the format accordingly.
    messages = []

    # Add system prompt (optional, but good for setting context/persona)
    # messages.append({"role": "system", "content": "You are a helpful customer support assistant."})

    for turn in history:
        messages.append({"role": turn['role'], "content": turn['content']})

    messages.append({"role": "user", "content": user_message})

    print(f"Built prompt messages: {messages}")
    return messages

def call_bedrock(prompt_messages):
    """
    Calls the Bedrock API with the constructed prompt.
    Assumes a model that supports the Messages API (e.g., Claude 3).
    Adjust payload for other models.
    """
    body = json.dumps({
        "messages": prompt_messages,
        "anthropic_version": "bedrock-2023-05-31", # Required for Anthropic models
        "max_tokens": 1000,
        "temperature": 0.7,
        "top_p": 0.9
    })

    try:
        response = bedrock_runtime.invoke_model(
            body=body,
            modelId=BEDROCK_MODEL_ID,
            accept='application/json',
            contentType='application/json'
        )
        response_body = json.loads(response.get('body').read())
        print(f"Bedrock response body: {response_body}")

        # Extract the content from the response
        if 'content' in response_body and len(response_body['content']) > 0:
            ai_response_text = response_body['content'][0]['text']
            return ai_response_text
        else:
            print("Bedrock response did not contain expected content.")
            return "I'm sorry, I couldn't generate a response."

    except Exception as e:
        print(f"Error calling Bedrock: {e}")
        # Log the full error for debugging in CloudWatch
        import traceback
        traceback.print_exc()
        return "An error occurred while processing your request. Please try again later."

def lambda_handler(event, context):
    """
    Main Lambda function handler.
    Expects a JSON payload with 'sessionId' and 'userMessage'.
    """
    print(f"Received event: {json.dumps(event)}")

    try:
        body = json.loads(event['body']) # Assuming API Gateway proxy integration
        session_id = body.get('sessionId') # This comes from the frontend/Postman

        # We will use the 'sessionId' from the frontend as the 'chat_id' for DynamoDB
        chat_id = session_id
        user_message = body.get('userMessage')

        if not chat_id or not user_message:
            return {
                'statusCode': 400,
                'headers': { 'Content-Type': 'application/json' },
                'body': json.dumps({'error': 'Missing sessionId (used as chat_id) or userMessage in request body'})
            }

        # 1. Retrieve history using chat_id
        history = retrieve_conversation_history(chat_id)

        # 2. Store user message in history using chat_id
        store_conversation_turn(chat_id, 'user', user_message)

        # 3. Build prompt (history is already in correct format)
        prompt_messages = build_prompt(user_message, history)

        # 4. Call Bedrock
        ai_response = call_bedrock(prompt_messages)

        # 5. Store AI response using chat_id
        store_conversation_turn(chat_id, 'assistant', ai_response)

        # 6. Return response
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*', # Required for CORS with API Gateway
                'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
                'Access-Control-Allow-Methods': 'OPTIONS,POST'
            },
            'body': json.dumps({
                'sessionId': session_id, # Return sessionId as expected by frontend
                'response': ai_response
            })
        }

    except json.JSONDecodeError as e:
        print(f"JSON Decode Error: {e}")
        return {
            'statusCode': 400,
            'headers': { 'Content-Type': 'application/json' },
            'body': json.dumps({'error': 'Invalid JSON in request body'})
        }
    except KeyError as e:
        print(f"Key Error: {e}")
        return {
            'statusCode': 400,
            'headers': { 'Content-Type': 'application/json' },
            'body': json.dumps({'error': f'Missing expected key in event: {e}'})
        }
    except Exception as e:
        print(f"Unhandled error: {e}")
        import traceback
        traceback.print_exc()
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*', # Required for CORS
                'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
                'Access-Control-Allow-Methods': 'OPTIONS,POST'
            },
            'body': json.dumps({'error': 'Internal server error', 'details': str(e)})
        }

