variable "comp" {
  description = "Name of the app component, app, worker, etc."
  default     = "app"
}

variable "name" {
  description = "Name of role"
  default     = ""
}

variable "lambda_function_arns" {
  description = "Lambda functions to allow access to"
  type        = list(string)
}
