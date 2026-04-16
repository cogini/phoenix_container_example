# Create IAM service role allowing ECS to call lambda hook

locals {
  name = var.name == "" ? "${var.org}-${var.app_name}-${var.env}-${var.comp}" : var.name
}

data "aws_iam_policy_document" "service-assume-role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "this" {
  dynamic "statement" {
    for_each = var.lambda_function_arns
    content {
      actions = [
        "lambda:InvokeFunction",
      ]
      resources = [statement.value]
    }
  }
}

resource "aws_iam_policy" "this" {
  name        = "${local.name}-lambda-policy"
  description = "Policy for Lambda"
  policy      = data.aws_iam_policy_document.this.json
}

resource "aws_iam_role" "this" {
  name               = "${local.name}-ecs-hook-service-role"
  assume_role_policy = data.aws_iam_policy_document.service-assume-role.json
}

resource "aws_iam_role_policy_attachment" "this" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.this.arn
}
