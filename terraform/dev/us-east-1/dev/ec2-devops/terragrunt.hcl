# Create DevOps EC2 instance

terraform {
  source = "${dirname(find_in_parent_folders())}/modules//ec2-private"
}
dependency "iam" {
  config_path = "../iam-instance-profile-devops"
}
dependency "sg" {
  config_path = "../sg-devops"
}
dependency "vpc" {
  config_path = "../vpc"
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
  comp = "devops"

  # Create a single instance
  instance_count = 1

  instance_type = "t4g.nano"

  ami_filter_architecture = ["arm64"]
  ami_filter_name = ["ubuntu/images/hvm-ssd/ubuntu-jammy*"]
  ami_filter_owners = ["amazon"]

  # Ubuntu 22.04
  # ami = "ami-0c7217cdde317cfec"

  keypair_name = "${local.app_name}-dev"

  # Increase root volume size, necessary when building large apps
  # root_volume_size = 400

  subnet_ids            = dependency.vpc.outputs.subnets["private"]
  security_group_ids    = [dependency.sg.outputs.security_group_id]
  instance_profile_name = dependency.iam.outputs.instance_profile_name
}
