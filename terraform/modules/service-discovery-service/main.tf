# Create Service Discovery service
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/service_discovery_service
#
# Example config:
# terraform {
#   source = "${dirname(find_in_parent_folders())}/modules//service-discovery-service"
# }
# include "root" {
#   path = find_in_parent_folders()
# }
# dependency "namespace" {
#   config_path = "../service-discovery-namespace"
# }
#
# inputs = {
#   comp = "app"
#   namespace_id = dependency.namespace.outputs.id
#   routing_policy = "MULTIVALUE"
# }

locals {
  name = var.name == "" ? "${var.app_name}-${var.comp}" : var.name
}

resource "aws_service_discovery_service" "this" {
  name = local.name

  dns_config {
    namespace_id = var.namespace_id

    dns_records {
      ttl  = var.dns_ttl
      type = "A"
    }

    routing_policy = var.routing_policy
  }

  dynamic "health_check_custom_config" {
    for_each = var.health_check_failure_threshold == null ? [] : tolist([1])
    content {
      failure_threshold = var.health_check_failure_threshold
    }
  }
}
