# Create IAM role that allows a GitHub Action to call AWS

terraform {
  source = "${dirname(find_in_parent_folders())}/modules//iam-github-action"
}

dependency "cloudfront" {
  config_path = "../cloudfront-app-assets"
}
dependency "codedeploy-app" {
  config_path = "../codedeploy-app"
}
dependency "codedeploy-deployment-app" {
  config_path = "../codedeploy-deployment-app"
}
dependency "codedeploy-api" {
  config_path = "../codedeploy-api"
}
dependency "codedeploy-deployment-api" {
  config_path = "../codedeploy-deployment-api"
}
dependency "ecr-app" {
  config_path = "../ecr-app"
}
dependency "ecr-api" {
  config_path = "../ecr-api"
}
dependency "ecr-otel" {
  config_path = "../ecr-otel"
}
dependency "ecs-cluster" {
  config_path = "../ecs-cluster"
}
dependency "ecs-service-app" {
  config_path = "../ecs-service-app"
}
dependency "ecs-service-api" {
  config_path = "../ecs-service-api"
}
dependency "ecs-service-worker" {
  config_path = "../ecs-service-worker"
}
dependency "iam-ecs-task-execution" {
  config_path = "../iam-ecs-task-execution"
}
dependency "iam-ecs-task-role" {
  config_path = "../iam-ecs-task-role-app"
}
dependency "s3" {
  config_path = "../s3-app"
}
include "root" {
  path = find_in_parent_folders()
}

inputs = {
  comp = "app"

  subs = [
    "repo:cogini/phoenix_container_example:*",
    "repo:cogini/absinthe_federation_example:*",
  ]

  s3_buckets = [
    dependency.s3.outputs.buckets["assets"].id
  ]

  enable_cloudfront = true

  ecr_arns = [
    dependency.ecr-app.outputs.arn,
    dependency.ecr-otel.outputs.arn
  ]

  ecs = [
    {
      service_arn                      = dependency.ecs-service-app.outputs.id
      task_role_arn                    = dependency.iam-ecs-task-role.outputs.arn
      execution_role_arn               = dependency.iam-ecs-task-execution.outputs.arn
      codedeploy_application_name      = dependency.codedeploy-app.outputs.app_name
      codedeploy_deployment_group_name = dependency.codedeploy-deployment-app.outputs.deployment_group_name
    },
    {
      service_arn                      = dependency.ecs-service-api.outputs.id
      task_role_arn                    = dependency.iam-ecs-task-role.outputs.arn
      execution_role_arn               = dependency.iam-ecs-task-execution.outputs.arn
      codedeploy_application_name      = dependency.codedeploy-api.outputs.app_name
      codedeploy_deployment_group_name = dependency.codedeploy-deployment-api.outputs.deployment_group_name
    },
    {
      service_arn                      = dependency.ecs-service-worker.outputs.id
      task_role_arn                    = dependency.iam-ecs-task-role.outputs.arn
      execution_role_arn               = dependency.iam-ecs-task-execution.outputs.arn
    }
  ]
}
