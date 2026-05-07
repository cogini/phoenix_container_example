# Configure Auto Scaling for ECS Service

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//autoscaling"
}
include "root" {
  path = find_in_parent_folders("root.hcl")
}
dependency "ecs-cluster" {
  config_path = "../ecs-cluster"
}
dependency "ecs-service" {
  config_path = "../ecs-service-worker"
}

inputs = {
  comp               = "worker"

  max_capacity       = 4
  # Minimum capacity of 0 allows scaling down to no instances when there is no
  # work to save cost. You will need some other mechanism to wake up the
  # service when there is work to be done.
  # min_capacity       = 1
  min_capacity       = 0

  resource_id        = "service/${dependency.ecs-cluster.outputs.name}/${dependency.ecs-service.outputs.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  target_tracking_policies = {
    worker-target-tracking-average-cpu-utilization = {
      target_value           = 75
      # scale_in_cooldown      = 30
      # scale_out_cooldown     = 30
      predefined_metric_specification = {
        predefined_metric_type = "ECSServiceAverageCPUUtilization"
      }
    },

    # worker-target-tracking-sqs = {
    #   target_value           = 75
    #   # scale_in_cooldown      = 30
    #   # scale_out_cooldown     = 30
    #   customized_metric_specification {
    #     metric_name = "ApproximateNumberOfMessagesVisible"
    #     namespace   = "AWS/SQS"
    #     statistic   = "Average"
    #     dimensions {
    #       name  = "QueueName"
    #       value = aws_sqs_queue.my_queue.name
    #     }
    #   }
    # }
  }
}
