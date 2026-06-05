# Network ACLs Inventory Configuration
# Comment out all blocks to execute GitOps destroy

inputs = {
  "dev-nacl" = {
    type       = "custom"
    vpc_id     = "vpc-dev-v2"
    subnet_ids = ["vpc-dev-v2:public-1a", "vpc-dev-v2:public-1b", "vpc-dev-v2:private-1a", "vpc-dev-v2:private-1b"]
    ingress = [
      {
        rule_no    = 100
        action     = "allow"
        protocol   = "tcp"
        from_port  = 80
        to_port    = 80
        cidr_block = "0.0.0.0/0"
      },
      {
        rule_no    = 110
        action     = "allow"
        protocol   = "tcp"
        from_port  = 443
        to_port    = 443
        cidr_block = "0.0.0.0/0"
      },
      {
        rule_no    = 120
        action     = "allow"
        protocol   = "tcp"
        from_port  = 22
        to_port    = 22
        cidr_block = "10.2.0.0/16"
      },
      {
        rule_no    = 130
        action     = "allow"
        protocol   = "tcp"
        from_port  = 1024
        to_port    = 65535
        cidr_block = "0.0.0.0/0"
      }
    ]
    egress = [
      {
        rule_no    = 100
        action     = "allow"
        protocol   = "-1"
        from_port  = 0
        to_port    = 0
        cidr_block = "0.0.0.0/0"
      }
    ]
    tags = { Name = "dev-nacl", Environment = "dev", ManagedBy = "Terragrunt" }
  }
}
