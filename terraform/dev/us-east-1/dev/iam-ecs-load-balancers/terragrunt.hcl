# Create service role so ECS can update load balancers for blue/green deployment

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//iam-ecs-load-balancers"
}
include "root" {
  path = find_in_parent_folders("root.hcl")
}
