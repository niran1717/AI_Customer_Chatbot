# Configure the AWS Provider
provider "aws" {
  region = var.aws_region
}

# -----------------------------------------------------------------------------
# 1. DynamoDB Table for storing conversations
# -----------------------------------------------------------------------------
resource "aws_dynamodb_table" "chatbot_conversations" {
  name             = var.dynamodb_table_name
  billing_mode     = "PAY_PER_REQUEST" # Free tier friendly (on-demand)
  hash_key         = "chat_id"
  range_key        = "timestamp" # Sort key for conversation order

  attribute {
    name = "chat_id"
    type = "S" # String
  }
  attribute {
    name = "timestamp"
    type = "S" # String
  }

  tags = {
    Project = "AICustomerChatbot"
  }
}

# -----------------------------------------------------------------------------
# 2. IAM Role for Lambda (with access to DynamoDB & Bedrock)
# -----------------------------------------------------------------------------

# IAM Policy for Lambda to assume role
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# IAM Role for Lambda function
resource "aws_iam_role" "lambda_execution_role" {
  name               = "${var.lambda_function_name}-ExecutionRole"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  tags = {
    Project = "AICustomerChatbot"
  }
}

# IAM Policy for Lambda to write logs to CloudWatch
resource "aws_iam_role_policy_attachment" "lambda_cloudwatch_policy" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# IAM Policy for Lambda to access DynamoDB
data "aws_iam_policy_document" "dynamodb_access_policy" {
  statement {
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:Query",
      "dynamodb:UpdateItem", # Added for completeness, though not strictly used in current code
      "dynamodb:DeleteItem"  # Added for completeness
    ]
    resources = [aws_dynamodb_table.chatbot_conversations.arn]
  }
}

resource "aws_iam_role_policy" "dynamodb_access" {
  name   = "${var.lambda_function_name}-DynamoDBAccess"
  role   = aws_iam_role.lambda_execution_role.id
  policy = data.aws_iam_policy_document.dynamodb_access_policy.json
}

# IAM Policy for Lambda to invoke Bedrock
data "aws_iam_policy_document" "bedrock_invoke_policy" {
  statement {
    actions = ["bedrock:InvokeModel"]
    resources = ["arn:${data.aws_partition.current.partition}:bedrock:${var.aws_region}::foundation-model/${var.bedrock_model_id}"]
  }
}

resource "aws_iam_role_policy" "bedrock_invoke" {
  name   = "${var.lambda_function_name}-BedrockInvoke"
  role   = aws_iam_role.lambda_execution_role.id
  policy = data.aws_iam_policy_document.bedrock_invoke_policy.json
}

# -----------------------------------------------------------------------------
# 3. Lambda Function
# -----------------------------------------------------------------------------

resource "aws_lambda_function" "chatbot_handler" {
  function_name    = var.lambda_function_name
  handler          = "lambda_function.lambda_handler" # File name . handler function name
  runtime          = "python3.9" # Or python3.10 based on your preference
  role             = aws_iam_role.lambda_execution_role.arn
  timeout          = 30 # seconds
  memory_size      = 256 # MB

  # Use a local file for the deployment package
  filename         = var.lambda_zip_path
  source_code_hash = filebase64sha256(var.lambda_zip_path) # Auto-updates on file change

  environment {
    variables = {
      DYNAMODB_TABLE_NAME = aws_dynamodb_table.chatbot_conversations.name
      BEDROCK_MODEL_ID    = var.bedrock_model_id
    }
  }

  tags = {
    Project = "AICustomerChatbot"
  }
}

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.chatbot_handler.function_name}"
  retention_in_days = 7 # Adjust retention as needed (e.g., 30, 90, 365)

  tags = {
    Project = "AICustomerChatbot"
  }
}

# -----------------------------------------------------------------------------
# 5. Create API Gateway REST API to expose Lambda
# 6. Connect API Gateway -> Lambda
# -----------------------------------------------------------------------------

resource "aws_api_gateway_rest_api" "chatbot_api" {
  name        = var.api_gateway_name
  description = "API for AI Customer Chatbot Lambda function"

  tags = {
    Project = "AICustomerChatbot"
  }
}

# API Gateway Resource (/chat)
resource "aws_api_gateway_resource" "chat_resource" {
  rest_api_id = aws_api_gateway_rest_api.chatbot_api.id
  parent_id   = aws_api_gateway_rest_api.chatbot_api.root_resource_id
  path_part   = "chat"
}

# API Gateway POST Method
resource "aws_api_gateway_method" "chat_post_method" {
  rest_api_id   = aws_api_gateway_rest_api.chatbot_api.id
  resource_id   = aws_api_gateway_resource.chat_resource.id
  http_method   = "POST"
  authorization = "NONE" # No authorization for public chatbot
}

# API Gateway Integration with Lambda (Proxy Integration)
resource "aws_api_gateway_integration" "chat_lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.chatbot_api.id
  resource_id             = aws_api_gateway_resource.chat_resource.id
  http_method             = aws_api_gateway_method.chat_post_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY" # Crucial for Lambda Proxy Integration
  uri                     = aws_lambda_function.chatbot_handler.invoke_arn
}

# Permission for API Gateway to invoke Lambda
resource "aws_lambda_permission" "api_gateway_lambda_permission" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.chatbot_handler.function_name
  principal     = "apigateway.amazonaws.com"
  # The /*/* part is very important. It tells the Lambda function
  # that it can be invoked by any API Gateway method on any resource
  # within the specified API.
  source_arn    = "${aws_api_gateway_rest_api.chatbot_api.execution_arn}/*/*"
}

