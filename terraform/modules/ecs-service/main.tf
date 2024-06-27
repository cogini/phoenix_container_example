# Create ECS service

locals {
  name        = var.name == "" ? "${var.app_name}-${var.comp}" : var.name
  family_name = var.family_name == "" ? local.name : var.family_name
}

data "aws_ecs_task_definition" "this" {
  task_definition = local.family_name
}

locals {
  task_definition = var.task_definition == "" ? data.aws_ecs_task_definition.this.arn : var.task_definition
}

# https://www.terraform.io/docs/providers/aws/r/ecs_service.html
# https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs_services.html
# https://docs.aws.amazon.com/AmazonECS/latest/developerguide/service_definition_parameters.html
resource "aws_ecs_service" "this" {
  name = local.name

  dynamic "capacity_provider_strategy" {
    for_each = var.capacity_provider_strategy
    iterator = strategy
    content {
      capacity_provider = lookup(strategy.value, "capacity_provider", null)
      weight            = lookup(strategy.value, "weight", null)
      base              = lookup(strategy.value, "base", null)
    }
  }

  cluster = var.cluster

  deployment_controller {
    type = var.deployment_controller_type
  }

  deployment_maximum_percent         = var.deployment_maximum_percent
  deployment_minimum_healthy_percent = var.deployment_minimum_healthy_percent
  desired_count                      = var.desired_count
  enable_ecs_managed_tags            = var.enable_ecs_managed_tags
  enable_execute_command             = var.enable_execute_command
  force_new_deployment               = var.force_new_deployment

  # dynamic "triggers" {
  #   for_each = var.force_new_deployment == null ? [] : tolist([1])
  #   content {
  #     redeployment = timestamp()
  #   }
  # }

  health_check_grace_period_seconds = var.health_check_grace_period_seconds
  iam_role                          = var.iam_role
  launch_type                       = var.launch_type

  # https://www.terraform.io/docs/providers/aws/r/ecs_service.html#load_balancer-1
  dynamic "load_balancer" {
    for_each = var.load_balancer
    content {
      elb_name         = lookup(load_balancer.value, "elb_name", null)
      target_group_arn = lookup(load_balancer.value, "target_group_arn", null)
      container_name   = lookup(load_balancer.value, "container_name", null)
      container_port   = lookup(load_balancer.value, "container_port", null)
    }
  }

  dynamic "network_configuration" {
    for_each = var.network_configuration == null ? [] : tolist([1])
    content {
      subnets          = lookup(var.network_configuration, "subnets", null)
      security_groups  = lookup(var.network_configuration, "security_groups", null)
      assign_public_ip = lookup(var.network_configuration, "assign_public_ip", null)
    }
  }

  # https://docs.aws.amazon.com/AmazonECS/latest/APIReference/API_PlacementStrategy.html
  dynamic "ordered_placement_strategy" {
    for_each = var.ordered_placement_strategy
    iterator = strategy
    content {
      type  = lookup(strategy.value, "type", null)
      field = lookup(strategy.value, "field", null)
    }
  }

  dynamic "placement_constraints" {
    for_each = var.placement_constraints
    iterator = constraint
    content {
      type = lookup(constraint.value, "type", null) # memberOf or distinctInstance
      # https://docs.aws.amazon.com/AmazonECS/latest/developerguide/cluster-query-language.html
      expression = lookup(constraint.value, "expression", null)
    }
  }

  platform_version    = var.platform_version
  propagate_tags      = var.propagate_tags
  scheduling_strategy = var.scheduling_strategy

  # https://www.terraform.io/docs/providers/aws/r/ecs_service.html#service_registries-1
  # https://docs.aws.amazon.com/Route53/latest/APIReference/API_autonaming_Service.html
  dynamic "service_registries" {
    for_each = var.service_registries == null ? [] : tolist([1])
    content {
      registry_arn   = lookup(var.service_registries, "registry_arn", null)
      port           = lookup(var.service_registries, "port", null)
      container_port = lookup(var.service_registries, "container_port", null)
      container_name = lookup(var.service_registries, "container_name", null)
    }
  }

  # service_connect_configuration = var.service_connect_configuration
  dynamic "service_connect_configuration" {
    for_each = var.service_connect_configuration == null ? [] : tolist([1])
    content {
      enabled   = lookup(service_connect_configuration, "enabled", true)
      namespace = lookup(service_connect_configuration, "namespace", null)

      dynamic "service" {
        for_each = lookup(service_connect_configuration, "service", [])
        content {
          client_alias          = lookup(service.value, "client_alias", [])
          discovery_name        = lookup(service.value, "discovery_name", null)
          ingress_port_override = lookup(service.value, "ingress_port_override", null)
          port_name             = lookup(service.value, "port_name", null)
        }
      }

      dynamic "log_configuration" {
        for_each = lookup(service_connect_configuration, "log_configuration", null) == null ? [] : tolist([1])
        content {
          log_driver = lookup(log_configuration.value, "log_driver", null)
          options    = lookup(log_configuration.value, "options", null)

          dynamic "secret_option" {
            for_each = lookup(log_configuration.value, "secret_option", [])
            content {
              name       = lookup(secret_option.value, "name", null)
              value_from = lookup(secret_option.value, "value_from", null)
            }
          }
        }
      }
    }
  }

  tags = merge(
    {
      "Name"  = local.name
      "org"   = var.org
      "app"   = var.app_name
      "env"   = var.env
      "comp"  = var.comp
      "owner" = var.owner
    },
    var.extra_tags
  )

  task_definition = local.task_definition

  # Allow external changes without Terraform plan difference
  lifecycle {
    # create_before_destroy = true
    ignore_changes = [
      # Changed externally when deploying an update
      task_definition,
      # Changed externally by CodeDeploy Blue/Green
      load_balancer,
      # May be modified manually
      desired_count
    ]
  }
}
