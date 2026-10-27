output "lambda_process_sensor_arn" {
  description = "ARN of the process_sensor_data Lambda function"
  value       = module.lambda.process_sensor_data_arn
}

output "lambda_process_sensor_name" {
  description = "Name of the process_sensor_data Lambda function"
  value       = module.lambda.process_sensor_data_name
}

output "lambda_role_arn" {
  description = "ARN of the IAM role used by the process_sensor_data Lambda"
  value       = module.lambda.lambda_role_arn
}

output "iot_endpoint" {
  description = "AWS IoT Core endpoint (already included in the gateway_aws_config output)"
  value       = module.iot_core.iot_endpoint
}

output "thing_arns" {
  description = "ARNs of all provisioned IoT Things"
  value       = module.iot_core.thing_arns
}

output "certificate_arns" {
  description = "ARNs of all IoT certificates"
  value       = module.iot_core.certificate_arns
}

output "certificate_pems" {
  description = "Certificate PEMs for firmware provisioning (sensitive)"
  sensitive   = true
  value       = module.iot_core.certificate_pems
}

output "private_keys" {
  description = "Private keys for firmware provisioning (sensitive — store securely)"
  sensitive   = true
  value       = module.iot_core.private_keys
}

output "iot_policy_arn" {
  description = "ARN of the shared IoT sensor policy"
  value       = module.iot_core.iot_policy_arn
}

output "topic_rule_arn" {
  description = "ARN of the IoT topic rule routing sensor data to Lambda"
  value       = module.iot_core.topic_rule_arn
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table storing sensor readings"
  value       = module.dynamodb.table_name
}

output "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table storing sensor readings"
  value       = module.dynamodb.table_arn
}

output "s3_bucket_raw_name" {
  description = "Name of the S3 bucket for raw sensor data archival"
  value       = module.s3.bucket_name
}

output "s3_bucket_raw_arn" {
  description = "ARN of the S3 bucket for raw sensor data archival"
  value       = module.s3.bucket_arn
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic used for fire risk alert notifications"
  value       = module.sns.topic_arn
}

output "fire_alert_lambda_arn" {
  description = "ARN of the fire_alert Lambda function"
  value       = module.lambda.fire_alert_arn
}

output "fire_alert_topic_rule_arn" {
  description = "ARN of the IoT topic rule that triggers fire_alert on critical readings"
  value       = module.iot_core.fire_alert_topic_rule_arn
}

output "lambda_inference_ecr_url" {
  description = "ECR repository URL for the Lambda inference container image"
  value       = module.lambda_inference.ecr_repository_url
}

output "lambda_inference_function_name" {
  description = "Lambda inference function name"
  value       = module.lambda_inference.lambda_function_name
}

output "aws_region" {
  description = "AWS region"
  value       = var.aws_region
}
