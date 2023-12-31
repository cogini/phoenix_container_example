# ECR repository for ECS app

terraform {
  source = "${dirname(find_in_parent_folders())}/modules//ecr-build"
}
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
  name = "${local.org}/aws-otel-collector"
}
