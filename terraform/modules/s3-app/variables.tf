variable "comp" {
  description = "Name of the app component, app, worker, etc."
}

variable "bucket_prefix" {
  description = "Start of bucket name, default org_unique-app_name-env.comp"
  default     = ""
}

variable "buckets" {
  description = "Buckets to create"
  type = map(object({
              name    = optional(string),
              encrypt = optional(bool, false),
              cors    = optional(object({
                          allowed_headers = optional(list(string)),
                          allowed_methods = optional(list(string)),
                          allowed_origins = optional(list(string)),
                          expose_headers  = optional(list(string)),
                          max_age_seconds = optional(number),
                          })),
              public_access_block = optional(object({
                          block_public_acls = optional(bool),
                          block_public_policy = optional(bool),
                          ignore_public_acls = optional(bool),
                          restrict_public_buckets  = optional(bool),
                          })),
              website           = optional(bool, false),
              object_ownership  = optional(string),
              versioning        = optional(bool, false)
              }))
  default     = {}
}

variable "force_destroy" {
  description = "Force destroy of bucket even if it's not empty"
  default     = false
}

variable "cors_allowed_headers" {
  type    = list(any)
  default = ["*"]
}

variable "cors_allowed_methods" {
  type    = list(any)
  default = ["GET"]
}

variable "cors_allowed_origins" {
  type    = list(any)
  default = ["*"]
}

variable "cors_expose_headers" {
  type    = list(any)
  default = ["ETag"]
}

variable "cors_max_age_seconds" {
  default = "3600"
}

variable "kms_key_id" {
  description = "Custom KMS key ARN"
  default     = null
}

variable "sse_algorithm" {
  description = "Encryption algorithm. aws:kms or AES256"
  default     = "aws:kms"
}
