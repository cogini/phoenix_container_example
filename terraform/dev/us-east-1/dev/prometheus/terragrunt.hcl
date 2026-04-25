# Create Prometheus Workspace

terraform {
  source = "github.com/terraform-aws-modules/terraform-aws-managed-service-prometheus?ref=v3.0.0"
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
  workspace_alias = "monitoring-${local.env}"
  workspace_id = "${local.env}"

  # kms_key_arn = dependency.kms.outputs.key_arn
}
