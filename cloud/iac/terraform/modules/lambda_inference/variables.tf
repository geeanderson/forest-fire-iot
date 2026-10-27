variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "source_image" {
  description = "Public inference image (model included) copied to ECR on apply"
  type        = string
}
