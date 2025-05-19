# Security group for app running in private subnet

terraform {
  source = "${dirname(find_in_parent_folders())}/modules//sg"
}
dependency "vpc" {
  config_path = "../vpc"
}
dependencies {
  paths = [
    "../sg-lb-public",
  ]
}
include "root" {
  path = find_in_parent_folders()
}

inputs = {
  comp      = "app"
  app_ports = [80, 443, 4000, 4001, 4443]
  # app_sources = ["sg-lb-public", "sg-bastion", "sg-devops", "sg-prometheus"]
  app_sources = ["sg-lb-public"]

  # prometheus_ports = [9100, 9111]
  # prometheus_sources = ["sg-prometheus"]

  # ssh_sources = ["sg-bastion", "sg-devops"]
  # icmp_sources = ["sg-bastion", "sg-devops"]
  extra_tags = { location = "internal" }

  allow_self = true

  vpc_id = dependency.vpc.outputs.vpc_id
}
