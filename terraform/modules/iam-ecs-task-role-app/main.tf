# Create IAM ECS task role for app

# Example config:
# terraform {
#   source = "${dirname(find_in_parent_folders())}/modules//iam-ecs-task-role-app"
# }
# include "root" {
#   path = find_in_parent_folders()
# }
# dependency "kms" {
#   config_path = "../kms"
# }
# dependencies {
#   paths = [
#     "../s3-app",
#   ]
# }
#
# inputs = {
#   comp = "app"
#
#   # Give access to S3 buckets
#   s3_buckets = {
#     # s3-app = {
#     #   # assets = {}
#     #   # Allow read only access to config bucket
#     #   config = {
#     #     actions = ["s3:ListBucket", "s3:List*", "s3:Get*"]
#     #   }
#     #   data = {
#     #     actions = ["s3:ListBucket", "s3:List*", "s3:Get*", "s3:PutObject*", "s3:DeleteObject"]
#     #   }
#     #   logs = {}
#     #   # protected_web = {}
#     #   # public_web = {}
#     # }
#   }
#
#   # Allow writing to any log group and stream
#   cloudwatch_logs = ["*"]
#   # cloudwatch_logs = ["log-group:*"]
#   # cloudwatch_logs = ["log-group:*:log-stream:*"]
#   # cloudwatch_logs_prefix = "arn:${var.aws_partition}:logs:*:*"
#
#   # Enable writing metrics to any namespace
#   cloudwatch_metrics_namespace = "*"
#   # Allow writing to specific namespace
#   # cloudwatch_metrics_namespace = "Foo"
#
#   Allow writing to AWS Managed Prometheus workspaces
#   prometheus = true
#
#   # Enable writing to AWS X-Ray
#   xray = true
#
#   # Give acess to all SSM Parameter Store params under /org/app/env/comp
#   ssm_ps_params = ["*"]
#   # Specify prefix and params
#   # Give acess to all SSM Parameter Store params under /org/app/env
#   # ssm_ps_param_prefix = "cogini/foo/dev"
#   # Give acess to specific params under prefix
#   # ssm_ps_params = ["app/*", "worker/*"]
#
#   # Allow use of ECS Exec
#   enable_ssmmessages = true
#
#   # Allow sending email via AWS SES
#   enable_ses = true
#
#   enable_transcribe = true
#
#   # Give access to KMS CMK
#   kms_key_arn = dependency.kms.outputs.key_arn
# }

data "aws_caller_identity" "current" {}

data "terraform_remote_state" "s3" {
  for_each = toset(keys(var.s3_buckets))
  backend  = "s3"
  config = {
    bucket = var.remote_state_s3_bucket_name
    # key    = "${var.remote_state_s3_key_prefix}/${each.key}/terraform.tfstate"
    # key    = "${var.remote_state_s3_key_prefix}/${var.aws_region}/${var.env}/${each.key}/terraform.tfstate"
    key    = "${var.remote_state_s3_parent_dir}/${each.key}/terraform.tfstate"
    region = var.remote_state_s3_bucket_region
  }
}

# Give access to S3 buckets
locals {
  bucket_names = {
    for comp, buckets in var.s3_buckets :
    comp => keys(buckets)
  }
  # Set default actions and ensure that bucket actually exists
  buckets = {
    for comp, buckets in var.s3_buckets :
    comp => {
      for name, attrs in buckets :
      name => {
        actions = lookup(attrs, "actions", ["s3:ListBucket", "s3:List*", "s3:Get*", "s3:PutObject*", "s3:DeleteObject"])
        bucket  = data.terraform_remote_state.s3[comp].outputs.buckets[name]
      }
      if lookup(data.terraform_remote_state.s3[comp].outputs.buckets, name, "missing") != "missing"
    }
  }
  # Get actions for bucket contents
  bucket_actions_content = flatten([
    for comp, buckets in local.buckets : [
      for name, attrs in buckets : {
        bucket = attrs["bucket"]
        actions = [for action in attrs["actions"] : action
        if !contains(["s3:ListBucket", "s3:GetEncryptionConfiguration"], action)]
      }
    ]
  ])
  bucket_actions = flatten([
    for comp, buckets in local.buckets : [
      for name, attrs in buckets : {
        bucket = attrs["bucket"]
        actions = [for action in attrs["actions"] : action
        if contains(["s3:ListBucket", "s3:GetEncryptionConfiguration"], action)]
      }
    ]
  ])
  configure_s3 = length(local.bucket_names) > 0
  configure_efs = length(var.efs) > 0
}

