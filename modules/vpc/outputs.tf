output "vpc_ids" {
  description = "Map of resource key to VPC ID."
  value       = { for k, v in aws_vpc.this : k => v.id }
}

output "vpc_arns" {
  description = "Map of resource key to VPC ARN."
  value       = { for k, v in aws_vpc.this : k => v.arn }
}

output "vpc_cidr_blocks" {
  description = "Map of resource key to primary CIDR."
  value       = { for k, v in aws_vpc.this : k => v.cidr_block }
}

output "subnet_ids" {
  description = "Map of \"<vpc_key>:<subnet_key>\" to subnet ID."
  value       = { for k, v in aws_subnet.this : k => v.id }
}

output "subnet_arns" {
  description = "Map of \"<vpc_key>:<subnet_key>\" to subnet ARN."
  value       = { for k, v in aws_subnet.this : k => v.arn }
}

output "subnet_cidr_blocks" {
  description = "Map of \"<vpc_key>:<subnet_key>\" to subnet CIDR."
  value       = { for k, v in aws_subnet.this : k => v.cidr_block }
}

output "internet_gateway_ids" {
  description = "Map of resource key to IGW ID."
  value       = { for k, v in aws_internet_gateway.this : k => v.id }
}

output "route_table_ids" {
  description = "Map of resource key to route table ID (merges custom + default)."
  value = merge(
    { for k, v in aws_route_table.this : k => v.id },
    { for k, v in aws_default_route_table.this : k => v.id },
  )
}

output "nacl_ids" {
  description = "Map of resource key to NACL ID (merges custom + default)."
  value = merge(
    { for k, v in aws_network_acl.this : k => v.id },
    { for k, v in aws_default_network_acl.this : k => v.id },
  )
}

output "sg_ids" {
  description = "Map of resource key to security group ID."
  value       = { for k, v in aws_security_group.this : k => v.id }
}

output "sg_arns" {
  description = "Map of resource key to security group ARN."
  value       = { for k, v in aws_security_group.this : k => v.arn }
}

output "endpoint_ids" {
  description = "Map of resource key to VPC endpoint ID."
  value       = { for k, v in aws_vpc_endpoint.this : k => v.id }
}

output "flow_log_ids" {
  description = "Map of resource key to flow log ID."
  value       = { for k, v in aws_flow_log.this : k => v.id }
}

output "eip_allocation_ids" {
  description = "Map of resource key to EIP allocation ID."
  value       = { for k, v in aws_eip.this : k => v.id }
}

output "eip_public_ips" {
  description = "Map of resource key to EIP public IP."
  value       = { for k, v in aws_eip.this : k => v.public_ip }
}

output "tgw_attachment_ids" {
  description = "Map of resource key to TGW VPC attachment ID."
  value       = { for k, v in aws_ec2_transit_gateway_vpc_attachment.this : k => v.id }
}

# Shared-network outputs
output "cgw_ids" {
  description = "Map of resource key to customer gateway ID."
  value       = { for k, v in aws_customer_gateway.this : k => v.id }
}

output "tgw_ids" {
  description = "Map of resource key to Transit Gateway ID."
  value       = { for k, v in aws_ec2_transit_gateway.this : k => v.id }
}

output "tgw_attachment_accepter_ids" {
  description = "Map of resource key to TGW VPC attachment accepter ID."
  value       = { for k, v in aws_ec2_transit_gateway_vpc_attachment_accepter.this : k => v.id }
}

output "tgw_peering_attachment_ids" {
  description = "Map of resource key to TGW peering attachment ID."
  value       = { for k, v in aws_ec2_transit_gateway_peering_attachment.this : k => v.id }
}

output "tgw_peering_accepter_ids" {
  description = "Map of resource key to TGW peering attachment accepter ID."
  value       = { for k, v in aws_ec2_transit_gateway_peering_attachment_accepter.this : k => v.id }
}

output "tgw_route_table_ids" {
  description = "Map of resource key to TGW route table ID."
  value       = { for k, v in aws_ec2_transit_gateway_route_table.this : k => v.id }
}

output "vgw_ids" {
  description = "Map of resource key to virtual private gateway ID."
  value       = { for k, v in aws_vpn_gateway.this : k => v.id }
}

output "vpn_connection_ids" {
  description = "Map of resource key to VPN connection ID."
  value       = { for k, v in aws_vpn_connection.this : k => v.id }
}
