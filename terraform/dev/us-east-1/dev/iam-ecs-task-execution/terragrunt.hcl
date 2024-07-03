# Create ECS IAM Task Execution role
# This role is used by ECS to start the task. It needs permissions to pull
# images from ECR, access Parameter Store, set up CloudWatch logs, etc.

terraform {
  source = "${dirname(find_in_parent_folders())}/modules//iam-ecs-task-execution"
}

# dependency "kms" {
#   config_path = "../kms"
# }
include "root" {
  path = find_in_parent_folders()
}

locals {
  common_vars      = read_terragrunt_config(find_in_parent_folders("common.hcl"))
  environment_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  org              = local.common_vars.locals.org
  app_name         = local.common_vars.locals.app_name
  env              = local.environment_vars.locals.env
}

inputs = {
  comp = "app"

  # Allow creating CloudWatch Logs group
  cloudwatch_logs_create_group = true

  # Allow writing to any log group and stream
  cloudwatch_logs = ["*"]
  # cloudwatch_logs = ["log-group:*"]
  # cloudwatch_logs = ["log-group:*:log-stream:*"]

  # Give access to SSM Parameter Store params
  # Default prefix is org/app/env/comp, e.g. "cogini/foo/dev/app"
  # ssm_ps_param_prefix = format("%s/%s/%s", local.org, local.app_name, local.env)

  # Give access to parameter names under prefix
  # "*" gives access to all parameters
  ssm_ps_params = ["*"]
  # Give acess to params under different components, after settting prefix to org/app
  # ssm_ps_params = ["app/*", "worker/*"]

  # Give access to KMS CMK
  # kms_key_arn = dependency.kms.outputs.key_arn
}