# API Gateway OPTIONS Method (for CORS preflight)
resource "aws_api_gateway_method" "chat_options_method" {
  rest_api_id   = aws_api_gateway_rest_api.chatbot_api.id
  resource_id   = aws_api_gateway_resource.chat_resource.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

# API Gateway Integration for OPTIONS (CORS)
resource "aws_api_gateway_integration" "chat_options_integration" {
  rest_api_id = aws_api_gateway_rest_api.chatbot_api.id
  resource_id = aws_api_gateway_resource.chat_resource.id
  http_method = aws_api_gateway_method.chat_options_method.http_method
  type        = "MOCK" # MOCK integration for CORS preflight
  request_templates = {
    "application/json" = "{ \"statusCode\": 200 }"
  }
}

# API Gateway Method Response for OPTIONS (CORS)
resource "aws_api_gateway_method_response" "chat_options_method_response" {
  rest_api_id = aws_api_gateway_rest_api.chatbot_api.id
  resource_id = aws_api_gateway_resource.chat_resource.id
  http_method = aws_api_gateway_method.chat_options_method.http_method
  status_code = "200"
  response_models = {
    "application/json" = "Empty"
  }
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

# API Gateway Integration Response for OPTIONS (CORS)
resource "aws_api_gateway_integration_response" "chat_options_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.chatbot_api.id
  resource_id = aws_api_gateway_resource.chat_resource.id
  http_method = aws_api_gateway_method.chat_options_method.http_method
  status_code = aws_api_gateway_method_response.chat_options_method_response.status_code

  response_templates = {
    "application/json" = ""
  }
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'OPTIONS,POST'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'" # IMPORTANT: Change to your frontend domain in production
  }
}

# API Gateway Deployment
resource "aws_api_gateway_deployment" "chatbot_deployment" {
  rest_api_id = aws_api_gateway_rest_api.chatbot_api.id
  # This creates a new deployment whenever the API definition changes
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.chat_resource.id,
      aws_api_gateway_method.chat_post_method.id,
      aws_api_gateway_integration.chat_lambda_integration.id,
      aws_api_gateway_method.chat_options_method.id,
      aws_api_gateway_integration.chat_options_integration.id,
      aws_api_gateway_method_response.chat_options_method_response.id,
      aws_api_gateway_integration_response.chat_options_integration_response.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

# API Gateway Stage
resource "aws_api_gateway_stage" "chatbot_stage" {
  deployment_id = aws_api_gateway_deployment.chatbot_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.chatbot_api.id
  stage_name    = var.api_gateway_stage_name

  # Enable CloudWatch logging for API Gateway
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway_log_group.arn
    format          = jsonencode({
      requestId               = "$context.requestId"
      ip                      = "$context.identity.sourceIp"
      caller                  = "$context.identity.caller"
      user                    = "$context.identity.user"
      requestTime             = "$context.requestTime"
      httpMethod              = "$context.httpMethod"
      resourcePath            = "$context.resourcePath"
      status                  = "$context.status"
      protocol                = "$context.protocol"
      responseLength          = "$context.responseLength"
      responseLatency         = "$context.responseLatency"
      integrationLatency      = "$context.integrationLatency"
      integrationStatus       = "$context.integrationStatus"
      errorMessage            = "$context.error.message"
      validationErrorString   = "$context.error.validationErrorString"
    })
  }

  variables = {
    # You can pass stage variables to Lambda if needed, e.g., "ENV" = "dev"
  }

  tags = {
    Project = "AICustomerChatbot"
  }
}

# CloudWatch Log Group for API Gateway
resource "aws_cloudwatch_log_group" "api_gateway_log_group" {
  name              = "/aws/api-gateway/${aws_api_gateway_rest_api.chatbot_api.name}/${var.api_gateway_stage_name}"
  retention_in_days = 7 # Adjust retention as needed

  tags = {
    Project = "AICustomerChatbot"
  }
}


# -----------------------------------------------------------------------------
# 8. Create SNS alert if errors occur
# -----------------------------------------------------------------------------

# SNS Topic for error alerts
resource "aws_sns_topic" "chatbot_error_alerts" {
  name = "ChatbotErrorAlerts"

  tags = {
    Project = "AICustomerChatbot"
  }
}

# SNS Topic Subscription (Email)
resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.chatbot_error_alerts.arn
  protocol  = "email"
  endpoint  = var.sns_notification_email
  # You will still need to confirm this subscription via email after apply
}

# CloudWatch Alarm for Lambda errors
resource "aws_cloudwatch_metric_alarm" "lambda_error_alarm" {
  alarm_name          = "ChatbotLambdaErrorAlarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60 # 1 minute
  statistic           = "Sum"
  threshold           = 1
  treat_missing_data  = "notBreaching" # Treat missing data as not breaching

  dimensions = {
    FunctionName = aws_lambda_function.chatbot_handler.function_name
  }

  alarm_actions = [aws_sns_topic.chatbot_error_alerts.arn]
  ok_actions    = [aws_sns_topic.chatbot_error_alerts.arn]

  tags = {
    Project = "AICustomerChatbot"
  }
}

# Data source for current AWS partition, used for ARN construction
data "aws_partition" "current" {}
