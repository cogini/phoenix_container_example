variable "artifacts_bucket_arn" {
  description = "S3 bucket with CodePipeline artifacts, needed for CodeDeploy"
  default     = ""
}

variable "assume_role_policy_principals" {
  description = "Additional principals to add to assume role policy"
  type        = list(object({
    type        = string
    identifiers = list(string)
  }))
  default     = []
}

variable "comp" {
  description = "Component, e.g., app, worker"
}

variable "cloudwatch_logs" {
  description = "CloudWatch Logs"
  type        = list(any)
  default     = []
}

variable "cloudwatch_logs_prefix" {
  description = "CloudWatch Logs, arn:aws:logs:*:* if blank"
  default     = ""
}

variable "cloudwatch_metrics_namespace" {
  description = "CloudWatch metrics namespace, * for any"
  default     = ""
}

variable "create_instance_profile" {
  description = "Whether to create instance profile or just role"
  default     = true
}

variable "enable_codedeploy" {
  description = "Allow instance to install via CodeDeploy"
  default     = false
}

variable "enable_cwl_readonly" {
  description = "Enables readonly access to CloudWatch Logs"
  default     = false
}

variable "enable_ec2_readonly" {
  description = "Allow instance to read EC2 details from other instances"
  default     = false
}

variable "enable_ecs_readonly" {
  description = "Allow instance to read ECS details"
  default     = false
}

variable "enable_ec2_describe_instances" {
  description = "Enable reading EC2 instance metadata"
  default     = false
}

variable "enable_ec2_describe_tags" {
  description = "Enable reading EC2 instance metadata"
  default     = false
}

variable "enable_ses" {
  description = "Allow sending to SES"
  default     = false
}

variable "enable_ssm_management" {
  description = "Allow instance to be managed via SSM"
  default     = false
}

variable "kms_key_arn" {
  description = "KMS CMK key ARN"
  default     = null
}

variable "name" {
  description = "Override name, default app_name-comp"
  default     = ""
}

variable "prometheus" {
  description = "Allow sending traces to AWS Prometheus"
  type        = bool
  default     = false
}

variable "prometheus_query" {
  description = "Allow querying AWS Prometheus"
  type        = bool
  default     = false
}

variable "prometheus_query_arns" {
  description = "Allow querying AWS Prometheus servers with these ARNs"
  type        = list(string)
  default     = ["*"]
}

variable "s3_buckets" {
  description = "S3 bucket access"
  type        = map(any)
  default     = {}
}

variable "sqs_queues" {
  description = "SQS queue ARNs"
  type        = list(string)
  default     = []
}

variable "ssm_ps_param_prefix" {
  description = "Prefix for SSM Parameter Store parameters, default env/org/app/comp"
  default     = ""
}

variable "ssm_ps_params" {
  description = "Names of SSM Parameter Store parameters"
  type        = list(any)
  default     = []
}

variable "xray" {
  description = "Allow sending traces to X-Ray"
  type        = bool
  default     = false
}
