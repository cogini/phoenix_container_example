# Create Route53 delgation set
#
# This is a set of nameservers which will be used when creating a zone.
# It's useful to create it separately from the zone, as you can then specify
# the nameservers for the domain in the registrar and they will stay the same
# even if you delete the Route53 zone and create it again.
#
# terragrunt import aws_route53_delegation_set.main N00459021OGOQ0Z7P9GHG

terraform {
  source = "${dirname(find_in_parent_folders())}/modules//route53-delegation-set"
}

include "root" {
  path = find_in_parent_folders()
}

inputs = {
  # Optional name
  reference_name = "main"
}
