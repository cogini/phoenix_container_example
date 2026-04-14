# Security group for load balancer running in public subnet

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
  comp          = "lb-public"
  ingress_ports = [80, 443]

  vpc_id = dependency.vpc.outputs.vpc_id
}
