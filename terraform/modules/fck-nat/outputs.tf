output "ami_id" {
  description = "ID of the AMI for the NAT instance"
  value       = module.fck-nat.ami_id
}

output "auto_scaling_group_arn" {
  description = "ARN of Auto Scaling Group for NAT instance"
  value       = try(module.fck-nat.auto_scaling_group_arn, null)
}

output "instance_arn" {
  description = "ARN of instance when running in non-HA mode"
  value       = try(module.fck-nat.instance_arn, null)
}

output "instance_public_ip" {
  description = "Public IP address of instance if running in non-HA mode"
  value       = module.fck-nat.instance_public_ip
}

output "instance_type" {
  description = "Instance type of the NAT instance"
  value       = module.fck-nat.instance_type
}

output "eni_id" {
  description = "ID of the ENI for the NAT instance"
  value       = module.fck-nat.eni_id
}
