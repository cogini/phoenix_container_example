# Create S3 buckets for app

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//s3-app"
}
include "root" {
  path = find_in_parent_folders("root.hcl")
}
# dependency "kms" {
#   config_path = "../kms"
# }
# dependency "route53" {
#   config_path = "../route53-public"
#   # config_path = "../route53-cdn" # separate CDN domain
# }
# dependency "s3-access-logs" {
#   config_path = "../s3-access-logs"
# }

inputs = {
  comp = "app"

  # Force S3 buckets to be deleted even when they are not empty
  # This is useful in dev, but dangerous in prod
  # force_destroy = true

  # Give access to S3 buckets
  buckets = {
    # App assets such as CSS and JS published via CDN
    assets = {
      website = true
      cors = {
        allowed_headers = ["*"]
        allowed_methods = ["GET", "HEAD"]
        allowed_origins = ["*"]
        # allowed_origins = [
        #   "https://*.tezrac.com",
        #   "http://localhost:4000"
        # ]
        expose_headers  = ["ETag"]
        max_age_seconds = 3600
      }
      encrypt = false
    }
    # Config files
    # config = {
    #   encrypt = true
    #   logging = {
    #     target_bucket = dependency.s3-access-logs.outputs.buckets["access_logs"].id
    #   }
    # }
    # Data files
    # data = {
    #   encrypt = true
    #   # versioning = true
    # }
    # Log files
    # logs = {
    #   encrypt = true
    # }
    # App public web files, e.g. logos for whitelabel, served from S3
    # public_web = {
    #   name = "public.${dependency.route53.outputs.name_nodot}"
    # }
    # App web files with controlled access, e.g. user data
    # protected_web = {
    #   name = "protected.${dependency.route53.outputs.name_nodot}"
    # }
    # SSM log files
    # ssm = {
    #   encrypt = true
    # }

    # CodeBuild cache
    # build_cache = {
    #   encrypt = true
    # }
    # CodePipeline deploy
    # deploy = {
    #   encrypt = true
    # }
  }

  # kms_key_id = dependency.kms.outputs.key_arn
}
