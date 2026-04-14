# Security group for devops instance running in private subnet

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//sg"
}
include "root" {
  path = find_in_parent_folders("root.hcl")
}
dependency "vpc" {
  config_path = "../vpc"
}

inputs = {
  comp = "devops"
  # ssh_sources = ["sg-bastion"]

  vpc_id = dependency.vpc.outputs.vpc_id
}
