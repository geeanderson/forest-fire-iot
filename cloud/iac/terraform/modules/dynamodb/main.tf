resource "aws_dynamodb_table" "sensor_readings" {
  name         = var.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "device_id"
  range_key    = "timestamp"

  attribute {
    name = "device_id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  tags = {
    Name        = var.table_name
    Project     = var.project_name
    Environment = var.environment
  }
}
