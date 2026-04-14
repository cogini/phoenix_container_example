# Create IAM instance profile for devops

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//iam-instance-profile-app"
}
include "root" {
  path = find_in_parent_folders("root.hcl")
}
# dependency "kms" {
#   config_path = "../kms"
# }

inputs = {
  comp = "devops"

  # Allow writing to any log group and stream
  cloudwatch_logs = ["*"]
  # cloudwatch_logs = ["log-group:*"]
  # cloudwatch_logs = ["log-group:*:log-stream:*"]

  # Enable management via SSM
  enable_ssm_management = true

  # Give access to KMS CMK
  # kms_key_arn = dependency.kms.outputs.key_arn
}
