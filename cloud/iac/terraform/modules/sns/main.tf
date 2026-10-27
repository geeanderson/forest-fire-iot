resource "aws_sns_topic" "fire_alerts" {
  name = "${var.project_name}-fire-alerts-${var.environment}"

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.fire_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}
