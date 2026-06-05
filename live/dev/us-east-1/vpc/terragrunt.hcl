# ─────────────────────────────────────────────────────────────────────────────
# vpc/terragrunt.hcl — Managed by Terragrunt
# Unit  : VPC networking (VPC, subnets, IGW, route tables, NACLs, security groups)
# Env   : dev | Region: us-east-1
# ─────────────────────────────────────────────────────────────────────────────

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "${include.root.locals.modules_base_url}/vpc"
}

locals {
  inv = "${get_terragrunt_dir()}/inventory"

  vpcs              = try(read_terragrunt_config("${local.inv}/vpcs.hcl").inputs, {})
  internet_gateways = try(read_terragrunt_config("${local.inv}/internet_gateways.hcl").inputs, {})
  route_tables      = try(read_terragrunt_config("${local.inv}/route_tables.hcl").inputs, {})
  security_groups   = try(read_terragrunt_config("${local.inv}/security_groups.hcl").inputs, {})
  network_acls      = try(read_terragrunt_config("${local.inv}/network_acls.hcl").inputs, {})
}

generate "inventory" {
  path              = "inventory.auto.tfvars.json"
  if_exists         = "overwrite"
  disable_signature = true
  contents = jsonencode({
    vpcs              = local.vpcs
    internet_gateways = local.internet_gateways
    route_tables      = local.route_tables
    security_groups   = local.security_groups
    network_acls      = local.network_acls
  })
}

