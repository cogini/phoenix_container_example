# Create load balancer rules which directs traffic to ellie service by path

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//lb-listener-rule"
}
include "root" {
  path = find_in_parent_folders("root.hcl")
}
dependency "lb" {
  config_path = "../lb-public"
}
dependency "tg-1" {
  config_path = "../target-group-app-1"
}
dependency "tg-2" {
  config_path = "../target-group-app-2"
}

locals {
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  region_vars  = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  env_vars     = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  dns_vars     = read_terragrunt_config(find_in_parent_folders("dns.hcl"))

  account_id    = local.account_vars.locals.aws_account_id
  region        = local.region_vars.locals.aws_region
  env           = local.env_vars.locals.env
  dns_domain    = local.dns_vars.locals.domain
  dns_subdomain = local.dns_vars.locals.subdomain
}

inputs = {
  listener_arn = dependency.lb.outputs.listener_arn
  # priority        = 100

  # target_group_arns = [
  #   dependency.tg-1.outputs.arn,
  #   # dependency.tg-2.outputs.arn
  # ]

  target_groups = [
    {
      arn = dependency.tg-1.outputs.arn
      # weight = 100
    },
    # {
    #   arn = dependency.tg-2.outputs.arn
    #   weight = 100
    # }
  ]

  conditions = [
    {
      # path_pattern = {
      #   values = [
      #     "/api/v1/mediaServices*", # Used to setup/create a session
      #     "/mediaSessions*"         # Handles client interactions for a session
      #   ]
      # }

      host_header = {
        values = [
          join(".", compact(["api", local.dns_subdomain, local.dns_domain]))
        ]
      }
    }
  ]
}
