# --- Thing ---
# Only the gateway talks to AWS; the sensor nodes reach it over LoRa and need no Thing or certificate.

resource "aws_iot_thing" "gateway" {
  name = "${var.project_name}-gateway"
}

# --- Policy ---

resource "aws_iot_policy" "sensor_policy" {
  name = "${var.project_name}-${var.environment}-sensor-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "iot:Connect"
        Resource = "arn:aws:iot:${var.aws_region}:*:client/forest-fire-*"
      },
      {
        Effect = "Allow"
        Action = "iot:Publish"
        Resource = [
          "arn:aws:iot:${var.aws_region}:*:topic/forest-fire/*/sensors",
          "arn:aws:iot:${var.aws_region}:*:topic/forest-fire/*/status"
        ]
      },
      {
        Effect = "Allow"
        Action = "iot:Subscribe"
        Resource = [
          "arn:aws:iot:${var.aws_region}:*:topicfilter/forest-fire/*/sensors",
          "arn:aws:iot:${var.aws_region}:*:topicfilter/forest-fire/*/status"
        ]
      },
      {
        Effect = "Allow"
        Action = "iot:Receive"
        Resource = [
          "arn:aws:iot:${var.aws_region}:*:topic/forest-fire/*/sensors",
          "arn:aws:iot:${var.aws_region}:*:topic/forest-fire/*/status"
        ]
      }
    ]
  })
}

# --- Certificate ---
# The private key is kept in the Terraform state (read it with `tofu output -json private_keys`):
# keep the state private, or use an encrypted remote backend.

resource "aws_iot_certificate" "gateway" {
  active = true
}

# --- Policy attachments ---

resource "aws_iot_policy_attachment" "gateway" {
  policy = aws_iot_policy.sensor_policy.name
  target = aws_iot_certificate.gateway.arn
}

# --- Thing-certificate attachments ---

resource "aws_iot_thing_principal_attachment" "gateway" {
  thing     = aws_iot_thing.gateway.name
  principal = aws_iot_certificate.gateway.arn
}

# --- IoT Rule: route sensor data to Lambda ---

data "aws_iam_policy_document" "iot_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["iot.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "iot_rule_role" {
  name               = "${var.project_name}-${var.environment}-iot-rule-role"
  assume_role_policy = data.aws_iam_policy_document.iot_assume_role.json
}

resource "aws_iam_role_policy" "iot_invoke_lambda" {
  name = "invoke-process-sensor-lambda"
  role = aws_iam_role.iot_rule_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "lambda:InvokeFunction"
        Resource = var.lambda_process_sensor_arn
      }
    ]
  })
}

resource "aws_iot_topic_rule" "sensor_data" {
  name        = "${replace(var.project_name, "-", "_")}_${var.environment}_sensor_data"
  description = "Route forest-fire sensor data to Lambda processor"
  enabled     = true
  sql         = "SELECT * FROM 'forest-fire/+/sensors'"
  sql_version = "2016-03-23"

  lambda {
    function_arn = var.lambda_process_sensor_arn
  }

  error_action {
    cloudwatch_logs {
      log_group_name = "/aws/iot/${var.project_name}/${var.environment}/errors"
      role_arn       = aws_iam_role.iot_rule_role.arn
    }
  }
}

# Allow IoT Rules Engine to invoke the Lambda function
resource "aws_lambda_permission" "iot_invoke" {
  statement_id  = "AllowIoTRuleInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_process_sensor_arn
  principal     = "iot.amazonaws.com"
  source_arn    = aws_iot_topic_rule.sensor_data.arn
}

# --- IoT Rule: fire alert (conditional — only when thresholds exceeded) ---

resource "aws_iam_role" "iot_fire_alert_role" {
  name               = "${var.project_name}-${var.environment}-iot-fire-alert-role"
  assume_role_policy = data.aws_iam_policy_document.iot_assume_role.json
}

resource "aws_iam_role_policy" "iot_invoke_fire_alert" {
  name = "invoke-fire-alert-lambda"
  role = aws_iam_role.iot_fire_alert_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "lambda:InvokeFunction"
        Resource = var.lambda_fire_alert_arn
      }
    ]
  })
}

resource "aws_iot_topic_rule" "fire_alert_rule" {
  name        = "${replace(var.project_name, "-", "_")}_${var.environment}_fire_alert"
  description = "Invoke fire_alert Lambda when sensor readings exceed critical thresholds"
  enabled     = true
  sql         = "SELECT * FROM 'forest-fire/+/sensors' WHERE (temperature > 45 OR (humidity < 15 AND humidity >= 0) OR air_quality > 500) AND temperature <> -1 AND humidity <> -1"
  sql_version = "2016-03-23"

  lambda {
    function_arn = var.lambda_fire_alert_arn
  }

  error_action {
    cloudwatch_logs {
      log_group_name = "/aws/iot/${var.project_name}/${var.environment}/errors"
      role_arn       = aws_iam_role.iot_fire_alert_role.arn
    }
  }
}

resource "aws_lambda_permission" "iot_invoke_fire_alert" {
  statement_id  = "AllowIoTFireAlertRuleInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_fire_alert_arn
  principal     = "iot.amazonaws.com"
  source_arn    = aws_iot_topic_rule.fire_alert_rule.arn
}
