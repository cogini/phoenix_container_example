variable "ami_id" {
  description = "AMI id"
  type        = string
  default     = null
}

variable "ha_mode" {
  description = "High availability mode"
  type        = bool
  default     = false
}

variable "instance_type" {
  description = "Instance type"
  type        = string
  default     = "t4g.micro"
}

variable "name" {
  description = "Name"
  default     = ""
}

variable "route_tables_ids" {
  description = "Route tables to update. Only valid if update_route_tables is true"
  type        = map(string)
  default     = {}
}

variable "route_table_id" {
  description = "Route table to update. Only valid if update_route_tables is true"
  type        = string
  default     = ""
}

variable "ssh_key_name" {
  description = "Name of key pair"
  type        = string
  default     = null
}

variable "subnet_id" {
  description = "Subnet id"
  type        = string
}

variable "update_route_tables" {
  description = "Update route tables"
  type        = bool
  default     = false
}

variable "use_cloudwatch_agent" {
  description = "Use Cloudwatch agent"
  type        = bool
  default     = true
}

variable "use_spot_instances" {
  description = "Use spot instances"
  type        = bool
  default     = false
}

variable "vpc_id" {
  description = "vpc_id"
}
