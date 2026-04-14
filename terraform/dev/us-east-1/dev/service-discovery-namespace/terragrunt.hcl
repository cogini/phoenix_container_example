# Service discovery DNS private namespace

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//service-discovery-private-dns-namespace"
}
include "root" {
  path = find_in_parent_folders("root.hcl")
}
dependency "vpc" {
  config_path = "../vpc"
}

inputs = {
  # name defaults to "${var.app_name}.internal"
  vpc_id = dependency.vpc.outputs.vpc_id
}
