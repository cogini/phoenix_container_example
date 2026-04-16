output "id" {
  description = "Listener rule id"
  value       = aws_lb_listener_rule.this.id
}

output "arn" {
  description = "Listener rule ARN"
  value       = aws_lb_listener_rule.this.arn
}
