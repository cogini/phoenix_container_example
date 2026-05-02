# Configure Application Auto Scaling

# https://docs.aws.amazon.com/autoscaling/application/userguide/what-is-application-auto-scaling.html
# https://docs.aws.amazon.com/AmazonECS/latest/developerguide/service-auto-scaling.html

# Example config:
# terraform {
#   source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//autoscaling"
# }
# include "root"{
#   path = find_in_parent_folders("root.hcl")
# }
# dependency "ecs-cluster" {
#   config_path = "../ecs-cluster"
# }
# dependency "ecs-service" {
#   config_path = "../ecs-service-app"
# }
#
# inputs = {
#   comp               = "app"
#   min_capacity       = 1
#   max_capacity       = 2
#   resource_id        = "service/${dependency.ecs_cluster.outputs.name}/${dependency.ecs_service.outputs.name}"
#   scalable_dimension = "ecs:service:DesiredCount"
#   service_namespace  = "ecs"
#
#   scaling_policies = {
#     target_tracking = {
#       name        = "app-media-target-tracking"
#       policy_type = "TargetTrackingScaling"
#
#       type_ = {
#         predefined_metric_type = "ECSServiceAverageCPUUtilization"
#         target_value       = 75
#         scale_in_cooldown  = 300
#         scale_out_cooldown = 300
#       }
#     }
#   }
# }

