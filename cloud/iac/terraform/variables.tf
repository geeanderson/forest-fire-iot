variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used as prefix across all resources"
  type        = string
  default     = "forest-fire-iot"
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "dynamodb_table_name" {
  description = "DynamoDB table name for sensor readings"
  type        = string
  default     = "forest-fire-readings"
}

variable "alert_email" {
  description = "Email address to receive fire risk alert notifications (required)"
  type        = string
}

variable "inference_image" {
  description = "Ready-to-run fire risk inference image (v1 Brazil model included). Copied to your ECR on apply; do not change it unless a new version is released."
  type        = string
  default     = "docker.io/geeanderson/forest-fire-iot:brazil-v1.0.0"
}

variable "nodes" {
  description = "Sensor nodes, keyed by DEVICE_ID (firmware/site_config.h). The position is used for the days without rain and the dashboard map; each node also gets a silent-node alarm."
  type = map(object({
    lat   = number
    lon   = number
    label = optional(string)
    city  = optional(string, "")
  }))

  validation {
    condition     = length(var.nodes) > 0
    error_message = "Declare at least one node."
  }
  validation {
    condition     = alltrue([for n in values(var.nodes) : abs(n.lat) <= 90 && abs(n.lon) <= 180])
    error_message = "Each node needs lat in [-90, 90] and lon in [-180, 180]."
  }
}

variable "ntfy_topic" {
  description = "Optional ntfy.sh topic: a push notification on every stored reading. Anyone who knows the topic can read it, so pick a hard-to-guess name. Empty = disabled."
  type        = string
  default     = ""
}

variable "create_dashboard_user" {
  description = "Create a read-only IAM user (dynamodb:Query on the readings table) and its access key for the dashboard. The secret key is kept in the Terraform state. Set to false to use your own credentials."
  type        = bool
  default     = true
}
