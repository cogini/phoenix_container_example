locals {
  aws_account_name = get_env("AWS_ACCOUNT_NAME", "")
  aws_account_id   = get_env("AWS_ACCOUNT_ID", "")
  aws_profile      = get_env("AWS_PROFILE", "")
}
