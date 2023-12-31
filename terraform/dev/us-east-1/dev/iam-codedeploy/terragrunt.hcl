# Define IAM service role for CodeDeploy for ECS

terraform {
  source = "${dirname(find_in_parent_folders())}/modules//iam-codedeploy-ecs"
}
include "root" {
  path = find_in_parent_folders()
}
