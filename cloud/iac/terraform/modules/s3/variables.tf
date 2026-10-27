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

variable "bucket_name" {
  description = "S3 bucket name for raw sensor data (must be globally unique)"
  type        = string
}

variable "raw_retention_days" {
  description = "Number of days before objects under raw/ prefix are expired"
  type        = number
  default     = 90
}
