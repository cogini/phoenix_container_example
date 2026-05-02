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
  min_capacity       = 1
  resource_id        = "service/${dependency.ecs-cluster.outputs.name}/${dependency.ecs-service.outputs.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  target_tracking_policies = {
    worker-target-tracking-average-cpu-utilization = {
      target_value           = 75
      scale_in_cooldown      = 300
      scale_out_cooldown     = 300

      predefined_metric_specification = {
        predefined_metric_type = "ECSServiceAverageCPUUtilization"
      }
    }
  }
}
