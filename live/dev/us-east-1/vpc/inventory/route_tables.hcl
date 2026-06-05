# Route Tables Inventory Configuration
# Comment out all blocks to execute GitOps destroy

inputs = {
  "public-rt" = {
    type       = "custom"
    vpc_id     = "vpc-dev-v2"
    subnet_ids = ["vpc-dev-v2:public-1a", "vpc-dev-v2:public-1b"]
    routes = [
      {
        cidr_block = "0.0.0.0/0"
        gateway_id = "igw-dev-v2"
      }
    ]
    tags = { Name = "rt-dev-v2-public", Environment = "dev", ManagedBy = "Terragrunt" }
  }
  "private-rt" = {
    type       = "custom"
    vpc_id     = "vpc-dev-v2"
    subnet_ids = ["vpc-dev-v2:private-1a", "vpc-dev-v2:private-1b"]
    routes     = []
    tags       = { Name = "rt-dev-v2-private", Environment = "dev", ManagedBy = "Terragrunt" }
  }
}
