# Create NAT instance

# A NAT instance is an EC2 instance which allows traffic outbound from
# instances in the private network segment. It does the same thing as a NAT
# Gateway, but is much cheaper to run. It has performance limits and
# generally is more trouble to run, but is useful for dev or smaller apps.

terraform {
  # source = "${dirname(find_in_parent_folders())}/modules//fck-nat"
  source = "${dirname(find_in_parent_folders())}/modules//nat"
}
dependency "vpc" {
  config_path = "../vpc"
}

include "root" {
  path = find_in_parent_folders()
}

inputs = {
  # name = "main" # default is app_name

  vpc_id                      = dependency.vpc.outputs.vpc_id
  public_subnet               = dependency.vpc.outputs.public_subnets[0]
  private_subnets_cidr_blocks = dependency.vpc.outputs.private_subnets_cidr_blocks
  private_route_table_ids     = dependency.vpc.outputs.private_route_table_ids

  # image_id = "ami-0f57d652281755ea1"

  # key_name = "my-key"
  # enabled = false
}
