# Create SNS topic

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//sns"
}
include "root" {
  path = find_in_parent_folders("root.hcl")
}

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
  comp = "codedeploy"
  name = "${local.org}-${local.app_name}-${local.env}-codedeploy"
}
