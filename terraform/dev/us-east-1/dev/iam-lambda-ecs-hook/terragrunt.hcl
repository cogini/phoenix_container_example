# Create service role so ECS can call lambda lifecycle hook

terraform {
  source = "${dirname(find_in_parent_folders())}/../modules//iam-lambda-ecs-hook"
}
include "root" {
  path = find_in_parent_folders()
}
dependency "lambda" {
  config_path = "../lambda-ecs-hook-ellie"
}

inputs = {
  comp = "ellie"

  lambda_function_arns = [
    dependency.lambda.outputs.lambda_function_arn
  ]
}
