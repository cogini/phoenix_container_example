# ECR repository for ECS app

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//ecr-build"
}
include "root" {
  path = find_in_parent_folders("root.hcl")
}

inputs = {
  comp = "api"
}
