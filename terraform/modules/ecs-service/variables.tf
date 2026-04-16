variable "capacity_provider_strategy" {
  description = "Capacity provider strategy"
  type        = list(
    object({
      capacity_provider = string
      weight            = optional(number)
      base              = optional(number)
    })
  )
  default     = []
}

variable "cluster" {
  description = "ECS cluster ARN"
  type        = string
  default     = null
}

variable "comp" {
  description = "Name of the app component, app, worker, etc."
}

variable "deployment_controller_type" {
  description = "Deployment controller type: CODE_DEPLOY or ECS. Default: ECS"
  type        = string
  default     = null
}

variable "deployment_configuration" {
  description = "Deployment configuration"
  type    = object({
    # Number of minutes to wait after a new deployment is fully provisioned
    # before terminating the old deployment. Valid range: 0-1440 minutes.
    # Used with BLUE_GREEN, LINEAR, and CANARY strategies.
    bake_time_in_minutes = optional(number)
    canary_configuration = optional(object({
      # Minutes to wait before shifting all traffic to the new deployment.
      # Valid range: 0-1440 minutes.
      canary_bake_time_in_minutes = optional(number)
      # Percentage of traffic to route to the canary deployment.
      # Valid range: 0.1-100.0.
      canary_percent = number
    }))
    lifecycle_hook = optional(object({
      hook_details = optional(string)
      hook_target_arn = string
      # Stages during the deployment when the hook should be invoked.
      # One or more of "RECONCILE_SERVICE", "PRE_SCALE_UP", "POST_SCALE_UP", "TEST_TRAFFIC_SHIFT",
      # "POST_TEST_TRAFFIC_SHIFT", "PRODUCTION_TRAFFIC_SHIFT", "POST_PRODUCTION_TRAFFIC_SHIFT"
      lifecycle_stages = list(string)
      # ARN of IAM role that grants the service permission to invoke the Lambda function.
      role_arn = string
    }))
    linear_configuration = optional(object({
      # Percentage of traffic to shift in each step during a linear deployment. Valid range: 3.0-100.0.
      step_percent = number
      # Minutes to wait between each step during a linear deployment. Valid range: 0-1440 minutes.
      step_bake_time_in_minutes = optional(number)
    }))
    strategy = optional(string) # ROLLING, BLUE_GREEN, LINEAR, CANARY. Default: ROLLING
  })
  default = null
}

variable "deployment_maximum_percent" {
  description = "Upper limit (percentage of desired_count) of running tasks that can be running in a service during a deployment"
  # Default 200% for REPLICA, 100% for DAEMON
  default = null
}

variable "deployment_minimum_healthy_percent" {
  description = "Lower limit (pct of desired_count) of running tasks that must remain running and healthy in a service during a deployment"
  # Default 100%, 0% for DAEMON
  default = null
}

variable "desired_count" {
  description = "Number of instances of the task to place and keep running"
  # Default 0
  default = null
}

variable "enable_execute_command" {
  description = "Enable Amazon ECS Exec"
  default     = null
}

variable "family_name" {
  description = "Name tag task definition family, name if blank"
  default     = ""
}

variable "force_new_deployment" {
  description = "Force new task deployment of the service"
  default     = null
}

# https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-using-tags.html#tag-resources-for-billing
variable "enable_ecs_managed_tags" {
  description = "Enable Amazon ECS managed tags for the tasks within the service"
  type        = bool
  default     = null
}

variable "health_check_grace_period_seconds" {
  description = "Seconds to ignore failing load balancer health checks on newly instantiated tasks to prevent premature shutdown"
  # Default 0
  default = null
}

variable "iam_role" {
  description = "ARN of IAM role that allows Amazon ECS to make calls to load balancer on your behalf"
  # This parameter is required if you are using a load balancer with your
  # service, but only if your task definition does not use the awsvpc network
  # mode. If using awsvpc network mode, do not specify this role.
  # If your account has already created the Amazon ECS service-linked role,
  # that role is used by default for your service unless you specify a role
  # here.
  type    = string
  default = null
}

variable "launch_type" {
  description = "Launch type: EC2 or FARGATE"
  # Default EC2
  default = null
}

variable "load_balancer" {
  description = "List of load balancer configs"
  type = list(object({
    advanced_configuration = optional(object({
      # ARN of alternate target group for Blue/Green deployments
      alternate_target_group_arn = string,
      # ARN of listener rule that routes production traffic
      production_listener_rule = string,
      # ARN of IAM role that allows ECS to manage the target groups
      role_arn = string
      # ARN of listener rule that routes test traffic
      test_listener_rule = optional(string)
    })),
    # Name of ELB. Required for ELB Classic
    elb_name         = optional(string),
    # ARN of load balancer target group to associate with the service.
    # Required for ALB or NLB
    target_group_arn = optional(string),
    container_name   = string,
    container_port   = number
  }))
  default = []
}

