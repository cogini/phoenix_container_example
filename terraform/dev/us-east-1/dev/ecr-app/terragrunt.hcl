# ECR repository for ECS app

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//ecr-build"
}
include "root" {
  path = find_in_parent_folders("root.hcl")
}

inputs = {
  comp = "app"

  # allow_codebuild = true

  # cross_accounts = [
  #  "arn:aws:iam::737720086707:root",
  #  "arn:aws:iam::318109559665:root"
  # ]
  # create_replication = true
  # registry_replication_rules = [
  #   {
  #     destinations = [{
  #       region      = "us-east-1"
  #       registry_id = "318109559665"
  #     }]
  # }]
}
