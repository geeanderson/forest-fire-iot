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

variable "table_name" {
  description = "DynamoDB table name for sensor readings"
  type        = string
  default     = "forest-fire-readings"
}

variable "ttl_days" {
  description = "Number of days before items are expired via TTL"
  type        = number
  default     = 90
}
