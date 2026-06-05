# EBS Volumes Inventory Configuration
# Comment out all blocks to execute GitOps destroy

inputs = {
  "data-vol-1a" = {
    availability_zone = "us-east-1a"
    size              = 20
    type              = "gp3"
    encrypted         = true
    tags = {
      Name        = "ebs-dev-v2-data-1a"
      Environment = "dev"
      ManagedBy   = "Terragrunt"
    }
  }
  "data-vol-1b" = {
    availability_zone = "us-east-1b"
    size              = 20
    type              = "gp3"
    encrypted         = true
    tags = {
      Name        = "ebs-dev-v2-data-1b"
      Environment = "dev"
      ManagedBy   = "Terragrunt"
    }
  }
}
