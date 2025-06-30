# 🤖 AI Customer Service Chatbot on AWS

Welcome to the **AI-Powered Customer Service Chatbot** project. This project demonstrates a fully serverless, intelligent customer service assistant built entirely on **AWS services**, leveraging **Amazon Bedrock**, **Lambda**, **DynamoDB**, **API Gateway**, and more.

---

## 🚀 Project Objective

Deliver a **context-aware, scalable, and secure AI chatbot** that can:
- Respond to customer queries using historical context and company-specific tone
- Incorporate business rules and restrictions
- Support monitoring, alerting, and analytics
- Scale without server maintenance

This is ideal for **customer support**, **product inquiry handling**, and **feedback automation**.

---

## 🧱 Architecture Overview

The architecture follows a modular, microservice pattern using serverless components.

![Architecture Diagram](./assets/AI_Chatbot.png)

---

## 🧪 Step-by-Step Deployment Process (with Screenshots)

### ✅ Step 1: Create DynamoDB Table
- Table name: `ChatHistory`
- Partition key: `chat_id` (String)
- Sort key: `timestamp` (String)
![DynamoDB table](./assets/dynamodb-chat-history.png)

---

### ✅ Step 2: Create IAM Role for Lambda
- Role name: `lambda-chatbot-role`
- Attach policies: `AmazonDynamoDBFullAccess`, `AmazonBedrockFullAccess`, `CloudWatchLogsFullAccess`
![IAM Role](./assets/iam-lambda-role.png)

---

### ✅ Step 3: Create Lambda Function
- Runtime: Python 3.12
- Role: `lambda-chatbot-role`
- Paste chatbot handler code with Bedrock and DynamoDB integration
![Lambda Created](./assets/lambda-function-created.png)
![Lambda Code](./assets/lambda-code.png)

---

### ✅ Step 4: Test Lambda Function
- Sample test event:
```json
{
  "chat_id": "user1",
  "message": "What are your business hours?"
}
```
- Expected: Claude response + DynamoDB entry
![Lambda Test](./assets/lambda-test-success.png)

---

### ✅ Step 5: Create API Gateway
- Type: HTTP API
- Connect to Lambda trigger
![API Gateway Created](./assets/apigateway-created.png)
![Endpoint](./assets/apigateway-endpoint.png)

---

### ✅ Step 6: Request Model Access in Bedrock
- Model ID: `anthropic.claude-instant-v1` (in `us-east-1`)
![Model Access](./assets/bedrock-access-request.png)

---

## 📁 Folder Structure

```
/AI_Customer_Chatbot/
│
├── assets/
│   ├── dynamodb-chat-history.png
│   ├── iam-lambda-role.png
│   ├── lambda-function-created.png
│   ├── lambda-code.png
│   ├── lambda-test-success.png
│   ├── apigateway-created.png
│   ├── apigateway-endpoint.png
│   ├── bedrock-access-request.png
│   └── AI_Chatbot.png
│
├── lambda/
│   └── chatbot_handler.py       # Core chatbot logic
│
├── frontend/
│   └── index.html               # Optional simple frontend
│
├── terraform/
│   └── main.tf                  # (Optional) Infrastructure as code
│
└── README.md
```

---

## 🧠 Components Used

| Service | Role |
|--------|------|
| **API Gateway** | Accepts user messages |
| **Lambda** | Processes and responds |
| **DynamoDB** | Stores conversation history |
| **Amazon Bedrock** | Generates responses (Claude Instant) |
| **CloudWatch** | Logs Lambda executions |
| **SNS** | Alerts on failure |

---

## 🧪 Testing

- ✅ Test via Postman or HTML form
- ✅ Inspect DynamoDB for stored messages
- ✅ View Lambda logs in CloudWatch

---

## 🧬 Next Steps

- Add authentication via Cognito (optional)
- Add log analytics using Athena + QuickSight
- Deploy with Terraform/CDK
- Set up alerting and metric dashboards

---

## 📬 Contributions

Feel free to fork, raise issues, or send PRs!

---

© 2025 – AI Customer Chatbot powered by AWS