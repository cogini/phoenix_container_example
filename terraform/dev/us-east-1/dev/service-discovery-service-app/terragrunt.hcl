# Create Service Discovery Service

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//service-discovery-service"
}
include "root" {
  path = find_in_parent_folders("root.hcl")
}
dependency "namespace" {
  config_path = "../service-discovery-namespace"
}

inputs = {
  comp           = "app"
  namespace_id   = dependency.namespace.outputs.id
  routing_policy = "MULTIVALUE"
}
