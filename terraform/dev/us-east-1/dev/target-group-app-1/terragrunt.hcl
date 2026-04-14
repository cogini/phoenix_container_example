# Create target group for blue/green deployment

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//target-group"
}
include "root" {
  path = find_in_parent_folders("root.hcl")
}
dependency "lb" {
  config_path = "../lb-public"
}
dependency "vpc" {
  config_path = "../vpc"
}

locals {
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  region_vars  = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  env_vars     = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  dns_vars     = read_terragrunt_config(find_in_parent_folders("dns.hcl"))

  account_id = local.account_vars.locals.aws_account_id
  region     = local.region_vars.locals.aws_region
  env        = local.env_vars.locals.env
  dns_domain = local.dns_vars.locals.domain
  dns_subdomain = local.dns_vars.locals.subdomain
}

inputs = {
  comp = "app"
  name = "app-1"

  hosts = [
    join(".", compact(["app", local.dns_subdomain, local.dns_domain])),
    join(".", compact([local.dns_subdomain, local.dns_domain]))
  ]

  port     = 4001
  protocol = "HTTPS"

  health_check = {
    # If you don't specify the port, it uses the same as the traffic port.
    # You still need to specify HTTPS, though.
    protocol = "HTTPS" # default HTTP
    # path = "/"
    path = "/healthz/liveness"
    # interval = 10 # default 30
    # timeout = 10 # default 5
    healthy_threshold   = 2 # default 3
    unhealthy_threshold = 2 # default 3
    matcher = "200,302" # default 200
  }

  # stickiness = {
  #   type = "lb_cookie"
  # }

  target_type = "ip" # default "instance"

  # listener_rule = true # default true
  listener_arn = dependency.lb.outputs.listener_arn

  vpc_id       = dependency.vpc.outputs.vpc_id
}
