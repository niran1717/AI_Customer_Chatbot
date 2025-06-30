# Output the API Gateway Invoke URL
output "api_gateway_invoke_url" {
  description = "The Invoke URL for the API Gateway Chatbot endpoint."
  value       = "${aws_api_gateway_deployment.chatbot_deployment.invoke_url}/${var.api_gateway_stage_name}/chat"
}

# Output the DynamoDB Table Name
output "dynamodb_table_name" {
  description = "The name of the DynamoDB table."
  value       = aws_dynamodb_table.chatbot_conversations.name
}

# Output the Lambda Function Name
output "lambda_function_name" {
  description = "The name of the Lambda function."
  value       = aws_lambda_function.chatbot_handler.function_name
}

# Output the SNS Topic ARN (for confirmation)
output "sns_topic_arn" {
  description = "The ARN of the SNS topic for error alerts."
  value       = aws_sns_topic.chatbot_error_alerts.arn
}
