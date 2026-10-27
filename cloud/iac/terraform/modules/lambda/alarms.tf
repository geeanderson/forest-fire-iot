# CloudWatch alarms on the ingestion pipeline.
# All built from log lines that process_sensor_data already prints, so the Lambda code is unchanged.
# Windows: risk and pipeline 2 x 30 min = 1 h; per-node silence 4 x 30 min = 2 h. E-mail on ALARM and on OK via the existing SNS topic.

locals {
  alarm_prefix     = "${var.project_name}-${var.environment}"
  metric_namespace = "ForestFire"
  alarm_period     = 1800
  alarm_periods    = 4
  risk_periods     = 2
  pipeline_periods = 2
}

# --- Model risk >= 4 ---
# Matches "[lambda] fire_risk=4 p=0.2500 n=47 device_id=node-01" (also fire_risk=5).

resource "aws_cloudwatch_log_metric_filter" "high_risk" {
  name           = "${local.alarm_prefix}-high-risk-readings"
  log_group_name = aws_cloudwatch_log_group.process_sensor_data.name
  pattern        = "[mode, risk=\"fire_risk=4\" || risk=\"fire_risk=5\", p, n, device]"

  metric_transformation {
    name      = "HighRiskReadings"
    namespace = local.metric_namespace
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "high_risk" {
  alarm_name          = "${local.alarm_prefix}-fire-risk-high"
  alarm_description   = "Model fire risk >= 4 on at least one reading in the last 1 h (check the dashboard/ntfy for the node)"
  namespace           = local.metric_namespace
  metric_name         = aws_cloudwatch_log_metric_filter.high_risk.metric_transformation[0].name
  statistic           = "Sum"
  period              = local.alarm_period
  evaluation_periods  = local.risk_periods
  datapoints_to_alarm = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.sns_topic_arn]
  ok_actions          = [var.sns_topic_arn]
}

# --- Silent node: no packet stored for 2 h ---
# Matches "DynamoDB write OK — device_id=node-01 timestamp=...".

resource "aws_cloudwatch_log_metric_filter" "node_packets" {
  for_each       = toset(var.monitored_nodes)
  name           = "${local.alarm_prefix}-packets-${each.key}"
  log_group_name = aws_cloudwatch_log_group.process_sensor_data.name
  pattern        = "\"DynamoDB write OK\" \"device_id=${each.key} \""

  metric_transformation {
    name      = "PacketsStored-${each.key}"
    namespace = local.metric_namespace
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "node_silent" {
  for_each            = toset(var.monitored_nodes)
  alarm_name          = "${local.alarm_prefix}-${each.key}-silent"
  alarm_description   = "${each.key}: no packet stored for 2 h (battery, radio or link)"
  namespace           = local.metric_namespace
  metric_name         = aws_cloudwatch_log_metric_filter.node_packets[each.key].metric_transformation[0].name
  statistic           = "Sum"
  period              = local.alarm_period
  evaluation_periods  = local.alarm_periods
  datapoints_to_alarm = local.alarm_periods
  threshold           = 1
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "breaching"
  alarm_actions       = [var.sns_topic_arn]
  ok_actions          = [var.sns_topic_arn]
}

# --- Gateway or pipeline down: process_sensor_data not invoked for 1 h ---
# Every node sends every 30 min, so an hour with no packet at all means a shared failure.

resource "aws_cloudwatch_metric_alarm" "pipeline_silent" {
  alarm_name          = "${local.alarm_prefix}-pipeline-silent"
  alarm_description   = "process_sensor_data not invoked for 1 h: gateway, Wi-Fi or IoT Core rule down"
  namespace           = "AWS/Lambda"
  metric_name         = "Invocations"
  dimensions          = { FunctionName = aws_lambda_function.process_sensor_data.function_name }
  statistic           = "Sum"
  period              = local.alarm_period
  evaluation_periods  = local.pipeline_periods
  datapoints_to_alarm = local.pipeline_periods
  threshold           = 1
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "breaching"
  alarm_actions       = [var.sns_topic_arn]
  ok_actions          = [var.sns_topic_arn]
}
