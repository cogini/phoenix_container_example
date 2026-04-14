# Create Route53 hosted zone for public domain

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//route53-zone"
}
include "root" {
  path = find_in_parent_folders("root.hcl")
}
dependency "delegation-set" {
  config_path = "../route53-delegation-set"
}

inputs = {
  name              = "rubegoldberg.io"
  delegation_set_id = dependency.delegation-set.outputs.id

  # Useful in dev, unsafe in prod
  # force_destroy = true
}
