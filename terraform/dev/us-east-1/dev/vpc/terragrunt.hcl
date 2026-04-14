# Create VPC

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//vpc"
}
include "root" {
  path = find_in_parent_folders("root.hcl")
}

inputs = {
  cidr             = "10.10.0.0/16"
  private_subnets  = ["10.10.1.0/24", "10.10.2.0/24"]
  public_subnets   = ["10.10.101.0/24", "10.10.102.0/24"]
  database_subnets = ["10.10.21.0/24", "10.10.22.0/24"]
  # elasticache_subnets = ["10.10.31.0/24", "10.10.32.0/24"]

  dhcp_options_domain_name_servers = ["127.0.0.1", "10.10.0.2"]

  create_database_subnet_group = true

  # enable_nat_gateway = true
  # single_nat_gateway = true

  enable_dns_support = true
  enable_dns_hostnames = true
}
