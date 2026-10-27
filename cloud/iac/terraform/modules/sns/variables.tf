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

variable "alert_email" {
  description = "Email address to receive fire risk alert notifications via SNS"
  type        = string
}
