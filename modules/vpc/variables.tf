variable "vpcs" {
  description = "Map of VPC configurations including nested subnets and secondary CIDR blocks."
  type = map(object({
    cidr_block                           = string
    instance_tenancy                     = optional(string, "default")
    enable_dns_support                   = optional(bool, true)
    enable_dns_hostnames                 = optional(bool)
    enable_network_address_usage_metrics = optional(bool)
    assign_generated_ipv6_cidr_block     = optional(bool)
    ipv6_cidr_block                      = optional(string)
    ipv6_ipam_pool_id                    = optional(string)
    ipv6_netmask_length                  = optional(number)
    ipv4_ipam_pool_id                    = optional(string)
    ipv4_netmask_length                  = optional(number)
    secondary_cidr_blocks                = optional(list(string), [])
    tags                                 = optional(map(string), {})

    subnets = optional(map(object({
      cidr_block                                     = string
      availability_zone                              = optional(string)
      availability_zone_id                           = optional(string)
      ipv6_cidr_block                                = optional(string)
      ipv6_native                                    = optional(bool)
      assign_ipv6_address_on_creation                = optional(bool)
      map_public_ip_on_launch                        = optional(bool)
      map_customer_owned_ip_on_launch                = optional(bool)
      customer_owned_ipv4_pool                       = optional(string)
      outpost_arn                                    = optional(string)
      enable_dns64                                   = optional(bool)
      enable_lni_at_device_index                     = optional(number)
      enable_resource_name_dns_a_record_on_launch    = optional(bool)
      enable_resource_name_dns_aaaa_record_on_launch = optional(bool)
      private_dns_hostname_type_on_launch            = optional(string)
      tags                                           = optional(map(string), {})
    })), {})
  }))
  default = {}
}

variable "internet_gateways" {
  description = "Map of Internet Gateway configurations."
  type = map(object({
    vpc_id = optional(string)
    tags   = optional(map(string), {})
  }))
  default = {}
}

variable "route_tables" {
  description = "Map of VPC route tables. Set type = \"default\" to manage an existing default route table."
  type = map(object({
    type                   = optional(string, "custom")
    vpc_id                 = optional(string)
    default_route_table_id = optional(string)
    subnet_ids             = optional(list(string), [])
    propagating_vgws       = optional(list(string), [])
    tags                   = optional(map(string), {})

    routes = optional(list(object({
      cidr_block                 = optional(string)
      ipv6_cidr_block            = optional(string)
      destination_prefix_list_id = optional(string)
      gateway_id                 = optional(string)
      transit_gateway_id         = optional(string)
      nat_gateway_id             = optional(string)
      vpc_endpoint_id            = optional(string)
      vpc_peering_connection_id  = optional(string)
      network_interface_id       = optional(string)
      egress_only_gateway_id     = optional(string)
      carrier_gateway_id         = optional(string)
      core_network_arn           = optional(string)
      local_gateway_id           = optional(string)
      odb_network_arn            = optional(string)
    })), [])
  }))
  default = {}
}

variable "network_acls" {
  description = "Map of NACL configurations. Set type = \"default\" to manage an existing default NACL."
  type = map(object({
    type                   = optional(string, "custom")
    vpc_id                 = optional(string)
    default_network_acl_id = optional(string)
    subnet_ids             = optional(list(string), [])
    tags                   = optional(map(string), {})

    ingress = optional(list(object({
      rule_no         = number
      action          = string
      protocol        = string
      from_port       = optional(number, 0)
      to_port         = optional(number, 0)
      cidr_block      = optional(string)
      ipv6_cidr_block = optional(string)
      icmp_type       = optional(number)
      icmp_code       = optional(number)
    })), [])

    egress = optional(list(object({
      rule_no         = number
      action          = string
      protocol        = string
      from_port       = optional(number, 0)
      to_port         = optional(number, 0)
      cidr_block      = optional(string)
      ipv6_cidr_block = optional(string)
      icmp_type       = optional(number)
      icmp_code       = optional(number)
    })), [])
  }))
  default = {}
}

