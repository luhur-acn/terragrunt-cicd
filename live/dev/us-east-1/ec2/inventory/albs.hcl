# Application Load Balancers Inventory Configuration
# Comment out all blocks to execute GitOps destroy | last-reviewed: 2026-06-03 v10

inputs = {
  "web-alb" = {
    name            = "web-dev-v2-alb"
    internal        = false
    ip_address_type = "ipv4"
    security_groups = ["alb-sg"]
    subnets = [
      "vpc-dev-v2:public-1a",
      "vpc-dev-v2:public-1b"
    ]

    listeners = {
      "http" = {
        port     = 80
        protocol = "HTTP"
        default_actions = [
          {
            type             = "forward"
            target_group_arn = "web-tg"
          }
        ]
      }
    }

    tags = {
      Name        = "web-dev-v2-alb"
      Environment = "dev"
      ManagedBy   = "Terragrunt"
    }
  }
}
