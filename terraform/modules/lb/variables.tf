variable "access_logs_bucket_id" {
  description = "S3 bucket for logs"
}

variable "access_logs_bucket_path_prefix" {
  description = "S3 bucket prefix"
  default     = "lb/"
}

variable "comp" {
  description = "Name of the component, app, worker, etc."
  default     = "public"
}

variable "default_action" {
  description = "Default action for the listener"
  type       = object({
    # type of routing action: forward, redirect, fixed-response,
    # authenticate-cognito, or authenticate-oidc.
    type             = string,
    fixed_response  = optional(object({
      content_type = string,
      message_body = optional(string),
      # The HTTP response code (2XX, 4XX, or 5XX)
      status_code  = optional(number)
    })),
    redirect = optional(object({
      # Hostname. Not percent-encoded. Can contain #{host}. Defaults to #{host}
      host        = optional(string),
      # Path. Valid values are a URL path, such as /img/route.png, or #{path}.
      # Absolute path, starting with the leading "/". This component is not
      # percent-encoded. The path can contain #{host}, #{path}, and #{port}.
      # Defaults to /#{path}.
      path        = optional(string),
      # Port. Valid values are 1-65535 or #{port}.
      port        = optional(number),
      # Protocol. Valid values are HTTP, HTTPS, or #{protocol}.
      protocol    = optional(string),
      # Query parameters. URL-encoded when necessary, but not percent-encoded.
      # Do not include the leading "?". Defaults to #{query}.
      query       = optional(string),
      # The HTTP response code: HTTP_301 or HTTP_302
      status_code = string
    }))
  })
  default = null
}

variable "dns_domain" {
  description = "DNS domain name, used to find certs"
  default     = ""
}

variable "enable_acm_cert" {
  description = "Use AWS Certificate Manager to manage cert"
  default     = true
}

variable "enable_deletion_protection" {
  description = "If true, deletion of the load balancer will be disabled via the AWS API. This will prevent Terraform from deleting the load balancer"
  default     = false
}

variable "enable_http" {
  description = "Enable unencrypted HTTP"
  default     = false
}

variable "enable_iam_cert" {
  description = "Use IAM to manage cert, exclusive to enable_acm_certificate"
  default     = false
}

variable "idle_timeout" {
  description = "The time in seconds that the connection is allowed to be idle"
  default     = 60
}

variable "internal" {
  description = "Whether LB is internal or public"
  default     = false
}

variable "ip_address_type" {
  description = "The type of IP addresses used by the subnets for your load balancer. The possible values are ipv4 and dualstack"

  # default     = "dualstack"
  default = "ipv4"
}

variable "name" {
  description = "Name of the instance, var.app_name-var.comp if blank"
  default     = ""
}

variable "subnet_ids" {
  description = "List of subnet ids"
  type        = list(any)
}

variable "security_group_ids" {
  description = "List of security group ids"
  type        = list(any)
}

# https://docs.aws.amazon.com/elasticloadbalancing/latest/classic/elb-security-policy-table.html
variable "ssl_policy" {
  description = "SSL security policy"
  default     = null
}

variable "target_group_arn" {
  description = "Default Target Group ARN"
  default     = null
}
