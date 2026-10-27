output "process_sensor_data_arn" {
  description = "ARN of the process_sensor_data Lambda function"
  value       = aws_lambda_function.process_sensor_data.arn
}

output "process_sensor_data_name" {
  description = "Name of the process_sensor_data Lambda function"
  value       = aws_lambda_function.process_sensor_data.function_name
}

output "lambda_role_arn" {
  description = "ARN of the IAM role attached to the process_sensor_data Lambda"
  value       = aws_iam_role.process_sensor_data.arn
}

output "fire_alert_arn" {
  description = "ARN of the fire_alert Lambda function"
  value       = aws_lambda_function.fire_alert.arn
}

output "fire_alert_name" {
  description = "Name of the fire_alert Lambda function"
  value       = aws_lambda_function.fire_alert.function_name
}
