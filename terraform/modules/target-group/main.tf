# Create load balancer target group for app

# Example config:
# terraform {
#   source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//target-group"
# }
# include "root" {
#   path = find_in_parent_folders("root.hcl")
# }
# dependency "vpc" {
#   config_path = "../vpc"
# }
# dependency "lb" {
#   config_path = "../lb-public"
# }
#
# inputs = {
#   comp = "app"
#   name = "app-1"
#
#   port     = 4001
#   protocol = "HTTPS"
#
#   health_check = {
#     # If you don't specify the port, it uses the same as the traffic port.
#     # You still need to specify HTTPS, though.
#     protocol = "HTTPS" # default HTTP
#     port = 4001
#     path = "/"
#     # interval = 10 # default 30
#     # timeout = 10 # default 5
#     healthy_threshold = 2 # default 3
#     unhealthy_threshold = 2 # default 3
#     matcher = "200,302" # default 200
#   }
#
#   # stickiness = {
#   #   type = "lb_cookie"
#   # }
#
#   # listener_rule = true # default
#   # listener_arn = dependency.lb.outputs.listener_arn
#   vpc_id        = dependency.vpc.outputs.vpc_id
#   target_type   = "ip"
# }

locals {
  name  = var.name == "" ? "${var.app_name}-${var.comp}" : var.name
  hosts = [for host in var.hosts : replace(host, "/\\.$/", "")]
}

# https://www.terraform.io/docs/providers/aws/r/lb_target_group.html
# https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-target-groups.html
resource "aws_lb_target_group" "this" {
  deregistration_delay          = var.deregistration_delay
  load_balancing_algorithm_type = var.load_balancing_algorithm_type
  name                          = local.name
  port                          = var.port
  protocol                      = var.protocol
  protocol_version              = var.protocol_version

  dynamic "health_check" {
    for_each = var.health_check == null ? [] : [var.health_check]
    content {
      enabled             = lookup(health_check.value, "enabled", null)
      healthy_threshold   = lookup(health_check.value, "healthy_threshold", null)
      interval            = lookup(health_check.value, "interval", null)
      matcher             = lookup(health_check.value, "matcher", null)
      path                = lookup(health_check.value, "path", null)
      port                = lookup(health_check.value, "port", null)
      protocol            = lookup(health_check.value, "protocol", null)
      timeout             = lookup(health_check.value, "timeout", null)
      unhealthy_threshold = lookup(health_check.value, "unhealthy_threshold", null)
    }
  }

  dynamic "stickiness" {
    for_each = var.stickiness == null ? [] : [var.stickiness]
    content {
      cookie_duration = lookup(stickiness.value, "cookie_duration", null)
      cookie_name     = lookup(stickiness.value, "cookie_name", null)
      enabled         = lookup(stickiness.value, "enabled", null)
      type            = lookup(stickiness.value, "type", "lb_cookie")
    }
  }

  vpc_id      = var.vpc_id
  target_type = var.target_type

  tags = merge(
    {
      "Name"  = local.name
      "org"   = var.org
      "app"   = var.app_name
      "env"   = var.env
      "comp"  = var.comp
      "owner" = var.owner
    },
    var.extra_tags,
  )

  lifecycle {
    create_before_destroy = true
  }
}

# https://registry.terraform.io/providers/-/aws/latest/docs/resources/lb_listener_rule
# https://docs.aws.amazon.com/elasticloadbalancing/latest/application/listener-update-rules.html
resource "aws_lb_listener_rule" "this" {
  count        = var.listener_rule ? 1 : 0
  listener_arn = var.listener_arn
  priority     = var.priority

  action {
    target_group_arn = aws_lb_target_group.this.arn
    type             = "forward"
  }

  dynamic "condition" {
    for_each = length(local.hosts) > 0 ? tolist([1]) : []
    content {
      host_header {
        values = local.hosts
      }
    }
  }

  dynamic "condition" {
    for_each = length(var.paths) > 0 ? tolist([1]) : []
    content {
      path_pattern {
        values = var.paths
      }
    }
  }
}
