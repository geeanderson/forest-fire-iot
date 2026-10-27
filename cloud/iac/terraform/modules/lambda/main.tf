locals {
  function_name   = "${var.project_name}-${var.environment}-process-sensor-data"
  log_group_name  = "/aws/lambda/${local.function_name}"
  source_dir      = "${path.module}/../../../../lambda/process_sensor_data"
  zip_output_path = "${path.module}/builds/process_sensor_data.zip"

  fire_alert_function_name = "${var.project_name}-${var.environment}-fire-alert"
  fire_alert_log_group     = "/aws/lambda/${local.fire_alert_function_name}"
  fire_alert_source_dir    = "${path.module}/../../../../lambda/fire_alert"
  fire_alert_zip_path      = "${path.module}/builds/fire_alert.zip"
}

data "archive_file" "process_sensor_data" {
  type        = "zip"
  source_dir  = local.source_dir
  output_path = local.zip_output_path
  excludes    = ["requirements.txt", "__pycache__", "*.pyc"]
}

# --- IAM Role ---

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "process_sensor_data" {
  name               = "${local.function_name}-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy" "process_sensor_data" {
  name = "${local.function_name}-policy"
  role = aws_iam_role.process_sensor_data.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["dynamodb:PutItem", "dynamodb:Query"]
        Resource = "arn:aws:dynamodb:${var.aws_region}:*:table/${var.dynamodb_table_name}"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = "${var.s3_bucket_raw_arn}/raw/*"
      },
      {
        Effect   = "Allow"
        Action   = ["lambda:InvokeFunction"]
        Resource = "arn:aws:lambda:${var.aws_region}:*:function:${var.lambda_inference_function_name}"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:*:log-group:${local.log_group_name}:*"
      }
    ]
  })
}

# --- fire_alert: archive, IAM, log group, function ---

data "archive_file" "fire_alert" {
  type        = "zip"
  source_dir  = local.fire_alert_source_dir
  output_path = local.fire_alert_zip_path
  excludes    = ["requirements.txt", "__pycache__", "*.pyc"]
}

resource "aws_iam_role" "fire_alert" {
  name               = "${local.fire_alert_function_name}-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy" "fire_alert" {
  name = "${local.fire_alert_function_name}-policy"
  role = aws_iam_role.fire_alert.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["sns:Publish"]
        Resource = var.sns_topic_arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:*:log-group:${local.fire_alert_log_group}:*"
      }
    ]
  })
}

# --- CloudWatch Log Group ---

resource "aws_cloudwatch_log_group" "process_sensor_data" {
  name              = local.log_group_name
  retention_in_days = 7
}

# --- Lambda Function ---

resource "aws_lambda_function" "process_sensor_data" {
  function_name    = local.function_name
  filename         = data.archive_file.process_sensor_data.output_path
  source_code_hash = data.archive_file.process_sensor_data.output_base64sha256
  role             = aws_iam_role.process_sensor_data.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.11"
  timeout          = 30
  memory_size      = 128

  environment {
    variables = {
      DYNAMODB_TABLE            = var.dynamodb_table_name
      S3_BUCKET_RAW             = var.s3_bucket_raw_name
      LAMBDA_INFERENCE_FUNCTION = var.lambda_inference_function_name
      NTFY_TOPIC                = var.ntfy_topic
      DEVICE_LOCATIONS          = jsonencode(var.device_locations)
    }
  }

  depends_on = [aws_cloudwatch_log_group.process_sensor_data]
}

resource "aws_cloudwatch_log_group" "fire_alert" {
  name              = local.fire_alert_log_group
  retention_in_days = 7
}

resource "aws_lambda_function" "fire_alert" {
  function_name    = local.fire_alert_function_name
  filename         = data.archive_file.fire_alert.output_path
  source_code_hash = data.archive_file.fire_alert.output_base64sha256
  role             = aws_iam_role.fire_alert.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.11"
  timeout          = 30
  memory_size      = 128

  environment {
    variables = {
      SNS_TOPIC_ARN         = var.sns_topic_arn
      THRESHOLD_TEMPERATURE = "45"
      THRESHOLD_HUMIDITY    = "15"
      THRESHOLD_AIR_QUALITY = "500"
    }
  }

  depends_on = [aws_cloudwatch_log_group.fire_alert]
}
