# Create bucket for AWS request logs from CloudFront

terraform {
  source = "${dirname(find_in_parent_folders())}/modules//s3-cloudfront-logs"
}
include "root" {
  path = find_in_parent_folders()
}

inputs = {
  comp = "cloudfront-logs"

  # Force S3 buckets to be deleted even when they are not empty
  # This is useful in dev, but dangerous in prod
  # force_destroy = true
}