variable "security_groups" {
  description = "Map of security group configurations with inline ingress/egress rules."
  type = map(object({
    name                   = string
    description            = string
    vpc_id                 = string
    revoke_rules_on_delete = optional(bool)
    tags                   = optional(map(string), {})

    ingress = optional(list(object({
      description      = optional(string)
      from_port        = number
      to_port          = number
      protocol         = string
      cidr_blocks      = optional(list(string))
      ipv6_cidr_blocks = optional(list(string))
      prefix_list_ids  = optional(list(string))
      security_groups  = optional(list(string))
      self             = optional(bool)
    })), [])

    egress = optional(list(object({
      description      = optional(string)
      from_port        = number
      to_port          = number
      protocol         = string
      cidr_blocks      = optional(list(string))
      ipv6_cidr_blocks = optional(list(string))
      prefix_list_ids  = optional(list(string))
      security_groups  = optional(list(string))
      self             = optional(bool)
    })), [])
  }))
  default = {}
}

variable "endpoints" {
  description = "Map of VPC endpoint configurations."
  type = map(object({
    vpc_id              = string
    service_name        = string
    vpc_endpoint_type   = optional(string, "Gateway")
    auto_accept         = optional(bool)
    policy              = optional(string)
    private_dns_enabled = optional(bool)
    ip_address_type     = optional(string)
    route_table_ids     = optional(list(string), [])
    subnet_ids          = optional(list(string), [])
    security_group_ids  = optional(list(string), [])

    dns_options = optional(object({
      dns_record_ip_type                             = optional(string)
      private_dns_only_for_inbound_resolver_endpoint = optional(bool)
    }))

    tags = optional(map(string), {})
  }))
  default = {}
}

variable "flow_logs" {
  description = "Map of aws_flow_log configurations."
  type = map(object({
    vpc_id                        = optional(string)
    subnet_id                     = optional(string)
    transit_gateway_id            = optional(string)
    transit_gateway_attachment_id = optional(string)
    eni_id                        = optional(string)
    log_destination_type          = optional(string, "cloud-watch-logs")
    log_destination               = optional(string)
    iam_role_arn                  = optional(string)
    deliver_cross_account_role    = optional(string)
    traffic_type                  = optional(string, "ALL")
    log_format                    = optional(string)
    max_aggregation_interval      = optional(number)

    destination_options = optional(object({
      file_format                = optional(string)
      hive_compatible_partitions = optional(bool)
      per_hour_partition         = optional(bool)
    }))

    tags = optional(map(string), {})
  }))
  default = {}
}

variable "eips" {
  description = "Map of Elastic IP configurations."
  type = map(object({
    domain                    = optional(string, "vpc")
    network_border_group      = optional(string)
    public_ipv4_pool          = optional(string)
    network_interface         = optional(string)
    associate_with_private_ip = optional(string)
    instance                  = optional(string)
    tags                      = optional(map(string), {})
  }))
  default = {}
}

variable "tgw_attachments" {
  description = "Map of Transit Gateway VPC attachments."
  type = map(object({
    name                                            = string
    transit_gateway_id                              = string
    vpc_id                                          = string
    subnet_ids                                      = list(string)
    dns_support                                     = optional(string, "enable")
    ipv6_support                                    = optional(string, "disable")
    appliance_mode_support                          = optional(string, "disable")
    transit_gateway_default_route_table_association = optional(bool, true)
    transit_gateway_default_route_table_propagation = optional(bool, true)
    tags                                            = optional(map(string), {})
  }))
  default = {}
}

# Shared-network resources (mst-shared-core)
variable "customer_gateways" {
  description = "Map of customer gateways."
  type = map(object({
    ip_address  = string
    bgp_asn     = string
    device_name = optional(string, null)
    type        = optional(string, "ipsec.1")
    tags        = optional(map(string), {})
  }))
  default = {}
}

variable "transit_gateways" {
  description = "Map of Transit Gateways."
  type = map(object({
    name                            = string
    amazon_side_asn                 = optional(number, 64512)
    auto_accept_shared_attachments  = optional(string, "enable")
    default_route_table_association = optional(string, "enable")
    default_route_table_propagation = optional(string, "enable")
    tags                            = optional(map(string), {})
    description                     = optional(string)
  }))
  default = {}
}

