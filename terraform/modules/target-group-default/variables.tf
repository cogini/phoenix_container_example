variable "comp" {
  description = "Name of the app component, app, worker, etc."
  default     = "default"
}

variable "deregistration_delay" {
  description = "Draining time in secodns"
  type        = number
  default     = null
}

variable "health_check" {
  description = "Mapping of tags for target group health_check"
  type        = object({
    enabled             = optional(bool)
    healthy_threshold   = optional(number)
    interval            = optional(number)
    matcher             = optional(string)
    path                = optional(string)
    port                = optional(number)
    protocol            = optional(string)
    timeout             = optional(number)
    unhealthy_threshold = optional(number)
  })
  default     = null
}

variable "name" {
  description = "The name of the target group"
  default     = ""
}

variable "port" {
  description = "Port on which targets receive traffic"
  type        = number
}

variable "protocol" {
  description = "Protocol to use for routing traffic to the targets"
  type        = string
  default     = null
}

variable "stickiness" {
  description = "Stickiness configuration"
  type        = object({
    cookie_duration = optional(number)
    cookie_name     = optional(string)
    enabled         = optional(bool)
    type            = string
  })
  default     = null
}

variable "target_type" {
  description = "The type of target, values are instance: instance, ip, lambda. Default instance"
  type        = string
  default     = null
}

variable "protocol_version" {
  description = "Protocol version"
  type        = string
  default     = null
}

variable "vpc_id" {
  description = "VPC id"
}
