variable "project_name" {
  description = "Project name used as prefix for resource names"
  type        = string
  default     = "forest-fire-iot"
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region for Lambda and related resources"
  type        = string
  default     = "us-east-1"
}

variable "dynamodb_table_name" {
  description = "DynamoDB table name where sensor readings are stored"
  type        = string
  default     = "forest-fire-readings"
}

variable "s3_bucket_raw_name" {
  description = "S3 bucket name for raw sensor data archival"
  type        = string
}

variable "s3_bucket_raw_arn" {
  description = "ARN of the S3 bucket used for raw sensor data archival"
  type        = string
}

variable "sns_topic_arn" {
  description = "ARN of the SNS topic used by fire_alert to publish fire risk notifications"
  type        = string
}

variable "lambda_inference_function_name" {
  description = "Name of the fire risk inference Lambda"
  type        = string
  default     = ""
}

variable "ntfy_topic" {
  description = "ntfy.sh topic for push notifications on each sensor reading written to DynamoDB. Empty string disables it."
  type        = string
  default     = ""
}

variable "monitored_nodes" {
  description = "Node IDs with a silent-node alarm (no packet stored for 2 h)"
  type        = list(string)
  default     = []
}

variable "device_locations" {
  description = "Position [lat, lon] of each node, passed as JSON in DEVICE_LOCATIONS"
  type        = map(list(number))
  default     = {}
}
