variable "comp" {
  description = "Name of app component: app, worker, etc."
}

# https://docs.aws.amazon.com/autoscaling/application/APIReference/API_RegisterScalableTarget.html#API_RegisterScalableTarget_RequestParameters
variable "max_capacity" {
  description = "Maximum value to scale out to"
  type        = number
}

# https://docs.aws.amazon.com/autoscaling/application/APIReference/API_RegisterScalableTarget.html#API_RegisterScalableTarget_RequestSyntax
# Scaling down down to 0 is possible, but CloudWatch metrics will not be recorded, so you need a different trigger scale it up.
variable "min_capacity" {
  description = "Minimum value to scale in to"
  type        = number
}

variable "name" {
  description = "Name tag of instance, var.app_name-var.comp if empty"
  default     = ""
}

variable "predictive_policies" {
  description = "Define predictive scaling policy configurations"
  type        = map(object({
    # The behavior that should be applied if the forecast capacity approaches
    # or exceeds the maximum capacity. Valid values are HonorMaxCapacity and
    # IncreaseMaxCapacity.
    max_capacity_breach_behavior = optional(string)
    # Size of the capacity buffer to use when the forecast capacity is close to
    # or exceeds the maximum capacity. The value is specified as a percentage
    # relative to the forecast capacity. Required if the
    # max_capacity_breach_behavior argument is set to IncreaseMaxCapacity, and
    # cannot be used otherwise.
    max_capacity_buffer          = optional(number)

    # Metrics and target utilization to use for predictive scaling.
    metric_specification         = object({
      # Target utilization
      target_value = number

      customized_capacity_metric_specification = optional(object({
        metric_data_query = list(object({
          expression = optional(string)
          id         = string
          label      = optional(string)
          metric_stat = optional(object({
            metric      = object({
              dimension = optional(object({
                name  = string
                value = string
              }))
              metric_name = string
              namespace   = string
            })
            stat        = string
            unit        = optional(string)
          }))
          return_data = optional(bool)
        }))
      }))

      customized_load_metric_specification = optional(object({
        metric_data_query = list(object({
          expression = optional(string)
          id         = string
          label      = optional(string)
          metric_stat = optional(object({
            metric      = object({
              dimension = optional(object({
                name  = string
                value = string
              }))
              metric_name = string
              namespace   = string
            })
            stat        = string
            unit        = optional(string)
          }))
          return_data = optional(bool)
        }))
      }))

      customized_scaling_metric_specification = optional(object({
        metric_data_query = list(object({
          expression = optional(string)
          id         = string
          label      = optional(string)
          metric_stat = optional(object({
            metric      = object({
              dimension = optional(object({
                name  = string
                value = string
              }))
              metric_name = string
              namespace   = string
            })
            stat        = string
            unit        = optional(string)
          }))
          return_data = optional(bool)
        }))
      }))

      predefined_load_metric_specification = optional(object({
        predefined_metric_type = string
        # Label that uniquely identifies a target group.
        resource_label         = optional(string)
      }))

      # Predefined metric pair specification that determines the appropriate scaling metric and load metric
      predefined_metric_pair_specification = optional(object({
        # Which metrics to use. There are two different types of metrics for each
        # metric type: one is a load metric and one is a scaling metric.
        predefined_metric_type = string
        # Label that uniquely identifies a target group.
        resource_label         = optional(string)
      }))

      predefined_scaling_metric_specification = optional(object({
        predefined_metric_type = string
        # Label that uniquely identifies a specific target group from which to
        # determine the average request count.
        resource_label         = optional(string)
      }))
    })

    # Predictive scaling mode. Valid values are ForecastOnly and
    # ForecastAndScale.
    mode = optional(string)
    # Amount of time, in seconds, that the start time can be advanced.
    scheduling_buffer_time = optional(number)
  }))
  default     = {}
}

variable "resource_id" {
  description = "Identifier of resource associated with scalable target, e.g. service/<cluster>/<service> for ECS"
  type        = string
}

# https://docs.aws.amazon.com/autoscaling/application/userguide/security_iam_service-with-iam.html#security_iam_service-with-iam-roles
variable "role_arn" {
  description = "ARN of IAM role allowing Application AutoScaling to modify target. Defaults to IAM Service-Linked Role for most services and custom IAM Roles are ignored."
  type        = string
  default     = null
}

