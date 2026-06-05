# ─────────────────────────────────────────────────────────────────────────────
# ec2/terragrunt.hcl — Managed by Terragrunt
# Unit  : Compute (EC2 instances, EBS volumes, target groups, ALBs/NLBs)
# Env   : dev | Region: us-east-1
# ─────────────────────────────────────────────────────────────────────────────

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "${include.root.locals.modules_base_url}/ec2"
}

dependency "vpc" {
  config_path = "../vpc"

  # Allows plan/validate before the vpc unit is applied. Missing keys fall back
  # to the logical key (module-side lookup default), so a pre-apply plan renders.
  mock_outputs = {
    vpc_ids    = {}
    subnet_ids = {}
    sg_ids     = {}
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "show"]
}

locals {
  inv = "${get_terragrunt_dir()}/inventory"

  instances     = try(read_terragrunt_config("${local.inv}/instances.hcl").inputs, {})
  ebs_volumes   = try(read_terragrunt_config("${local.inv}/ebs_volumes.hcl").inputs, {})
  target_groups = try(read_terragrunt_config("${local.inv}/target_groups.hcl").inputs, {})
  albs          = try(read_terragrunt_config("${local.inv}/albs.hcl").inputs, {})
}

generate "inventory" {
  path              = "inventory.auto.tfvars.json"
  if_exists         = "overwrite"
  disable_signature = true
  contents = jsonencode({
    instances     = local.instances
    ebs_volumes   = local.ebs_volumes
    target_groups = local.target_groups
    albs          = local.albs
    nlbs          = {}
  })
}
inputs = {
  subnet_id_map = dependency.vpc.outputs.subnet_ids
  sg_id_map     = dependency.vpc.outputs.sg_ids
  vpc_id_map    = dependency.vpc.outputs.vpc_ids
}
