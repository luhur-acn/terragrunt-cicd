locals {
  # Modules are co-located inside this repo (no SSH to a separate repo needed).
  # Terragrunt resolves the source relative to the root of the repo.
  modules_base_url_local = "${get_repo_root()}//modules"

  # When running in CI/CD the modules are already checked out alongside the
  # environments, so we always use the local path.
  modules_base_url = local.modules_base_url_local

  # Automatically load account-level variables
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))

  # Automatically load region-level variables
  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  # Extract the variables we need for easy access
  account_name = local.account_vars.locals.account_name
  account_id   = local.account_vars.locals.account_id
  aws_region   = local.region_vars.locals.aws_region

  # Determine if we are running in CI/CD (GitHub Actions)
  is_cicd         = get_env("GITHUB_ACTIONS", "false") == "true"
  profile_setting = local.is_cicd ? "" : "profile = \"${get_env("AWS_PROFILE", local.account_vars.locals.aws_profile)}\""
}

# Generate an AWS provider block
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "aws" {
      region  = "${local.aws_region}"
      ${local.profile_setting}

      allowed_account_ids = ["${local.account_id}"]
    }
  EOF
}

# Configure Terragrunt to automatically store tfstate files in an S3 bucket.
# Uses S3 native state locking (use_lockfile = true) — no DynamoDB needed.
# Supports local backend fallback for fully offline runs.
remote_state {
  backend = get_env("USE_LOCAL_BACKEND", "false") == "true" ? "local" : "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = get_env("USE_LOCAL_BACKEND", "false") == "true" ? {
    path = "${get_parent_terragrunt_dir()}/.terraform-states/${path_relative_to_include()}/terraform.tfstate"
    } : merge(
    {
      bucket       = "terragrunt-state-${local.account_id}-${local.aws_region}"
      key          = "${path_relative_to_include()}/terraform.tfstate"
      region       = local.aws_region
      encrypt      = true
      use_lockfile = true
    },
    local.is_cicd ? {} : { profile = local.account_vars.locals.aws_profile }
  )
}

inputs = merge(
  local.account_vars.locals,
  local.region_vars.locals,
)
