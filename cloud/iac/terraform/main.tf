terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

module "dynamodb" {
  source = "./modules/dynamodb"

  project_name = var.project_name
  environment  = var.environment
  table_name   = var.dynamodb_table_name
}

module "s3" {
  source = "./modules/s3"

  project_name = var.project_name
  environment  = var.environment
  bucket_name  = "${var.project_name}-raw-${var.environment}"
}

module "sns" {
  source = "./modules/sns"

  project_name = var.project_name
  environment  = var.environment
  alert_email  = var.alert_email
}

module "lambda_inference" {
  source = "./modules/lambda_inference"

  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region
  source_image = var.inference_image
}

module "lambda" {
  source = "./modules/lambda"

  project_name                   = var.project_name
  environment                    = var.environment
  aws_region                     = var.aws_region
  dynamodb_table_name            = module.dynamodb.table_name
  s3_bucket_raw_name             = module.s3.bucket_name
  s3_bucket_raw_arn              = module.s3.bucket_arn
  sns_topic_arn                  = module.sns.topic_arn
  lambda_inference_function_name = module.lambda_inference.lambda_function_name
  device_locations               = { for id, n in var.nodes : id => [n.lat, n.lon] }
  monitored_nodes                = keys(var.nodes)
  ntfy_topic                     = var.ntfy_topic
}

module "iot_core" {
  source = "./modules/iot_core"

  aws_region                = var.aws_region
  project_name              = var.project_name
  environment               = var.environment
  lambda_process_sensor_arn = module.lambda.process_sensor_data_arn
  lambda_fire_alert_arn     = module.lambda.fire_alert_arn
}

