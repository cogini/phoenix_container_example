# Create NAT instance

# A NAT instance is an EC2 instance which allows traffic outbound from
# instances in the private network segment. It does the same thing as a NAT
# Gateway, but is much cheaper to run. It has performance limits and
# generally is more trouble to run, but is useful for dev or smaller apps.

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//fck-nat"
}
include "root" {
  path = find_in_parent_folders("root.hcl")
}
dependency "vpc" {
  config_path = "../vpc"
}


locals {
  common_vars      = read_terragrunt_config(find_in_parent_folders("common.hcl"))
  environment_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  org              = local.common_vars.locals.org
  app_name         = local.common_vars.locals.app_name
  env              = local.environment_vars.locals.env
}

inputs = {
  subnet_id           = dependency.vpc.outputs.public_subnets[0]
  ha_mode             = false

  update_route_tables = true
  route_tables_ids    = {for i, v in dependency.vpc.outputs.private_route_table_ids : format("private-%02d", i) => v}

  # instance_type       = "t4g.nano"
  # ami_id              = "ami-075a0093cd9926d44"


  ssh_key_name        = "${local.app_name}-${local.env}"

  vpc_id              = dependency.vpc.outputs.vpc_id
}
