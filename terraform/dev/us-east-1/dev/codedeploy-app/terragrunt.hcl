# Create CodeDeploy application for app

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//codedeploy"
}
include "root" {
  path = find_in_parent_folders("root.hcl")
}

inputs = {
  comp             = "app"
  compute_platform = "ECS"
}
