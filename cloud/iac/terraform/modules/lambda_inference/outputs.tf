output "ecr_repository_url" {
  value = aws_ecr_repository.inference.repository_url
}

output "lambda_function_name" {
  value = aws_lambda_function.inference.function_name
}

output "lambda_function_arn" {
  value = aws_lambda_function.inference.arn
}
