# Create SNS topic

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//sns"
}
include "root" {
  path = find_in_parent_folders("root.hcl")
}

inputs = {
  comp = "codedeploy"
}
