output "target_arn" {
  value = aws_appautoscaling_target.this.arn
}

output "target_tags_all" {
  value = aws_appautoscaling_target.this.tags_all
}
