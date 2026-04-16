variable "conditions" {
  description = "List of conditions for the listener rule"
  type        = list(object({
    host_header = optional(object({
      regex_values  = optional(list(string))
      values        = optional(list(string))
    }))
    http_header = optional(object({
      http_header_name = string
      regex_values     = optional(list(string))
      values           = optional(list(string))
    }))
    http_request_method = optional(list(string))
    path_pattern = optional(object({
      regex_values     = optional(list(string))
      values           = optional(list(string))
    }))
    query_string  = optional(list(object({
      key   = string
      value = string
    })))
    source_ip     = optional(list(string))
  }))
}

variable "listener_arn" {
  description = "Listener to add rule to"
  type        = string
}

variable "priority" {
  description = "Priority of rule"
  type        = number
  default     = null
}

variable "stickiness_enabled" {
  description = "Enable sticky sessions for the target group"
  type        = bool
  default     = false
}

variable "stickiness_duration" {
  description = "Duration for stickiness in seconds"
  type        = number
  default     = null
}

variable "target_group_arns" {
  description = "Target Group(s) to forward traffic to"
  type        = list(string)
  default     = []
}

variable "target_groups" {
  description = "Target Group(s) to forward traffic to"
  type        = list(object({
    # ARN of the target group
    arn = string
    # 1-999
    weight = optional(number)
  }))
  default     = []
}
