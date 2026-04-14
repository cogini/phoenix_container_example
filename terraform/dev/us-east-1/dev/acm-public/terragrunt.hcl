# Create cert using Amazon Certificate Manager for public domain.

# Cert is for base domain and wildcard.
# Cert for load balancer is created in region where load balancer runs.
# CloudFront certs must be created in us-east-1 region.

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//acm"
}
include "root" {
  path = find_in_parent_folders("root.hcl")
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
  dns_domain = join(".", compact([local.dns_subdomain, local.dns_domain]))

  # Whether to create Route53 records for validation.
  # Default is true, for primary load balancer cert.
  # False when there is a cert already in another region, e.g. for CloudFront.
  # create_route53_records = false
}
