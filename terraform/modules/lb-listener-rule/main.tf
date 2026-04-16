# Create load balancer listener rule

# Example config:
# terraform {
#   source = "${dirname(find_in_parent_folders())}/../modules//lb-listener-rule"
# }
# include "root" {
#   path = find_in_parent_folders()
# }
# dependency "lb" {
#   config_path = "../lb-public"
# }
# dependency "tg-1" {
#   config_path = "../target-group-app-ecs-ellie-1"
# }
# dependency "tg-2" {
#   config_path = "../target-group-app-ecs-ellie-2"
# }
#
# inputs = {
#   listener_arn = dependency.lb.outputs.listener_arn
#   # priority        = 100
#
#   target_group_arns = [
#     # dependency.tg-1.outputs.arn,
#     dependency.tg-2.outputs.arn
#   ]
#
#   conditions = [
#     {
#       path_pattern = {
#         values = [
#           "/api/v1/mediaServices/*", # Used to setup/create a session
#           "/mediaSessions/*"         # Handles client interactions for a session
#         ]
#       }
#     }
#   ]
# }

resource "aws_lb_listener_rule" "this" {
  listener_arn = var.listener_arn
  priority     = var.priority

  action {
    type = "forward"

    forward {
      dynamic "target_group" {
        for_each = var.target_group_arns
        iterator = target_group_arn
        content {
          arn = target_group_arn.value
        }
      }

      dynamic "target_group" {
        for_each = var.target_groups
        content {
          arn = lookup(target_group.value, "arn", null)
          weight = lookup(target_group.value, "weight", null)
        }
      }

      dynamic "stickiness" {
        for_each = var.stickiness_enabled ? tolist([1]) : []
        content {
          enabled  = var.stickiness_enabled
          duration = var.stickiness_duration
        }
      }
    }
  }

  dynamic "condition" {
    for_each = var.conditions
    iterator = condition
    content {
      dynamic "host_header" {
        for_each = lookup(condition.value, "host_header", null) != null ? [condition.value.host_header] : []
        iterator = host_header
        content {
          values = host_header.value.values
        }
      }

      dynamic "http_header" {
        for_each = lookup(condition.value, "http_header", null) != null ? [condition.value.http_header] : []
        iterator = http_header
        content {
          http_header_name = http_header.value.http_header_name
          values           = http_header.value.values
        }
      }

      dynamic "http_request_method" {
        for_each = lookup(condition.value, "http_request_method", null) != null ? [condition.value.http_request_method] : []
        iterator = http_request_method
        content {
          values = http_request_method.value
        }
      }

      dynamic "path_pattern" {
        for_each = lookup(condition.value, "path_pattern", null) != null ? [condition.value.path_pattern] : []
        iterator = path_pattern
        content {
          values = path_pattern.value.values
        }
      }

      dynamic "query_string" {
        for_each = lookup(condition.value, "query_string", null) != null ? [condition.value.query_string] : []
        iterator = query_string
        content {
          key   = query_string.value.key
          value = query_string.value.value
        }
      }

      dynamic "source_ip" {
        for_each = lookup(condition.value, "source_ip", null) != null ? [condition.value.source_ip] : []
        iterator = source_ip
        content {
          values = source_ip.value
        }
      }
    }
  }
}
