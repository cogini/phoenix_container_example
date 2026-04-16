output "role_id" {
  description = "Role id"
  value       = aws_iam_role.this.id
}

output "role_arn" {
  description = "Role arn"
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "Role name"
  value       = aws_iam_role.this.name
}
