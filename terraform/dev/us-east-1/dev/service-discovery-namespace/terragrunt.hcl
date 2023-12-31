# Service discovery DNS private namespace

terraform {
  source = "${dirname(find_in_parent_folders())}/modules//service-discovery-private-dns-namespace"
}
dependency "vpc" {
  config_path = "../vpc"
}
include "root" {
  path = find_in_parent_folders()
}

inputs = {
  # name = "app.internal"
  vpc_id = dependency.vpc.outputs.vpc_id
}
