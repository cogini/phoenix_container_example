# Create ECS service

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//ecs-service"
}
include "root" {
  path = find_in_parent_folders("root.hcl")
}
dependency "cluster" {
  config_path = "../ecs-cluster"
}
# dependency "iam-lambda" {
#   config_path = "../iam-lambda-ecs-hook-app"
# }
# dependency "iam-ecs-lb" {
#   config_path = "../iam-ecs-load-balancers"
# }
# dependency "lambda" {
#   config_path = "../lambda-ecs-hook-app"
# }
dependency "sd-service" {
  config_path = "../service-discovery-service-app"
}
dependency "sg" {
  config_path = "../sg-app-private"
}
dependency "task" {
  config_path = "../ecs-task-app"
}
# dependency "listener-rule" {
#   config_path = "../lb-listener-rule-app"
# }
dependency "tg-1" {
  config_path = "../target-group-app-ecs-1"
}
dependency "tg-2" {
  config_path = "../target-group-app-ecs-2"
}
dependency "vpc" {
  config_path = "../vpc"
}

inputs = {
  comp    = "app"
  cluster = dependency.cluster.outputs.arn

  # By default, the module looks up the latest task definition
  # task_definition = dependency.task.outputs.arn
  # task_definition = "foo-app:27"

  load_balancer = [
    {
      target_group_arn = dependency.tg-1.outputs.arn
      # container_name   = dependency.task.outputs.container_name
      # Name of container to associate with the load balancer, from task definition
      container_name   = "foo-app"
      # Port on container to associate with the load balancer, from task definition
      # container_port = dependency.task.outputs.port_mappings[0].hostPort
      container_port   = 4000
      # advanced_configuration = {
      #   alternate_target_group_arn = dependency.tg-1.outputs.arn
      #   production_listener_rule = dependency.listener-rule.outputs.arn
      #   # Role which allows ECS to modify load balancer target group and listener rules
      #   role_arn = dependency.iam-ecs-lb.outputs.role_arn
      # }
    }
  ]

  # launch_type = "FARGATE"

  capacity_provider_strategy = [
    {
      capacity_provider = "FARGATE"
      weight            = 1
      base              = 1
    },
    {
      capacity_provider = "FARGATE_SPOT"
      weight            = 1
    }
  ]

  # deployment_controller_type = "CODE_DEPLOY"
  deployment_controller_type = "ECS"
  force_new_deployment       = true

  # deployment_configuration = {
  #   strategy = "BLUE_GREEN" # "ROLLING", "BLUE_GREEN", "LINEAR", "CANARY". Default: "ROLLING"
  #   # strategy = "ROLLING"
  #   bake_time_in_minutes = 0 # default 5
  #
  #   lifecycle_hook = {
  #     hook_details = "ECS Deployment Lifecycle Hook"
  #     hook_target_arn = dependency.lambda.outputs.lambda_function_arn
  #     lifecycle_stages = [
  #       "RECONCILE_SERVICE", "PRE_SCALE_UP", "POST_SCALE_UP", "TEST_TRAFFIC_SHIFT",
  #       "POST_TEST_TRAFFIC_SHIFT", "PRODUCTION_TRAFFIC_SHIFT", "POST_PRODUCTION_TRAFFIC_SHIFT"
  #     ]
  #     # Role which allows ECS to invoke Lambda function
  #     role_arn = dependency.iam-lambda.outputs.role_arn
  #   }
  # }

  # deployment_maximum_percent = 200
  # deployment_minimum_healthy_percent = 0
  desired_count = 1
  health_check_grace_period_seconds = 5

  # iam_role = dependency.iam.outputs.instance_profile_name

  network_configuration = {
    subnets          = dependency.vpc.outputs.subnets["private"]
    security_groups  = [dependency.sg.outputs.security_group_id]
    assign_public_ip = false # true when running in public subnet
  }

  service_registries = {
    registry_arn = dependency.sd-service.outputs.arn
    # port = 4000
    # container_name = dependency.task.outputs.container_name
    container_name = "foo-app"
    # Port value from task definition
    # container_port = dependency.task.outputs.port_mappings[0].hostPort
    # container_port = 4000
    # Port value if Service Discovery service specified an SRV record
    # port = 4000
  }

  # service_connect_configuration = {
  #   # enabled = true # default true
  #   # log_configuration = {
  #   #   log_driver = "awslogs"
  #   # }
  #   # namespace name or ARN of aws_service_discovery_http_namespace
  #   namespace = dependency.sd-service.outputs.arn
  #   service = [
  #     {
  #       port_name =  "web"
  #       # discovery_name = "ai-app"
  #       # client_alias = ["ai-app.ai.internal"]
  #     }
  #   ]
  # }

  enable_ecs_managed_tags = true

  # propagate_tags = "SERVICE" | "TASK_DEFINITION"

  # ordered_placement_strategy = [
  #   {
  #     type  = "binpack"
  #     field = "cpu"
  #   }
  # ]

  # placement_constraints = [
  #   {
  #     type       = "memberOf"
  #     expression = "attribute:ecs.availability-zone in [us-west-2a, us-west-2b]"
  #   }
  # ]

  enable_execute_command = true

  # force_delete = true
}
