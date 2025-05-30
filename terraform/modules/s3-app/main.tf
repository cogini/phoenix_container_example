# Create S3 buckets for app

# Example config:
# terraform {
#   source = "${get_terragrunt_dir()}/../../../modules//s3-app"
# }
# dependency "kms" {
#   config_path = "../kms"
# }
# include {
#   path = find_in_parent_folders()
# }
#
# inputs = {
#   comp = "app"
#
#   # Force S3 buckets to be deleted even when they are not empty
#   # This is useful in dev, but dangerous in prod
#   force_destroy = true
#
#   buckets = {
#     # App assets such as CSS and JS published via CDN
#     assets = {
#     }
#     # Config files
#     config = {
#       encrypt = true
#     }
#     # Data files
#     data = {
#       encrypt = true
#     }
#     # Log files
#     logs = {
#       encrypt= true
#     }
#     # App public web files, e.g. user logos for whitelabel
#     public_web = {
#       website = true
#       acl = "public-read"
#     }
#     # App web files with controlled access, e.g. user data
#     protected_web = {
#       website = true
#       encrypt = true
#     }
#     # SSM files
#     ssm = {
#       encrypt = true
#     }
#
#     # CodeBuild cache
#     build_cache = {
#       encrypt = true
#     }
#     # CodePipeline deploy
#     deploy = {
#       encrypt = true
#     }
#   }
#
#   kms_key_id = dependency.kms.outputs.key_arn
# }

locals {
  bucket_prefix = var.bucket_prefix == "" ? "${var.org_unique}-${var.app_name}-${var.env}-${var.comp}" : var.bucket_prefix
  buckets = {
    for key, bucket in var.buckets :
    key => {
      # name    = lookup(bucket, "name", "${local.bucket_prefix}-${replace(key, "_", "-")}")
      name    = lookup(bucket, "name", null) == null ? "${local.bucket_prefix}-${replace(key, "_", "-")}" : bucket["name"]
      encrypt = lookup(bucket, "encrypt", false)
      cors    = lookup(bucket, "cors", {})
      cors_enabled = lookup(bucket, "cors", null) != null
      public_access_block    = lookup(bucket, "public_access_block", {})
      public_access_block_enabled = lookup(bucket, "public_access_block", null) != null
      website = lookup(bucket, "website", false)
      # https://docs.aws.amazon.com/AmazonS3/latest/dev/acl-overview.html#canned-acl
      # acl = lookup(bucket, "acl", null)
      # https://github.com/aws/aws-cdk/issues/25358
      # BucketOwnerPreferred, ObjectWriter or BucketOwnerEnforced
      # AWS default is BucketOwnerEnforced as of April 2023
      # https://aws.amazon.com/about-aws/whats-new/2022/12/amazon-s3-automatically-enable-block-public-access-disable-access-control-lists-buckets-april-2023/
      object_ownership = lookup(bucket, "object_ownership", "BucketOwnerEnforced")
      versioning       = lookup(bucket, "versioning", false)
    }
  }
}

# https://www.terraform.io/docs/providers/aws/r/s3_bucket.html
# https://docs.aws.amazon.com/AmazonS3/latest/dev/acl-overview.html
# https://docs.aws.amazon.com/codepipeline/latest/userguide/tutorials-simple-s3.html
resource "aws_s3_bucket" "buckets" {
  for_each = local.buckets
  bucket   = each.value.name
  # acl    = each.value.acl

  # dynamic "website" {
  #   for_each = each.value.website ? tolist([1]) : []
  #   content {
  #     index_document = "index.html"
  #     error_document = "404.html"
  #   }
  # }

  tags = merge(
    {
      "org"   = var.org
      "app"   = var.app_name
      "env"   = var.env
      "comp"  = var.comp
      "owner" = var.owner
    },
    var.extra_tags,
  )

  force_destroy = var.force_destroy
}

resource "aws_s3_bucket_website_configuration" "this" {
  for_each = { for k, v in local.buckets : k => v if v.website }
  bucket   = each.value.name

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "404.html"
  }
}

resource "aws_s3_bucket_cors_configuration" "this" {
  for_each = { for k, v in local.buckets : k => v if v.cors_enabled }
  bucket   = each.value.name

  cors_rule {
    allowed_headers = lookup(each.value.cors, "allowed_headers", null)
    allowed_methods = lookup(each.value.cors, "allowed_methods", null)
    allowed_origins = lookup(each.value.cors, "allowed_origins", null)
    expose_headers  = lookup(each.value.cors, "expose_headers", null)
    max_age_seconds = lookup(each.value.cors, "max_age_seconds", null)
  }
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block
resource "aws_s3_bucket_public_access_block" "this" {
  for_each = { for k, v in local.buckets : k => v if v.public_access_block_enabled }
  bucket   = each.value.name

  block_public_acls = lookup(each.value.public_access_block, "block_public_acls", null)
  block_public_policy = lookup(each.value.public_access_block, "block_public_policy", null)
  ignore_public_acls = lookup(each.value.public_access_block, "ignore_public_acls", null)
  restrict_public_buckets  = lookup(each.value.public_access_block, "restrict_public_buckets", null)
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  for_each = { for k, v in local.buckets : k => v if v.encrypt }
  bucket   = each.value.name

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.kms_key_id
      sse_algorithm     = var.sse_algorithm
    }
  }
}

resource "aws_s3_bucket_versioning" "this" {
  for_each = { for k, v in local.buckets : k => v if v.versioning }
  bucket   = each.value.name

  versioning_configuration {
    status = "Enabled"
  }
}

# resource "aws_s3_bucket_acl" "this" {
#   for_each = local.buckets
#
#   bucket = each.value.name
#   acl = each.value.acl
#
#   # depends_on = [aws_s3_bucket_ownership_controls.this]
# }

# resource "aws_s3_bucket_ownership_controls" "this" {
#   for_each = local.buckets
#   bucket = each.value.name
#
#   rule {
#     object_ownership = each.value.object_ownership
#   }
#
#   depends_on = [aws_s3_bucket_acl.this]
# }
