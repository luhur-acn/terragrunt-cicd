# Security Groups Inventory Configuration
# Comment out all blocks to execute GitOps destroy

inputs = {
  "alb-sg" = {
    name        = "alb-dev-v2-sg"
    description = "ALB Security Group - HTTP inbound from internet"
    vpc_id      = "vpc-dev-v2"
    ingress = [
      {
        description = "Allow HTTP from internet"
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
      }
    ]
    egress = [
      {
        description = "Allow all outbound"
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
      }
    ]
    tags = { Name = "alb-dev-v2-sg", Environment = "dev", ManagedBy = "Terragrunt" }
  }
  "web-sg" = {
    name        = "web-dev-v2-sg"
    description = "EC2 web security group - HTTP from ALB, SSH from VPC"
    vpc_id      = "vpc-dev-v2"
    ingress = [
      {
        description     = "Allow HTTP from ALB"
        from_port       = 80
        to_port         = 80
        protocol        = "tcp"
        security_groups = ["alb-sg"]
      },
      {
        description = "Allow SSH from VPC CIDR"
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["10.2.0.0/16"]
      }
    ]
    egress = [
      {
        description = "Allow all outbound"
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
      }
    ]
    tags = { Name = "web-dev-v2-sg", Environment = "dev", ManagedBy = "Terragrunt" }
  }
}
