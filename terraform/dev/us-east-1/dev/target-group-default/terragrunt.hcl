# Create default target group for load balancer

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//target-group-default"
}
include "root" {
  path = find_in_parent_folders("root.hcl")
}
dependency "vpc" {
  config_path = "../vpc"
}

inputs = {
  # comp     = "app"
  port     = 4001
  protocol = "HTTPS" # default HTTP

  health_check = {
    # If you don't specify the port, it uses the same as the traffic port.
    # You still need to specify HTTPS, though.
    protocol            = "HTTPS" # default HTTP
    port                = 4001
    path                = "/healthz/liveness"
    interval            = 30
    timeout             = 10
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200"
  }

  # stickiness = {
  #   type = "lb_cookie"
  # }

  vpc_id = dependency.vpc.outputs.vpc_id
}
