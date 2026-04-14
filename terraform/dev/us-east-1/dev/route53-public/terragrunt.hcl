# Create Route53 hosted zone for public domain

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//route53-zone"
}
include "root" {
  path = find_in_parent_folders("root.hcl")
}
dependency "delegation-set" {
  config_path = "../route53-delegation-set"
}

locals {
  account_vars     = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  region_vars      = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  env_vars         = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  common_vars      = read_terragrunt_config(find_in_parent_folders("common.hcl"))
  dns_vars     = read_terragrunt_config(find_in_parent_folders("dns.hcl"))

  org      = local.common_vars.locals.org
  app_name = local.common_vars.locals.app_name
  env      = local.env_vars.locals.env
  dns_domain = local.dns_vars.locals.domain
  dns_subdomain = local.dns_vars.locals.subdomain
}

inputs = {
  name = join(".", compact([local.dns_subdomain, local.dns_domain]))
  delegation_set_id = dependency.delegation-set.outputs.id

  # Useful in dev, unsafe in prod
  force_destroy = true
}
