# Create ECS cluster

terraform {
  source = "${dirname(find_in_parent_folders())}/modules//ecs-cluster"
}
dependency "sd-namespace" {
  config_path = "../service-discovery-namespace"
}
include "root" {
  path = find_in_parent_folders()
}

inputs = {
  # name = "foo" # Default is app_name

  # capacity_providers = ["FARGATE", "FARGATE_SPOT"]
  default_capacity_provider_strategy = [
    {
      capacity_provider = "FARGATE"
      weight            = 1
      base              = 1
    },
    {
      capacity_provider = "FARGATE_SPOT"
      weight            = 1
    },
  ]

  container_insights = "enabled"

  service_discovery_namespace = dependency.sd-namespace.outputs.arn

  # force_delete = true
}
