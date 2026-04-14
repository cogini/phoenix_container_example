# Create Load Balancer in public subnet

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//lb"
}
include "root" {
  path = find_in_parent_folders("root.hcl")
}
dependency "s3" {
  config_path = "../s3-request-logs"
}
dependency "sg" {
  config_path = "../sg-lb-public"
}
dependency "tg" {
  config_path = "../target-group-default"
}
dependency "vpc" {
  config_path = "../vpc"
}
dependencies {
  paths = [
    "../acm-public",
  ]
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
  comp = "public"
  # name = "foo" # legacy

  access_logs_bucket_id = dependency.s3.outputs.buckets["logs"].id
  subnet_ids            = dependency.vpc.outputs.subnets["public"]
  security_group_ids    = [dependency.sg.outputs.security_group_id]
  target_group_arn      = dependency.tg.outputs.arn
  dns_domain            = join(".", compact([local.dns_subdomain, local.dns_domain]))
}