variable "tgw_attachment_accepters" {
  description = "Map of Transit Gateway VPC attachment accepters (cross-account)."
  type = map(object({
    transit_gateway_attachment_id                   = string
    transit_gateway_default_route_table_association = optional(bool, true)
    transit_gateway_default_route_table_propagation = optional(bool, true)
    tags                                            = optional(map(string), {})
  }))
  default = {}
}

variable "tgw_peering_attachments" {
  description = "Map of Transit Gateway peering attachments (requester side)."
  type = map(object({
    transit_gateway_id      = string
    peer_transit_gateway_id = string
    peer_account_id         = string
    peer_region             = string
    tags                    = optional(map(string), {})
  }))
  default = {}
}

variable "tgw_peering_accepters" {
  description = "Map of Transit Gateway peering attachment accepters."
  type = map(object({
    transit_gateway_attachment_id = string
    tags                          = optional(map(string), {})
  }))
  default = {}
}

variable "tgw_route_tables" {
  description = "Map of TGW Route Tables with associations, propagations, and static routes."
  type = map(object({
    transit_gateway_id = string
    tags               = optional(map(string), {})
    routes = optional(list(object({
      destination_cidr_block        = string
      transit_gateway_attachment_id = optional(string)
      blackhole                     = optional(bool, false)
    })), [])
    associations = optional(list(string), [])
    propagations = optional(list(string), [])
  }))
  default = {}
}

variable "vpn_gateways" {
  description = "Map of virtual private gateways."
  type = map(object({
    amazon_side_asn = optional(number, 64512)
    vpc_id          = optional(string)
    tags            = optional(map(string), {})
  }))
  default = {}
}

variable "vpn_connections" {
  description = "Map of VPN connections. Preshared keys live in var.vpn_sensitive_inputs."
  type = map(object({
    customer_gateway_id = string
    transit_gateway_id  = optional(string)
    vpn_gateway_id      = optional(string)
    static_routes_only  = optional(bool, false)
    type                = optional(string, "ipsec.1")
    tags                = optional(map(string), {})

    tunnel1_inside_cidr = optional(string)
    tunnel2_inside_cidr = optional(string)

    tunnel1_ike_versions                 = optional(list(string))
    tunnel1_phase1_dh_group_numbers      = optional(list(number))
    tunnel1_phase1_encryption_algorithms = optional(list(string))
    tunnel1_phase1_integrity_algorithms  = optional(list(string))
    tunnel1_phase1_lifetime_seconds      = optional(number)
    tunnel1_phase2_dh_group_numbers      = optional(list(number))
    tunnel1_phase2_encryption_algorithms = optional(list(string))
    tunnel1_phase2_integrity_algorithms  = optional(list(string))
    tunnel1_phase2_lifetime_seconds      = optional(number)
    tunnel1_startup_action               = optional(string)
    tunnel1_dpd_timeout_action           = optional(string)
    tunnel1_dpd_timeout_seconds          = optional(number)

    tunnel2_ike_versions                 = optional(list(string))
    tunnel2_phase1_dh_group_numbers      = optional(list(number))
    tunnel2_phase1_encryption_algorithms = optional(list(string))
    tunnel2_phase1_integrity_algorithms  = optional(list(string))
    tunnel2_phase1_lifetime_seconds      = optional(number)
    tunnel2_phase2_dh_group_numbers      = optional(list(number))
    tunnel2_phase2_encryption_algorithms = optional(list(string))
    tunnel2_phase2_integrity_algorithms  = optional(list(string))
    tunnel2_phase2_lifetime_seconds      = optional(number)
    tunnel2_startup_action               = optional(string)
    tunnel2_dpd_timeout_action           = optional(string)
    tunnel2_dpd_timeout_seconds          = optional(number)
  }))
  default = {}
}

variable "vpn_sensitive_inputs" {
  description = "Per-resource sensitive attributes for VPN connections (preshared keys). Keys must match keys in var.vpn_connections."
  sensitive   = true
  type = map(object({
    tunnel1_preshared_key = optional(string)
    tunnel2_preshared_key = optional(string)
  }))
  default = {}
}