locals {
  # https://docs.aws.amazon.com/systems-manager/latest/userguide/sysman-paramstore-access.html
  # Configure access to SSM Parameter Store parameters
  ssm_ps_arn          = "arn:${var.aws_partition}:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter"
  ssm_ps_param_prefix = var.ssm_ps_param_prefix == "" ? "${var.org}/${var.app_name}/${var.env}/${var.comp}" : var.ssm_ps_param_prefix
  ssm_ps_resources    = [for name in var.ssm_ps_params : "${local.ssm_ps_arn}/${local.ssm_ps_param_prefix}/${name}"]
  configure_ssm_ps    = length(local.ssm_ps_resources) > 0
  configure_sqs       = length(var.sqs_queues) > 0
}

locals {
  name = var.name == "" ? "${var.app_name}" : var.name
}

locals {
  # Configure access to CloudWatch metrics
  configure_cloudwatch_metrics  = var.cloudwatch_metrics_namespace != ""
  cloudwatch_metrics_namespaces = var.cloudwatch_metrics_namespace == "*" ? [] : [var.cloudwatch_metrics_namespace]

  # Configure access to CloudWatch Logs
  cloudwatch_logs_prefix = var.cloudwatch_logs_prefix == "" ? "arn:${var.aws_partition}:logs:*:*" : var.cloudwatch_logs_prefix
  cloudwatch_logs        = [for name in var.cloudwatch_logs : "${local.cloudwatch_logs_prefix}:${name}"]
  # arn:${var.aws_partition}:logs:*:*:*
  # arn:${var.aws_partition}:logs:*:*:log-group:*
  # arn:${var.aws_partition}:logs:*:*:log-group:*:log-stream:*

  # The first * in each string can be replaced with an AWS region name like
  # us-east-1 to grant access only within the given region.
  #
  # The * after log-group in can be replaced with a log group name to grant
  # access only to the named group.
  #
  # The * after log-stream can be replaced with a log stream name to grant
  # access only to the named stream.
  configure_cloudwatch_logs = length(local.cloudwatch_logs) > 0
}

# Send data to to AWS X-Ray and Prometheus
locals {
  write_xray       = var.xray
  write_prometheus = var.prometheus
}

data "aws_iam_policy_document" "this" {
  # Allow writing to CloudWatch Logs
  # https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/EC2NewInstanceCWL.html
  #
  # In addition, you may want to allow writing directly to a S3 bucket for logs
  # https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/Sending-Logs-Directly-To-S3.html
  # Configure that with "buckets", above
  dynamic "statement" {
    for_each = local.configure_cloudwatch_logs ? tolist([1]) : []
    content {
      actions = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams",
        "logs:PutRetentionPolicy",
      ]
      resources = local.cloudwatch_logs
    }
  }

  # Allow writing to CloudWatch metrics
  # https://docs.aws.amazon.com/IAM/latest/UserGuide/list_amazoncloudwatch.html
  # https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/iam-cw-condition-keys-namespace.html
  dynamic "statement" {
    for_each = local.configure_cloudwatch_metrics ? tolist([1]) : []
    content {
      actions = [
        "cloudwatch:PutMetricData",
      ]
      resources = ["*"]
      dynamic "condition" {
        for_each = local.cloudwatch_metrics_namespaces
        content {
          test     = "StringEquals"
          variable = "cloudwatch:namespace"
          values   = [condition.value]
        }
      }
    }
  }

  dynamic "statement" {
    for_each = var.enable_ecs_discovery ? tolist([1]) : []
    content {
      actions = [
        "ec2:DescribeInstances",
        "ecs:DescribeContainerInstances",
        "ecs:DescribeTasks",
        "ecs:ListClusters",
        "ecs:ListServices",
        "ecs:ListTasks",
      ]
      resources = ["*"]
    }
  }

  dynamic "statement" {
    for_each = var.enable_transcribe ? tolist([1]) : []
    content {
      actions = [
        "transcribe:StartTranscriptionJob",
        "transcribe:GetTranscriptionJob",
        "transcribe:TagResource"
      ]
      resources = ["*"]
    }
  }

  dynamic "statement" {
    for_each = local.configure_sqs ? tolist([1]) : []
    content {
      actions = [
        "sqs:SendMessage",
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:ChangeMessageVisibility",
        "sqs:ListQueues"
      ]
      resources = var.sqs_queues
    }
  }

  # Allow S3 ListBucket actions on buckets
  dynamic "statement" {
    for_each = local.bucket_actions
    content {
      actions   = statement.value["actions"]
      resources = [statement.value["bucket"].arn]
    }
  }

  # Allow S3 other actions on buckets
  dynamic "statement" {
    for_each = local.bucket_actions_content
    content {
      actions   = statement.value["actions"]
      resources = ["${statement.value["bucket"].arn}/*"]
    }
  }

  # Allow read only access to SSM Parameter Store params
  dynamic "statement" {
    for_each = local.configure_ssm_ps ? tolist([1]) : []
    content {
      actions = [
        "ssm:DescribeParameters",
        "ssm:GetParameters",
        "ssm:GetParameter*"
      ]
      resources = local.ssm_ps_resources
    }
  }

  # Allow access to SSM for management
  # https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-setting-up-messageAPIs.html
  # https://docs.aws.amazon.com/systems-manager/latest/userguide/setup-instance-profile.html

  # Allow access to ssmmessages for secure connection
  # https://aws.amazon.com/blogs/containers/new-using-amazon-ecs-exec-access-your-containers-fargate-ec2/
  dynamic "statement" {
    for_each = var.enable_ssmmessages ? tolist([1]) : []
    content {
      actions = [
        "ssmmessages:CreateControlChannel",
        "ssmmessages:CreateDataChannel",
        "ssmmessages:OpenControlChannel",
        "ssmmessages:OpenDataChannel",
      ]
      resources = ["*"]
    }
  }

  # Allow sending email via SES
  dynamic "statement" {
    for_each = var.enable_ses ? tolist([1]) : []
    content {
      actions = [
        "ses:SendRawEmail"
      ]
      resources = ["*"]
    }
  }

  # Give access to EFS file systems
  dynamic "statement" {
    for_each = var.efs
    content {
      actions   = statement.value.actions
      resources = [statement.value.file_system_arn]
      dynamic "condition" {
        for_each = statement.value.access_point_arn == null ? [] : [statement.value.access_point_arn]
        content {
          test     = "StringEquals"
          variable = "elasticfilesystem:AccessPointArn"
          values   = [condition.value]
        }
      }
    }
  }

  # KMS
  # https://docs.aws.amazon.com/kms/latest/developerguide/kms-api-permissions-reference.html
  # https://docs.aws.amazon.com/kms/latest/developerguide/key-policies.html
  # https://repost.aws/knowledge-center/s3-access-denied-error-kms
  dynamic "statement" {
    for_each = var.kms_key_arn == null ? [] : tolist([1])
    content {
      sid = "AllowKeyUsage"
      actions = [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:DescribeKey",
      ]
      resources = [var.kms_key_arn]
    }
  }
}

