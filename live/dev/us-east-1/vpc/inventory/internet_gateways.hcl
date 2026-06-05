# Internet Gateways Inventory Configuration
# Comment out all blocks to execute GitOps destroy

inputs = {
  "igw-dev-v2" = {
    vpc_id = "vpc-dev-v2"
    tags   = { Name = "igw-dev-v2", Environment = "dev", ManagedBy = "Terragrunt" }
  }
}
