# ECR repository for ECS app

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//ecr-build"
}
include "root" {
  path = find_in_parent_folders("root.hcl")
}

inputs = {
  comp = "app"

  pull_through_cache_rules = [
    {
      ecr_repository_prefix = "ecr-public"
      upstream_registry_url = "public.ecr.aws"
    }
  ]
}
