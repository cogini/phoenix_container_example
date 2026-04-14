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

include "root" {
  path = find_in_parent_folders()
}

inputs = {
  dns_domain = dependency.route53.outputs.name_nodot

  # Whether to create Route53 records for validation.
  # Default is true, for primary load balancer cert.
  # False when there is a cert already in another region, e.g. for CloudFront.
  # create_route53_records = false
}