variable "name" {
  description = "Name tag of instance, var.app_name-var.comp if empty"
  default     = ""
}

variable "network_configuration" {
  description = "Network configuration"
  type        = object({
    subnets = list(string),
    security_groups = list(string),
    assign_public_ip = bool
  })
  default     = null
}

variable "ordered_placement_strategy" {
  description = "Service level strategy rules taken into consideration during task placement"
  type        = list(object({
    type = string, # random, spread, or binpack
    field = optional(string)
  }))
  default     = []
}

variable "placement_constraints" {
  description = "Rules taken into consideration during task placement"
  type        = list(string)
  # Not supported for FARGATE
  default = []
}

variable "platform_version" {
  # https://docs.aws.amazon.com/AmazonECS/latest/developerguide/platform_versions.html
  description = "The platform version on which to run your service. Only applicable for launch_type set to FARGATE. Defaults to LATEST"
  type        = string
  default     = null
}

variable "propagate_tags" {
  description = "Whether to propagate tags from task definition or service to tasks: SERVICE or TASK_DEFINITION"
  type        = string
  default     = null
}

variable "scheduling_strategy" {
  description = "Scheduling strategy: REPLICA or DAEMON"
  # Default REPLICA. Fargate tasks do not support DAEMON."
  type    = string
  default = null
}

# https://www.terraform.io/docs/providers/aws/r/ecs_service.html#service_registries-1
variable "service_registries" {
  description = "Service discovery registries for the service"
  type = object({
    # ARN of AWS Service Registry
    registry_arn = string,
    # Port value used if service discovery service specified an SRV record
    port = optional(number),
    # Container name from task definition, not needed there is only one container
    container_name = optional(string),
    # Port from task definition
    container_port = optional(number)
  })
  default = null
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service#service_connect_configuration
variable "service_connect_configuration" {
  description = "ECS Service Connect configuration"
  type = object({
    enabled = optional(bool), # Default true
    log_configuration = optional(object({
      # Log driver to use. Valid values: awslogs, fluentd, gelf, journald, json-file, splunk, syslog
      log_driver = string,
      # Configuration options to send to the log driver. See https://docs.aws.amazon.com/AmazonECS/latest/developerguide/using_awslogs.html
      options = optional(map(string)),
      # The secrets to pass to the log configuration. See https://docs.aws.amazon.com/AmazonECS/latest/developerguide/using_awslogs.html
      secret_option = optional(list(object({
        # Name of secret
        name = string,
        # Secret to expose to the container, either full ARN of the
        # AWS Secrets Manager secret or full ARN of parameter in
        # AWS Systems Manager Parameter Store.
        value_from = string
      })))
    })),
    # The namespace name or ARN of aws_service_discovery_http_namespace
    namespace = optional(string),
    # Service Connect service objects
    service = optional(list(object({
      # List of client aliases for ths service. Maximum number of aliases is 1.
      client_alias = optional(list(object({
        # Name used in the applications of client tasks to connect to this service.
        dns_name = optional(string),
        # Listening port number for the Service Connect proxy. This port is
        # available inside of all of the tasks within the same namespace.
        port = number
      }))),
      # The name of the new AWS Cloud Map service that ECS creates.
      # Must be a valid DNS name, and must be unique in the namespace.
      discovery_name = optional(string),
      # Port number for the Service Connect proxy to listen on.
      ingress_port_override = optional(number),
      # Name of one of the portMappings from all the containers in the task definition.
      port_name = string,
      timeout = optional(object({
        # time in seconds a connection will stay active while idle. 0 to disable idleTimeout.
        idle_timeout_seconds = optional(number),
        # time in seconds for upstream to respond with a complete response per request.
        # 0 to disable perRequestTimeout. Can only be set when appProtocol isn't TCP.
        per_request_timeout_seconds = optional(number)
      })),
      tls = optional(object({
        issuer_cert_authority = optional(object({
          # ARN of the aws_acmpca_certificate_authority used to create the TLS Certificates
          aws_pca_authority_arn = string
        })),
        # KMS key used to encrypt the private key in Secrets Manager.
        kms_key = optional(string),
        # ARN of the IAM Role that's associated with the Service Connect TLS.
        role_arn = optional(string)
      }))
    }))),
  })
  default = null
}

variable "task_definition" {
  description = "Family and revision (family:revision) or full ARN of task definition to run in service"
  type        = string
  default     = ""
}

variable "wait_for_steady_state" {
  description = "Wait for service to reach steady state (like aws ecs wait services-stable) before continuing. Default false."
  type        = bool
  default     = null
}
