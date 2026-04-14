# Create NAT instance based on fck-nat

# A NAT instance is an EC2 instance which allows traffic outbound from
# instances in the private network segment. It does the same thing as a NAT
# Gateway, but is much cheaper to run. It has performance limits and
# generally is more trouble to run, but is useful for dev or smaller apps.

# https://fck-nat.dev/v1.3.0/deploying/
# https://github.com/RaJiska/terraform-aws-fck-nat

# terraform {
#   source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//fck-nat"
# }
# include "root" {
#   path = find_in_parent_folders("root.hcl")
# }
# dependency "vpc" {
#   config_path = "../vpc"
# }
#
# inputs = {
#   vpc_id                      = dependency.vpc.outputs.vpc_id
#   public_subnet               = dependency.vpc.outputs.public_subnets[0]
#   private_subnets_cidr_blocks = dependency.vpc.outputs.private_subnets_cidr_blocks
#   private_route_table_ids     = dependency.vpc.outputs.private_route_table_ids
# }

locals {
  name     = var.name == "" ? var.app_name : var.name

  tags = merge(
    {
      "org"   = var.org
      "app"   = var.app_name
      "env"   = var.env
      "owner" = var.owner
    },
    var.extra_tags,
  )
}

module "fck-nat" {
  # source = "RaJiska/fck-nat/aws"
  # version = "~> 1.2"
  # Use the latest changes in the main branch until a new release is made
  # source = "git::https://github.com/RaJiska/terraform-aws-fck-nat.git"
  source = "RaJiska/fck-nat/aws"

  name                 = local.name
  instance_type        = var.instance_type
  ami_id               = var.ami_id

  vpc_id               = var.vpc_id
  subnet_id            = var.subnet_id

  # Enable high-availability mode
  ha_mode              = var.ha_mode

  # Enable Cloudwatch agent and have metrics reported
  use_cloudwatch_agent = var.use_cloudwatch_agent

  # eip_allocation_ids   = ["eipalloc-abc1234"] # Allocation ID of an existing EIP

  update_route_tables  = var.update_route_tables
  route_tables_ids     = var.route_tables_ids

  tags = local.tags
}
