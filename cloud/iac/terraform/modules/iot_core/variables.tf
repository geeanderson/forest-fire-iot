variable "aws_region" {
  description = "AWS region for IoT Core resources"
  type        = string
  default     = "us-east-1"
}

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

variable "lambda_process_sensor_arn" {
  description = "ARN of the Lambda function that processes sensor data"
  type        = string
}

variable "lambda_fire_alert_arn" {
  description = "ARN of the Lambda function that handles fire risk alerts"
  type        = string
}
