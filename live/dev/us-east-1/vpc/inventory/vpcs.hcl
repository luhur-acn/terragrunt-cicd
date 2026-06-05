# VPC & Subnets Inventory Configuration
# Comment out all blocks to execute GitOps destroy

inputs = {
  "vpc-dev-v2" = {
    cidr_block           = "10.2.0.0/16"
    enable_dns_support   = true
    enable_dns_hostnames = true

    subnets = {
      "public-1a" = {
        cidr_block              = "10.2.1.0/24"
        availability_zone       = "us-east-1a"
        map_public_ip_on_launch = true
        tags                    = { Name = "subnet-dev-v2-public-1a", Tier = "public", Environment = "dev" }
      }
      "public-1b" = {
        cidr_block              = "10.2.2.0/24"
        availability_zone       = "us-east-1b"
        map_public_ip_on_launch = true
        tags                    = { Name = "subnet-dev-v2-public-1b", Tier = "public", Environment = "dev" }
      }
      "private-1a" = {
        cidr_block        = "10.2.11.0/24"
        availability_zone = "us-east-1a"
        tags              = { Name = "subnet-dev-v2-private-1a", Tier = "private", Environment = "dev" }
      }
      "private-1b" = {
        cidr_block        = "10.2.12.0/24"
        availability_zone = "us-east-1b"
        tags              = { Name = "subnet-dev-v2-private-1b", Tier = "private", Environment = "dev" }
      }
    }

    tags = { Name = "vpc-dev-v2", Environment = "dev", ManagedBy = "Terragrunt" }
  }
}
