output "arn" {
  description = "ECS task definition arn"
  value       = aws_ecs_task_definition.this.arn
}

# output "container_definitions" {
#   description = "JSON for container definitions"
#   value       = aws_ecs_task_definition.this.container_definitions
# }

# output "container_definitions_jsondecode" {
#   description = "JSON for container definitions"
#   value       = jsondecode(aws_ecs_task_definition.this.container_definitions)
# }

output "container_name" {
  description = "Primary container name"
  value       = local.container_name
}

output "cpu" {
  description = "CPU spec"
  value       = aws_ecs_task_definition.this.cpu
}

output "family" {
  description = "ECS task definition family"
  value       = aws_ecs_task_definition.this.family
}

output "memory" {
  description = "Memory spec"
  value       = aws_ecs_task_definition.this.memory
}

output "port_mappings" {
  description = "Primary port mappings"
  value       = var.port_mappings
}

output "revision" {
  description = "ECS task definition revision"
  value       = aws_ecs_task_definition.this.revision
}

output "ssm_ps_arn_param_prefix" {
  description = "Prefix for SSM Parameter Store ARN and parameters"
  value       = local.ssm_ps_arn_param_prefix
}