# https://docs.aws.amazon.com/autoscaling/application/APIReference/API_RegisterScalableTarget.html#API_RegisterScalableTarget_RequestSyntax
variable "scalable_dimension" {
  description = "Scalable dimension associated with scalable target: ecs:service:DesiredCount, ec2:spot-fleet-request:TargetCapacity, etc."
  type        = string
}

variable "service_namespace" {
  description = "AWS service namespace of the scalable target: ecs, ec2, etc."
  type        = string
}

variable "step_policies" {
  description = "Define step policy configurations"
  type        = map(object({
    # Whether the adjustment is an absolute number or a percentage of the
    # current capacity. Valid values are ChangeInCapacity, ExactCapacity, and
    # PercentChangeInCapacity.
    adjustment_type        = string
    # Amount of time, in seconds, after a scaling activity completes and before
    # the next scaling activity can start.
    cooldown               = number
    # Aggregation type for the policy's metrics. Valid values are "Minimum",
    # "Maximum", and "Average". Without a value, AWS will treat the aggregation
    # type as "Average".
    metric_aggregation_type = optional(string)
    # Minimum number to adjust your scalable dimension as a result of a scaling
    # activity. If the adjustment type is PercentChangeInCapacity, the scaling
    # policy changes the scalable dimension of the scalable target by this
    # amount.
    min_adjustment_magnitude = optional(number)
    # Set of adjustments that manage scaling
    step_adjustment        = optional(list(object({
      # Lower bound for the difference between the alarm threshold and the
      # CloudWatch metric. Without a value, AWS will treat this bound as
      # negative infinity.
      metric_interval_lower_bound = optional(number)
      # Upper bound for the difference between the alarm threshold and the
      # CloudWatch metric. Without a value, AWS will treat this bound as
      # infinity. The upper bound must be greater than the lower bound.
      metric_interval_upper_bound = optional(number)
      # Number of members by which to scale, when the adjustment bounds are
      # breached. A positive value scales up. A negative value scales down.
      scaling_adjustment         = number
    })))
  }))
  default     = {}
}

variable "suspended_state" {
  description = "Specifies whether scaling activities for target are in suspended state."
  type        = object({
    dynamic_scaling_in_suspended  = optional(bool)
    dynamic_scaling_out_suspended = optional(bool)
    scheduled_scaling_suspended   = optional(bool)
  })
  default     = null
}

variable "target_tracking_policies" {
  description = "Define target tracking scaling policy configuraions"
  type        = map(object({
    target_value           = number
    # Whether scale in by the target tracking policy is disabled. If the value
    # is true, scale in is disabled and the target tracking policy won't remove
    # capacity from the scalable resource. Otherwise, scale in is enabled and
    # the target tracking policy can remove capacity from the scalable
    # resource. The default value is false.
    disable_scale_in       = optional(bool)
    # Amount of time, in seconds, after a scale out activity completes before
    # another scale out activity can start.
    scale_in_cooldown      = optional(number)
    # Amount of time, in seconds, after a scale out activity completes before
    # another scale out activity can start.
    scale_out_cooldown     = optional(number)
    customized_metric_specification = optional(object({
      metric_name = optional(string)
      namespace   = optional(string)
      statistic   = optional(string) # Average, Minimum, Maximum, SampleCount, Sum
      unit        = optional(string)
      # Metrics to include, as a metric data query
      metrics     = optional(list(object({
        # expression or metrics must be specified, but not both
        expression = optional(string)
        id         = string
        label      = optional(string)

        metric_stat = optional(object({
          metric      = object({
            dimensions = optional(object({
              name  = string
              value = string
            }))
            metric_name = string
            namespace   = string
          })
          stat        = string
          unit        = optional(string)
        }))
        return_data = optional(bool)
      })))

      # Configuration block(s) with the dimensions of the metric if the metric
      # was published with dimensions.
      dimensions  = optional(list(object({
        name  = string
        value = string
      })))
    }))
    predefined_metric_specification = optional(object({
      predefined_metric_type = string,
      # for ECSServiceAverageCPUUtilization and ECSServiceAverageMemoryUtilization
      # Must be specified if predefined_metric_type is ALBRequestCountPerTarget.
      # See https://docs.aws.amazon.com/autoscaling/plans/APIReference/API_PredefinedScalingMetricSpecification.html
      resource_label         = optional(string)
    }))
  }))
  default     = {}
}
