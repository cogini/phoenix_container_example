# Security group for RDS db

terraform {
  source = "${dirname(find_in_parent_folders())}/modules//sg"
}
dependency "vpc" {
  config_path = "../vpc"
}
dependencies {
  paths = [
    # "../sg-bastion",
    "../sg-devops",
    "../sg-app-private",
    # "../sg-app-public",
    # "../sg-build-app",
    # "../sg-worker",
  ]
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
  comp      = "rds-app"
  name      = "${local.app_name}-db"
  app_ports = [5432]
  app_sources = [
    # "sg-bastion",
    "sg-devops",
    "sg-app-private",
    # "sg-app-public",
    # "sg-build-app",
    # "sg-worker",
  ]

  vpc_id = dependency.vpc.outputs.vpc_id
}
