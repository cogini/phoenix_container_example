# Create IAM instance profile for devops

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//iam-instance-profile-app"
}
include "root" {
  path = find_in_parent_folders("root.hcl")
}
# dependency "kms" {
#   config_path = "../kms"
# }

locals {
  account_vars     = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  region_vars      = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  env_vars         = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  common_vars      = read_terragrunt_config(find_in_parent_folders("common.hcl"))

  org      = local.common_vars.locals.org
  app_name = local.common_vars.locals.app_name
  env      = local.env_vars.locals.env
}

inputs = {
  comp = "devops"

  # Allow writing to any log group and stream
  cloudwatch_logs = ["*"]
  # cloudwatch_logs = ["log-group:*"]
  # cloudwatch_logs = ["log-group:*:log-stream:*"]

  # Enable management via SSM
  enable_ssm_management = true

  # Give access to SSM Parameter Store parameters under org/app/env
  ssm_ps_param_prefix = "${local.org}/${local.app_name}/${local.env}"
  ssm_ps_params = ["*"]

  # Give access to KMS CMK
  # kms_key_arn = dependency.kms.outputs.key_arn
}