# KMS for SSM PS
# https://docs.aws.amazon.com/kms/latest/developerguide/services-parameter-store.html
# Allow reading parameters encrypted using CMK
# dynamic "statement" {
#   for_each = var.kms_key_arn != null ? tolist([1]) : []
#   content {
#     actions = ["kms:Decrypt", "kms:DescribeKey"]
#     resources = [var.kms_key_arn]
#   }
# }
#
# KMS for S3
# https://docs.aws.amazon.com/kms/latest/developerguide/services-s3.html
#
# ALlow writing encrypted data to S3
# dynamic "statement" {
#   for_each = var.has_kms ? tolist([1]) : []
#   content {
#     actions   = ["kms:GenerateDataKey"]
#     resources = ["*"]
#   }
# }

# Allow role to be assumed by AWS
data "aws_iam_policy_document" "assume-role-policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = [
        "ecs-tasks.amazonaws.com"
      ]
    }
  }
}

# Base IAM role
# https://github.com/hashicorp/terraform/issues/2761
resource "aws_iam_role" "this" {
  name_prefix = "${local.name}-${var.comp}-"
  description = "${local.name} ${var.comp} task role"
  assume_role_policy = data.aws_iam_policy_document.assume-role-policy.json

  # https://github.com/hashicorp/terraform/issues/2761
  force_detach_policies = true

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_policy" "this" {
  name_prefix = "${local.name}-${var.comp}-ecs-task-"
  description = "Access resources from ECS task"
  policy      = data.aws_iam_policy_document.this.json
}

resource "aws_iam_role_policy_attachment" "this" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.this.arn
}

# Allow uploading segment documents and telemetry to the X-Ray API
# https://docs.aws.amazon.com/xray/latest/devguide/security_iam_id-based-policy-examples.html
resource "aws_iam_role_policy_attachment" "xray" {
  count      = local.write_xray ? 1 : 0
  role       = aws_iam_role.this.name
  policy_arn = "arn:${var.aws_partition}:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

# Grant write only access to AWS Managed Prometheus workspaces
# https://docs.aws.amazon.com/prometheus/latest/userguide/security-iam-awsmanpol.html
resource "aws_iam_role_policy_attachment" "prometheus" {
  count      = local.write_prometheus ? 1 : 0
  role       = aws_iam_role.this.name
  policy_arn = "arn:${var.aws_partition}:iam::aws:policy/AmazonPrometheusRemoteWriteAccess"
}

# Allow component to read parameters from SSM
# This requires fewer permissions than the full SSM management permissions
# https://docs.aws.amazon.com/systems-manager/latest/userguide/auth-and-access-control-iam-identity-based-access-control.html#managed-policies
# resource "aws_iam_role_policy_attachment" "ssm-service-policy" {
#   count      = var.enable_ssm_ps_readonly ? 1 : 0
#   role       = aws_iam_role.this.name
#   policy_arn = "arn:${var.aws_partition}:iam::aws:policy/AmazonSSMReadOnlyAccess"
# }
