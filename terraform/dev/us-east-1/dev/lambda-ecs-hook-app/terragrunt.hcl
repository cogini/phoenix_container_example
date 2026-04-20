terraform {
  source = "github.com/terraform-aws-modules/terraform-aws-lambda?ref=v8.7.0"
}
include {
  path = find_in_parent_folders("root.hcl")
}

locals {
  account_vars     = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  common_vars      = read_terragrunt_config(find_in_parent_folders("common.hcl"))
  region_vars      = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  environment_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  aws_account_id   = local.account_vars.locals.aws_account_id
  org              = local.common_vars.locals.org
  app_name         = local.common_vars.locals.app_name
  env              = local.environment_vars.locals.env
}


inputs = {
  description            = "ECS lifecycle callbacks for app"
  function_name          = "${local.app_name}-ecs-app"
  handler                = "index.lambda_handler"
  runtime                = "python3.12"
  # memory_size            = 1024 # default 128
  # ephemeral_storage_size = 512 # default 512
  architectures          = ["arm64"] # default ["x86_64"]
  timeout                = 20

  environment_variables = {
    LOG_LEVEL = "DEBUG"
  }

  source_path = [
    "./src"
  ]

  # create_package = false
  # archive_filename       = "content_type_processor.zip"
  # local_existing_package = "./content_type_processor.zip"

  create_role = true
  role_name          = "lambda-${local.app_name}-ecs-app"
  role_description   = "IAM role for Lambda function ${local.app_name}-ecs-app"

  assume_role_policy_statements = {
    account_root = {
      effect  = "Allow",
      actions = ["sts:AssumeRole"],
      principals = {
        account_principal = {
          type        = "AWS",
          identifiers = [local.aws_account_id]
        }
      }
    }
  }

  attach_policies = true
  policies        = ["arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"]

  publish = true
}