locals {
  name = var.name == "" ? "${var.app_name}-${var.comp}" : var.name
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_target.html
resource "aws_appautoscaling_target" "this" {
  max_capacity       = var.max_capacity
  min_capacity       = var.min_capacity
  resource_id        = var.resource_id
  scalable_dimension = var.scalable_dimension
  service_namespace  = var.service_namespace

  dynamic "suspended_state" {
    for_each = var.suspended_state[*]
    content {
      dynamic_scaling_in_suspended  = lookup(suspended_state.value, "dynamic_scaling_in_suspended", null)
      dynamic_scaling_out_suspended = lookup(suspended_state.value, "dynamic_scaling_out_suspended", null)
      scheduled_scaling_suspended   = lookup(suspended_state.value, "scheduled_scaling_suspended", null)
    }
  }
}

resource "aws_appautoscaling_policy" "predictive" {
  for_each           = var.predictive_policies
  name               = each.key
  policy_type        = "PredictiveScaling"

  resource_id        = aws_appautoscaling_target.this.resource_id
  scalable_dimension = aws_appautoscaling_target.this.scalable_dimension
  service_namespace  = aws_appautoscaling_target.this.service_namespace

  predictive_scaling_policy_configuration {
    max_capacity_breach_behavior = lookup(each.value, "max_capacity_breach_behavior", null)
    max_capacity_buffer          = lookup(each.value, "max_capacity_buffer", null)
    mode                         = lookup(each.value, "mode", null)
    scheduling_buffer_time       = lookup(each.value, "scheduling_buffer_time", null)

    metric_specification {
      target_value = each.value.metric_specification.target_value

      dynamic "customized_capacity_metric_specification" {
        for_each = lookup(each.value.metric_specification, "customized_capacity_metric_specification", null)[*]
        content {
          dynamic "metric_data_query" {
            for_each = customized_capacity_metric_specification.value.metric_data_query[*]
            content {
              expression = lookup(metric_data_query.value, "expression", null)
              id         = metric_data_query.value.id
              label      = lookup(metric_data_query.value, "label", null)

              dynamic "metric_stat" {
                for_each = lookup(metric_data_query.value, "metric_stat", null)[*]
                content {
                  dynamic "metric" {
                    for_each = lookup(metric_stat.value, "metric", null)[*]
                    content {
                      dynamic "dimension" {
                        for_each = lookup(metric.value, "dimension", null)[*]
                        content {
                          name  = dimensions.value.name
                          value = dimensions.value.value
                        }
                      }

                      metric_name = metric.value.metric_name
                      namespace   = metric.value.namespace
                    }
                  }

                  stat   = lookup(metric_stat.value, "stat", null)
                  unit   = lookup(metric_stat.value, "unit", null)
                }
              }
              return_data = lookup(metric_data_query.value, "return_data", null)
            }
          }
        }
      }

      dynamic "customized_load_metric_specification" {
        for_each = lookup(each.value.metric_specification, "customized_load_metric_specification", null)[*]
        content {
          dynamic "metric_data_query" {
            for_each = customized_load_metric_specification.value.metric_data_query[*]
            content {
              expression = lookup(metric_data_query.value, "expression", null)
              id         = metric_data_query.value.id
              label      = lookup(metric_data_query.value, "label", null)

              dynamic "metric_stat" {
                for_each = lookup(metric_data_query.value, "metric_stat", null)[*]
                content {
                  dynamic "metric" {
                    for_each = lookup(metric_stat.value, "metric", null)[*]
                    content {
                      dynamic "dimension" {
                        for_each = lookup(metric.value, "dimension", null)[*]
                        content {
                          name  = dimensions.value.name
                          value = dimensions.value.value
                        }
                      }

                      metric_name = metric.value.metric_name
                      namespace   = metric.value.namespace
                    }
                  }

                  stat   = lookup(metric_stat.value, "stat", null)
                  unit   = lookup(metric_stat.value, "unit", null)
                }
              }
              return_data = lookup(metric_data_query.value, "return_data", null)
            }
          }
        }
      }

      dynamic "customized_load_metric_specification" {
        for_each = lookup(each.value.metric_specification, "customized_load_metric_specification", null)[*]
        content {

          dynamic "metric_data_query" {
            for_each = lookup(customized_load_metric_specification.value, "metric_data_query", null)[*]
            content {
              expression = lookup(metric_data_query.value, "expression", null)
              id         = lookup(metric_data_query.value, "id", null)
              label      = lookup(metric_data_query.value, "label", null)

              dynamic "metric_stat" {
                for_each = lookup(metric_data_query.value, "metric_stat", null)[*]
                content {
                  metric = lookup(metric_stat.value, "metric_name", null)

                  dynamic "metric" {
                    for_each = lookup(metric_stat.value, "metric", null)[*]
                    content {
                      dynamic "dimension" {
                        for_each = lookup(metric.value, "dimension", null)[*]
                        content {
                          name  = dimensions.value.name
                          value = dimensions.value.value
                        }
                      }

                      metric_name = metric.value.metric_name
                      namespace   = metric.value.namespace
                    }
                  }

                  stat   = lookup(metric_stat.value, "stat", null)
                  unit   = lookup(metric_stat.value, "unit", null)
                }
              }
              return_data = lookup(metric_data_query.value, "return_data", null)
            }
          }
        }
      }

      dynamic "customized_scaling_metric_specification" {
        for_each = lookup(each.value.metric_specification, "customized_scaling_metric_specification", null)[*]
        content {

          dynamic "metric_data_query" {
            for_each = lookup(customized_scaling_metric_specification.value, "metric_data_query", null)[*]
            content {
              expression = lookup(metric_data_query.value, "expression", null)
              id         = lookup(metric_data_query.value, "id", null)
              label      = lookup(metric_data_query.value, "label", null)

              dynamic "metric_stat" {
                for_each = lookup(metric_data_query.value, "metric_stat", null)[*]
                content {
                  dynamic "metric" {
                    for_each = lookup(metric_stat.value, "metric", null)[*]
                    content {
                      dynamic "dimension" {
                        for_each = lookup(metric.value, "dimension", null)[*]
                        content {
                          name  = dimensions.value.name
                          value = dimensions.value.value
                        }
                      }

                      metric_name = metric.value.metric_name
                      namespace   = metric.value.namespace
                    }
                  }

                  stat   = lookup(metric_stat.value, "stat", null)
                  unit   = lookup(metric_stat.value, "unit", null)
                }
              }
              return_data = lookup(metric_data_query.value, "return_data", null)
            }
          }
        }
      }

      dynamic "predefined_load_metric_specification" {
        for_each = lookup(each.value.metric_specification, "predefined_load_metric_specification", null)[*]
        content {
           predefined_metric_type = lookup(predefined_load_metric_specification.value, "predefined_metric_type", null)
           resource_label         = lookup(predefined_load_metric_specification.value, "resource_label", null)
        }
      }

      dynamic "predefined_metric_pair_specification" {
        for_each = lookup(each.value.metric_specification, "predefined_metric_pair_specification", null)[*]
        content {
           predefined_metric_type = lookup(predefined_metric_pair_specification.value, "predefined_metric_type", null)
           resource_label         = lookup(predefined_metric_pair_specification.value, "resource_label", null)
        }
      }

      dynamic "predefined_scaling_metric_specification" {
        for_each = lookup(each.value.metric_specification, "predefined_scaling_metric_specification", null)[*]
        content {
           predefined_metric_type = lookup(predefined_scaling_metric_specification.value, "predefined_metric_type", null)
           resource_label         = lookup(predefined_scaling_metric_specification.value, "resource_label", null)
        }
      }
    }
  }
}

resource "aws_appautoscaling_policy" "step" {
  for_each           = var.step_policies
  name               = each.key
  policy_type        = "StepScaling"

  resource_id        = aws_appautoscaling_target.this.resource_id
  scalable_dimension = aws_appautoscaling_target.this.scalable_dimension
  service_namespace  = aws_appautoscaling_target.this.service_namespace

  step_scaling_policy_configuration {
    adjustment_type          = each.value.adjustment_type
    cooldown                 = each.value.cooldown
    metric_aggregation_type  = lookup(each.value, "metric_aggregation_type", null)
    min_adjustment_magnitude = lookup(each.value, "min_adjustment_magnitude", null)

    dynamic "step_adjustment" {
      for_each = each.value.step_adjustment[*]
      content {
        metric_interval_lower_bound = lookup(step_adjustment.value, "metric_interval_lower_bound", null)
        metric_interval_upper_bound = lookup(step_adjustment.value, "metric_interval_upper_bound", null)
        scaling_adjustment          = step_adjustment.value.scaling_adjustment
      }
    }
  }
}

resource "aws_appautoscaling_policy" "tracking" {
  for_each           = var.target_tracking_policies
  name               = each.key
  policy_type        = "TargetTrackingScaling"

  resource_id        = aws_appautoscaling_target.this.resource_id
  scalable_dimension = aws_appautoscaling_target.this.scalable_dimension
  service_namespace  = aws_appautoscaling_target.this.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = each.value.target_value
    disable_scale_in   = lookup(each.value, "disable_scale_in", null)
    scale_in_cooldown  = lookup(each.value, "scale_in_cooldown", null)
    scale_out_cooldown = lookup(each.value, "scale_out_cooldown", null)

    dynamic "customized_metric_specification" {
      for_each = lookup(each.value, "customized_metric_specification", null)[*]
      content {
        metric_name = lookup(customized_metric_specification.value, "metric_name", null)
        namespace   = lookup(customized_metric_specification.value, "namespace", null)
        statistic   = lookup(customized_metric_specification.value, "statistic", null)
        unit        = lookup(customized_metric_specification.value, "unit", null)

        dynamic "metrics" {
          for_each = lookup(customized_metric_specification.value, "metrics", null)[*]
          content {
            expression = lookup(metrics.value, "expression", null)
            id         = lookup(metrics.value, "id", null)
            label      = lookup(metrics.value, "label", null)
  
            dynamic "metric_stat" {
              for_each = lookup(metrics.value, "metric_stat", null)[*]
              content {
                dynamic "metric" {
                  for_each = lookup(metric_stat.value, "metric", null)[*]
                  content {
                    dynamic "dimensions" {
                      for_each = lookup(metric.value, "dimensions", null)[*]
                      content {
                        name  = dimensions.value.name
                        value = dimensions.value.value
                      }
                    }
  
                    metric_name = metric.value.metric_name
                    namespace   = metric.value.namespace
                  }
                }
  
                stat   = lookup(metric_stat.value, "stat", null)
                unit   = lookup(metric_stat.value, "unit", null)
              }
            }
            return_data  = lookup(metrics.value, "return_data", null)
          }
        }
  
        dynamic "dimensions" {
          for_each = lookup(customized_metric_specification.value, "dimensions", null)[*]
          content {
            name  = dimensions.value.name
            value = dimensions.value.value
          }
        }
      }
    }

    dynamic "predefined_metric_specification" {
      for_each = lookup(each.value, "predefined_metric_specification", null)[*]
      content {
        predefined_metric_type = predefined_metric_specification.value.predefined_metric_type
        resource_label = lookup(predefined_metric_specification.value, "resource_label", null)
      }
    }
  }
}

