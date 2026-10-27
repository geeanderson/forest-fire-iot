output "topic_arn" {
  description = "ARN of the SNS topic for fire risk alerts"
  value       = aws_sns_topic.fire_alerts.arn
}

output "topic_name" {
  description = "Name of the SNS topic for fire risk alerts"
  value       = aws_sns_topic.fire_alerts.name
}
