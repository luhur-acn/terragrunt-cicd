# EC2 Instances Inventory Configuration
# Comment out all blocks to execute GitOps destroy

inputs = {
  "web-app-v2-01" = {
    ami                    = "ami-0c02fb55956c7d316"
    instance_type          = "t3.micro"
    subnet_id              = "vpc-dev-v2:private-1a"
    vpc_security_group_ids = ["web-sg"]
    availability_zone      = "us-east-1a"
    ebs_optimized          = true

    root_block_device = {
      volume_size           = 20
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }

    metadata_options = {
      http_endpoint               = "enabled"
      http_tokens                 = "required"
      http_put_response_hop_limit = 2
    }

    user_data = "web-app-v2-01" # Hostname passed to user-data logic

    ebs_volumes = {
      "data-vol" = {
        device_name = "/dev/xvdf"
        volume_key  = "data-vol-1a"
      }
    }

    tags = {
      Name        = "web-app-v2-01"
      Environment = "dev"
      ManagedBy   = "Terragrunt"
    }
  }

  "web-app-v2-02" = {
    ami                    = "ami-0c02fb55956c7d316"
    instance_type          = "t3.micro"
    subnet_id              = "vpc-dev-v2:private-1b"
    vpc_security_group_ids = ["web-sg"]
    availability_zone      = "us-east-1b"
    ebs_optimized          = true

    root_block_device = {
      volume_size           = 20
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }

    metadata_options = {
      http_endpoint               = "enabled"
      http_tokens                 = "required"
      http_put_response_hop_limit = 2
    }

    user_data = "web-app-v2-02" # Hostname passed to user-data logic

    ebs_volumes = {
      "data-vol" = {
        device_name = "/dev/xvdf"
        volume_key  = "data-vol-1b"
      }
    }

    tags = {
      Name        = "web-app-v2-02"
      Environment = "dev"
      ManagedBy   = "Terragrunt"
    }
  }
}
