# Create VPC

terraform {
  source = "${dirname(find_in_parent_folders())}/modules//vpc"
}
include "root" {
  path = find_in_parent_folders()
}

inputs = {
  cidr             = "10.10.0.0/16"
  private_subnets  = ["10.10.1.0/24", "10.10.2.0/24"]
  database_subnets = ["10.10.21.0/24", "10.10.22.0/24"]
  public_subnets   = ["10.10.101.0/24", "10.10.102.0/24"]

  create_database_subnet_group = true

  # enable_nat_gateway = true
  # single_nat_gateway = true
}
