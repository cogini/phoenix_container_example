# Create IAM service role allowing ECS to update load balancer for blue/green deployment
# https://docs.aws.amazon.com/AmazonECS/latest/developerguide/AmazonECSInfrastructureRolePolicyForLoadBalancers.html

locals {
  name = var.name == "" ? "${var.org}-${var.app_name}-${var.env}" : var.name
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

resource "aws_iam_role" "this" {
  name               = "${local.name}-ecs-load-balancers"
  assume_role_policy = data.aws_iam_policy_document.service-assume-role.json
}

resource "aws_iam_role_policy_attachment" "this" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonECSInfrastructureRolePolicyForLoadBalancers"
}
