data "aws_iot_endpoint" "current" {
  endpoint_type = "iot:Data-ATS"
}

output "iot_endpoint" {
  description = "AWS IoT Core data endpoint (used by the gateway_aws_config output)"
  value       = data.aws_iot_endpoint.current.endpoint_address
}

output "thing_arns" {
  description = "ARNs of all provisioned IoT Things"
  value       = { "gateway" = aws_iot_thing.gateway.arn }
}

output "certificate_arns" {
  description = "ARNs of all IoT certificates (one per Thing)"
  value       = { "gateway" = aws_iot_certificate.gateway.arn }
}

output "certificate_pems" {
  description = "Certificate PEM data for each Thing (write to .cert.pem files for firmware)"
  sensitive   = true
  value       = { "gateway" = aws_iot_certificate.gateway.certificate_pem }
}

output "private_keys" {
  description = "Private key PEM for each Thing — store securely, never commit to git"
  sensitive   = true
  value       = { "gateway" = aws_iot_certificate.gateway.private_key }
}

output "iot_policy_arn" {
  description = "ARN of the shared IoT policy"
  value       = aws_iot_policy.sensor_policy.arn
}

output "topic_rule_arn" {
  description = "ARN of the IoT topic rule that routes sensor data to Lambda"
  value       = aws_iot_topic_rule.sensor_data.arn
}

output "fire_alert_topic_rule_arn" {
  description = "ARN of the IoT topic rule that triggers the fire_alert Lambda on critical readings"
  value       = aws_iot_topic_rule.fire_alert_rule.arn
}
