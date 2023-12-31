# Create IAM OpenID connect provider for GitHub Action

include {
  path = find_in_parent_folders()
}

terraform {
  source = "${dirname(find_in_parent_folders())}/modules//iam-openid-connect-provider-github"
}

inputs = {}
