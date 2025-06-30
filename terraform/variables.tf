# AWS Region where resources will be deployed
variable "aws_region" {
  description = "The AWS region to deploy resources in."
  type        = string
  default     = "us-east-1" # Set your desired region here
}

# DynamoDB Table Name
variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table for conversation history."
  type        = string
  default     = "ChatbotConversations"
}

# Bedrock Model ID
variable "bedrock_model_id" {
  description = "The Bedrock model ID to use for the chatbot (e.g., anthropic.claude-3-sonnet-20240229-v1:0)."
  type        = string
  default     = "anthropic.claude-3-sonnet-20240229-v1:0" # IMPORTANT: Change this to your desired Bedrock model ID
}

# Email for SNS alerts
variable "sns_notification_email" {
  description = "Email address for SNS error notifications."
  type        = string
  # IMPORTANT: Replace with your actual email address
  default     = "your-email@example.com"
}

# Path to the Lambda deployment package (ZIP file)
variable "lambda_zip_path" {
  description = "Path to the Lambda function deployment package (ZIP file)."
  type        = string
  default     = "./lambda_function.zip" # Assumes zip is in the same directory
}

# Name for the Lambda function
variable "lambda_function_name" {
  description = "Name for the Lambda function."
  type        = string
  default     = "ChatbotHandler"
}

# Name for the API Gateway API
variable "api_gateway_name" {
  description = "Name for the API Gateway REST API."
  type        = string
  default     = "AICustomerChatbotAPI"
}

# API Gateway stage name
variable "api_gateway_stage_name" {
  description = "Name for the API Gateway deployment stage."
  type        = string
  default     = "dev"
}
