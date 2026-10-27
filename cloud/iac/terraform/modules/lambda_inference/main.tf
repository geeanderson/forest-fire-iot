locals {
  name = "${var.project_name}-${var.environment}-fire-risk-inference"
  # One ECR tag per source image, so a new version also updates the Lambda.
  ecr_image = "${aws_ecr_repository.inference.repository_url}:${substr(sha256(var.source_image), 0, 12)}"
}

# ---------------------------------------------------------------------------
# ECR repository
# ---------------------------------------------------------------------------

resource "aws_ecr_repository" "inference" {
  name                 = "forest-fire-inference"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = false
  }
}

resource "aws_ecr_lifecycle_policy" "inference" {
  repository = aws_ecr_repository.inference.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 3 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 3
      }
      action = { type = "expire" }
    }]
  })
}

# ---------------------------------------------------------------------------
# Image copy: Docker Hub -> ECR (Lambda only runs images from ECR in the same account)
# Runs on the machine executing `tofu apply`; needs Docker running and the AWS CLI.
# ---------------------------------------------------------------------------

resource "terraform_data" "image_copy" {
  triggers_replace = [var.source_image, local.ecr_image]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -euo pipefail
      docker pull --platform linux/amd64 "$SOURCE_IMAGE"
      aws ecr get-login-password --region "$AWS_REGION" \
        | docker login --username AWS --password-stdin "$ECR_REGISTRY"
      docker tag "$SOURCE_IMAGE" "$ECR_IMAGE"
      docker push "$ECR_IMAGE"
    EOT
    environment = {
      SOURCE_IMAGE = var.source_image
      ECR_IMAGE    = local.ecr_image
      ECR_REGISTRY = split("/", aws_ecr_repository.inference.repository_url)[0]
      AWS_REGION   = var.aws_region
    }
  }
}

# ---------------------------------------------------------------------------
# IAM
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "inference" {
  name               = "${local.name}-role"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

resource "aws_iam_role_policy" "inference" {
  name = "${local.name}-policy"
  role = aws_iam_role.inference.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ]
        Resource = "arn:aws:logs:${var.aws_region}:*:log-group:/aws/lambda/${local.name}:*"
      }
    ]
  })
}

# ---------------------------------------------------------------------------
# CloudWatch Log Group
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "inference" {
  name              = "/aws/lambda/${local.name}"
  retention_in_days = 7
}

# ---------------------------------------------------------------------------
# Lambda Function (container image)
# ---------------------------------------------------------------------------

resource "aws_lambda_function" "inference" {
  function_name = local.name
  package_type  = "Image"
  image_uri     = local.ecr_image
  role          = aws_iam_role.inference.arn
  timeout       = 120
  memory_size   = 1024

  depends_on = [aws_cloudwatch_log_group.inference, terraform_data.image_copy]
}
