resource "aws_vpc" "this" {
  for_each = var.vpcs

  cidr_block                           = each.value.cidr_block
  instance_tenancy                     = each.value.instance_tenancy
  enable_dns_support                   = each.value.enable_dns_support
  enable_dns_hostnames                 = each.value.enable_dns_hostnames
  enable_network_address_usage_metrics = each.value.enable_network_address_usage_metrics
  assign_generated_ipv6_cidr_block     = each.value.assign_generated_ipv6_cidr_block
  ipv6_cidr_block                      = each.value.ipv6_cidr_block
  ipv6_ipam_pool_id                    = each.value.ipv6_ipam_pool_id
  ipv6_netmask_length                  = each.value.ipv6_netmask_length
  ipv4_ipam_pool_id                    = each.value.ipv4_ipam_pool_id
  ipv4_netmask_length                  = each.value.ipv4_netmask_length

  tags = each.value.tags
}

# All flattened locals are namespaced to avoid collisions across the inlined child modules.
locals {
  vpc_secondary_cidrs = merge([
    for k, v in var.vpcs : {
      for cidr in v.secondary_cidr_blocks : "${k}:${cidr}" => { vpc_key = k, cidr = cidr }
    }
  ]...)

  vpc_subnets = merge([
    for k, v in var.vpcs : {
      for sk, sv in v.subnets : "${k}:${sk}" => merge(sv, { vpc_key = k })
    }
  ]...)

  rt_associations = merge([
    for k, v in var.route_tables : {
      for s in v.subnet_ids : "${k}__${s}" => { rt_key = k, subnet_id = s, type = v.type }
    }
  ]...)

  tgw_routes = flatten([
    for rt_key, rt in var.tgw_route_tables : [
      for r in rt.routes : {
        key                           = "${rt_key}:${r.destination_cidr_block}"
        route_table_id                = aws_ec2_transit_gateway_route_table.this[rt_key].id
        destination_cidr_block        = r.destination_cidr_block
        transit_gateway_attachment_id = r.transit_gateway_attachment_id
        blackhole                     = r.blackhole
      }
    ]
  ])

  tgw_rt_associations = flatten([
    for rt_key, rt in var.tgw_route_tables : [
      for attach_id in rt.associations : {
        key                           = "${rt_key}:${attach_id}"
        route_table_id                = aws_ec2_transit_gateway_route_table.this[rt_key].id
        transit_gateway_attachment_id = attach_id
      }
    ]
  ])

  tgw_rt_propagations = flatten([
    for rt_key, rt in var.tgw_route_tables : [
      for attach_id in rt.propagations : {
        key                           = "${rt_key}:${attach_id}"
        route_table_id                = aws_ec2_transit_gateway_route_table.this[rt_key].id
        transit_gateway_attachment_id = attach_id
      }
    ]
  ])
}

resource "aws_subnet" "this" {
  for_each = local.vpc_subnets

  vpc_id                                         = aws_vpc.this[each.value.vpc_key].id
  cidr_block                                     = each.value.cidr_block
  availability_zone                              = each.value.availability_zone
  availability_zone_id                           = each.value.availability_zone_id
  ipv6_cidr_block                                = each.value.ipv6_cidr_block
  ipv6_native                                    = each.value.ipv6_native
  assign_ipv6_address_on_creation                = each.value.assign_ipv6_address_on_creation
  map_public_ip_on_launch                        = each.value.map_public_ip_on_launch
  map_customer_owned_ip_on_launch                = each.value.map_customer_owned_ip_on_launch
  customer_owned_ipv4_pool                       = each.value.customer_owned_ipv4_pool
  outpost_arn                                    = each.value.outpost_arn
  enable_dns64                                   = each.value.enable_dns64
  enable_lni_at_device_index                     = each.value.enable_lni_at_device_index
  enable_resource_name_dns_a_record_on_launch    = each.value.enable_resource_name_dns_a_record_on_launch
  enable_resource_name_dns_aaaa_record_on_launch = each.value.enable_resource_name_dns_aaaa_record_on_launch
  private_dns_hostname_type_on_launch            = each.value.private_dns_hostname_type_on_launch

  tags = each.value.tags
}

resource "aws_vpc_ipv4_cidr_block_association" "this" {
  for_each = local.vpc_secondary_cidrs

  vpc_id     = aws_vpc.this[each.value.vpc_key].id
  cidr_block = each.value.cidr
}

resource "aws_internet_gateway" "this" {
  for_each = var.internet_gateways

  # Resolve a logical VPC key (e.g. "vpc-dev-v2") to the created VPC ID;
  # fall back to the raw value if it's already a real ID.
  vpc_id = try(aws_vpc.this[each.value.vpc_id].id, each.value.vpc_id)
  tags   = each.value.tags
}

resource "aws_route_table" "this" {
  for_each = { for k, v in var.route_tables : k => v if v.type == "custom" }

  vpc_id           = try(aws_vpc.this[each.value.vpc_id].id, each.value.vpc_id)
  propagating_vgws = each.value.propagating_vgws

  dynamic "route" {
    for_each = each.value.routes
    content {
      cidr_block                 = route.value.cidr_block
      ipv6_cidr_block            = route.value.ipv6_cidr_block
      destination_prefix_list_id = route.value.destination_prefix_list_id
      # Resolve a logical IGW key (e.g. "igw-dev-v2") to its created ID.
      gateway_id                = try(aws_internet_gateway.this[route.value.gateway_id].id, route.value.gateway_id)
      transit_gateway_id        = route.value.transit_gateway_id
      nat_gateway_id            = route.value.nat_gateway_id
      vpc_endpoint_id           = route.value.vpc_endpoint_id
      vpc_peering_connection_id = route.value.vpc_peering_connection_id
      network_interface_id      = route.value.network_interface_id
      egress_only_gateway_id    = route.value.egress_only_gateway_id
      carrier_gateway_id        = route.value.carrier_gateway_id
      core_network_arn          = route.value.core_network_arn
      local_gateway_id          = route.value.local_gateway_id
    }
  }

  tags = each.value.tags

  lifecycle {
    # aws_route_table route SET uses all schema fields for hashing; new provider
    # attributes (odb_network_arn) can cause hash mismatches on import. Ignore
    # during the PoC import phase so existing live routes are not deleted.
    ignore_changes = [route]
  }
}

resource "aws_default_route_table" "this" {
  for_each = { for k, v in var.route_tables : k => v if v.type == "default" }

  default_route_table_id = each.value.default_route_table_id
  propagating_vgws       = each.value.propagating_vgws

  dynamic "route" {
    for_each = each.value.routes
    content {
      cidr_block                 = route.value.cidr_block
      ipv6_cidr_block            = route.value.ipv6_cidr_block
      destination_prefix_list_id = route.value.destination_prefix_list_id
      gateway_id                 = try(aws_internet_gateway.this[route.value.gateway_id].id, route.value.gateway_id)
      transit_gateway_id         = route.value.transit_gateway_id
      nat_gateway_id             = route.value.nat_gateway_id
      vpc_endpoint_id            = route.value.vpc_endpoint_id
      vpc_peering_connection_id  = route.value.vpc_peering_connection_id
      network_interface_id       = route.value.network_interface_id
      egress_only_gateway_id     = route.value.egress_only_gateway_id
      core_network_arn           = route.value.core_network_arn
    }
  }

  tags = each.value.tags

  lifecycle {
    ignore_changes = [route]
  }
}

resource "aws_route_table_association" "this" {
  for_each = local.rt_associations

  # Resolve logical "<vpc_key>:<subnet_key>" to the created subnet ID.
  subnet_id = try(aws_subnet.this[each.value.subnet_id].id, each.value.subnet_id)
  route_table_id = (
    each.value.type == "custom"
    ? aws_route_table.this[each.value.rt_key].id
    : aws_default_route_table.this[each.value.rt_key].id
  )
}

resource "aws_network_acl" "this" {
  for_each = { for k, v in var.network_acls : k => v if v.type == "custom" }

  vpc_id     = try(aws_vpc.this[each.value.vpc_id].id, each.value.vpc_id)
  subnet_ids = length(each.value.subnet_ids) > 0 ? [for s in each.value.subnet_ids : try(aws_subnet.this[s].id, s)] : null

  dynamic "ingress" {
    for_each = each.value.ingress
    content {
      rule_no         = ingress.value.rule_no
      action          = ingress.value.action
      protocol        = ingress.value.protocol
      from_port       = ingress.value.from_port
      to_port         = ingress.value.to_port
      cidr_block      = ingress.value.cidr_block
      ipv6_cidr_block = ingress.value.ipv6_cidr_block
      icmp_type       = ingress.value.icmp_type
      icmp_code       = ingress.value.icmp_code
    }
  }

  dynamic "egress" {
    for_each = each.value.egress
    content {
      rule_no         = egress.value.rule_no
      action          = egress.value.action
      protocol        = egress.value.protocol
      from_port       = egress.value.from_port
      to_port         = egress.value.to_port
      cidr_block      = egress.value.cidr_block
      ipv6_cidr_block = egress.value.ipv6_cidr_block
      icmp_type       = egress.value.icmp_type
      icmp_code       = egress.value.icmp_code
    }
  }

  tags = each.value.tags
}

resource "aws_default_network_acl" "this" {
  for_each = { for k, v in var.network_acls : k => v if v.type == "default" }

  default_network_acl_id = each.value.default_network_acl_id
  subnet_ids             = length(each.value.subnet_ids) > 0 ? [for s in each.value.subnet_ids : try(aws_subnet.this[s].id, s)] : null

  dynamic "ingress" {
    for_each = each.value.ingress
    content {
      rule_no         = ingress.value.rule_no
      action          = ingress.value.action
      protocol        = ingress.value.protocol
      from_port       = ingress.value.from_port
      to_port         = ingress.value.to_port
      cidr_block      = ingress.value.cidr_block
      ipv6_cidr_block = ingress.value.ipv6_cidr_block
      icmp_type       = ingress.value.icmp_type
      icmp_code       = ingress.value.icmp_code
    }
  }

  dynamic "egress" {
    for_each = each.value.egress
    content {
      rule_no         = egress.value.rule_no
      action          = egress.value.action
      protocol        = egress.value.protocol
      from_port       = egress.value.from_port
      to_port         = egress.value.to_port
      cidr_block      = egress.value.cidr_block
      ipv6_cidr_block = egress.value.ipv6_cidr_block
      icmp_type       = egress.value.icmp_type
      icmp_code       = egress.value.icmp_code
    }
  }

  tags = each.value.tags
}

resource "aws_security_group" "this" {
  for_each = var.security_groups

  name                   = each.value.name
  description            = each.value.description
  vpc_id                 = try(aws_vpc.this[each.value.vpc_id].id, each.value.vpc_id)
  revoke_rules_on_delete = each.value.revoke_rules_on_delete

  tags = each.value.tags
}

# Rules are standalone resources (no inline ingress/egress). An SG-to-SG rule
# referencing aws_security_group.this[...] from a SEPARATE resource is a normal
# cross-resource edge — unlike inline resolution, which makes the SG depend on
# itself and produces a "Cycle" error.
#
# Each inline-style rule is split: CIDR/ipv6/prefix/self sources collapse into
# one rule (cidr_blocks takes the whole list), and EACH referenced SG becomes
# its own rule. A rule is only emitted to the *_cidr set if it actually has a
# non-SG source, so we never create a rule with all sources null.
locals {
  sg_ingress_cidr = flatten([
    for sg_key, sg in var.security_groups : [
      for idx, rule in coalesce(sg.ingress, []) :
      merge(rule, { security_group_key = sg_key, rule_index = idx })
      if try(length(rule.cidr_blocks), 0) > 0
      || try(length(rule.ipv6_cidr_blocks), 0) > 0
      || try(length(rule.prefix_list_ids), 0) > 0
      || coalesce(rule.self, false)
    ]
  ])

  sg_ingress_sg = flatten([
    for sg_key, sg in var.security_groups : [
      for idx, rule in coalesce(sg.ingress, []) : [
        for src in coalesce(rule.security_groups, []) :
        merge(rule, { security_group_key = sg_key, rule_index = idx, source_sg = src })
      ]
    ]
  ])

  sg_egress_cidr = flatten([
    for sg_key, sg in var.security_groups : [
      for idx, rule in coalesce(sg.egress, []) :
      merge(rule, { security_group_key = sg_key, rule_index = idx })
      if try(length(rule.cidr_blocks), 0) > 0
      || try(length(rule.ipv6_cidr_blocks), 0) > 0
      || try(length(rule.prefix_list_ids), 0) > 0
      || coalesce(rule.self, false)
    ]
  ])

  sg_egress_sg = flatten([
    for sg_key, sg in var.security_groups : [
      for idx, rule in coalesce(sg.egress, []) : [
        for src in coalesce(rule.security_groups, []) :
        merge(rule, { security_group_key = sg_key, rule_index = idx, source_sg = src })
      ]
    ]
  ])
}

resource "aws_security_group_rule" "ingress_cidr" {
  for_each = {
    for rule in local.sg_ingress_cidr : "${rule.security_group_key}_in_cidr_${rule.rule_index}" => rule
  }

  security_group_id = aws_security_group.this[each.value.security_group_key].id
  type              = "ingress"
  description       = each.value.description
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  protocol          = each.value.protocol
  cidr_blocks       = each.value.cidr_blocks
  ipv6_cidr_blocks  = each.value.ipv6_cidr_blocks
  prefix_list_ids   = each.value.prefix_list_ids
  self              = try(each.value.self, null)
}

resource "aws_security_group_rule" "ingress_sg" {
  for_each = {
    for rule in local.sg_ingress_sg : "${rule.security_group_key}_in_sg_${rule.rule_index}_${rule.source_sg}" => rule
  }

  security_group_id        = aws_security_group.this[each.value.security_group_key].id
  type                     = "ingress"
  description              = each.value.description
  from_port                = each.value.from_port
  to_port                  = each.value.to_port
  protocol                 = each.value.protocol
  source_security_group_id = try(aws_security_group.this[each.value.source_sg].id, each.value.source_sg)
}

resource "aws_security_group_rule" "egress_cidr" {
  for_each = {
    for rule in local.sg_egress_cidr : "${rule.security_group_key}_eg_cidr_${rule.rule_index}" => rule
  }

  security_group_id = aws_security_group.this[each.value.security_group_key].id
  type              = "egress"
  description       = each.value.description
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  protocol          = each.value.protocol
  cidr_blocks       = each.value.cidr_blocks
  ipv6_cidr_blocks  = each.value.ipv6_cidr_blocks
  prefix_list_ids   = each.value.prefix_list_ids
  self              = try(each.value.self, null)
}

resource "aws_security_group_rule" "egress_sg" {
  for_each = {
    for rule in local.sg_egress_sg : "${rule.security_group_key}_eg_sg_${rule.rule_index}_${rule.source_sg}" => rule
  }

  security_group_id        = aws_security_group.this[each.value.security_group_key].id
  type                     = "egress"
  description              = each.value.description
  from_port                = each.value.from_port
  to_port                  = each.value.to_port
  protocol                 = each.value.protocol
  source_security_group_id = try(aws_security_group.this[each.value.source_sg].id, each.value.source_sg)
}

resource "aws_vpc_endpoint" "this" {
  for_each = var.endpoints

  vpc_id              = each.value.vpc_id
  service_name        = each.value.service_name
  vpc_endpoint_type   = each.value.vpc_endpoint_type
  auto_accept         = each.value.auto_accept
  policy              = each.value.policy
  private_dns_enabled = each.value.private_dns_enabled
  ip_address_type     = each.value.ip_address_type

  route_table_ids    = length(each.value.route_table_ids) > 0 ? each.value.route_table_ids : null
  subnet_ids         = length(each.value.subnet_ids) > 0 ? each.value.subnet_ids : null
  security_group_ids = length(each.value.security_group_ids) > 0 ? each.value.security_group_ids : null

  dynamic "dns_options" {
    for_each = each.value.dns_options != null ? [each.value.dns_options] : []
    content {
      dns_record_ip_type                             = dns_options.value.dns_record_ip_type
      private_dns_only_for_inbound_resolver_endpoint = dns_options.value.private_dns_only_for_inbound_resolver_endpoint
    }
  }

  tags = each.value.tags
}

resource "aws_flow_log" "this" {
  for_each = var.flow_logs

  vpc_id                        = each.value.vpc_id
  subnet_id                     = each.value.subnet_id
  transit_gateway_id            = each.value.transit_gateway_id
  transit_gateway_attachment_id = each.value.transit_gateway_attachment_id
  eni_id                        = each.value.eni_id

  log_destination_type       = each.value.log_destination_type
  log_destination            = each.value.log_destination
  iam_role_arn               = each.value.iam_role_arn
  deliver_cross_account_role = each.value.deliver_cross_account_role
  traffic_type               = each.value.traffic_type
  log_format                 = each.value.log_format
  max_aggregation_interval   = each.value.max_aggregation_interval

  dynamic "destination_options" {
    for_each = each.value.destination_options != null ? [each.value.destination_options] : []
    content {
      file_format                = destination_options.value.file_format
      hive_compatible_partitions = destination_options.value.hive_compatible_partitions
      per_hour_partition         = destination_options.value.per_hour_partition
    }
  }

  tags = each.value.tags
}

resource "aws_eip" "this" {
  for_each = var.eips

  domain                    = each.value.domain
  network_border_group      = each.value.network_border_group
  public_ipv4_pool          = each.value.public_ipv4_pool
  network_interface         = each.value.network_interface
  associate_with_private_ip = each.value.associate_with_private_ip
  instance                  = each.value.instance

  tags = each.value.tags

  lifecycle {
    # associate_with_private_ip is create-time only; AWS does not return it
    # on read, so it always shows drift on import.
    ignore_changes = [associate_with_private_ip]
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "this" {
  for_each = var.tgw_attachments

  subnet_ids             = each.value.subnet_ids
  transit_gateway_id     = each.value.transit_gateway_id
  vpc_id                 = each.value.vpc_id
  dns_support            = each.value.dns_support
  ipv6_support           = each.value.ipv6_support
  appliance_mode_support = each.value.appliance_mode_support

  transit_gateway_default_route_table_association = each.value.transit_gateway_default_route_table_association
  transit_gateway_default_route_table_propagation = each.value.transit_gateway_default_route_table_propagation

  tags = each.value.tags
}

# Shared-network (mst-shared-core) resources

resource "aws_customer_gateway" "this" {
  for_each = var.customer_gateways

  ip_address  = each.value.ip_address
  bgp_asn     = each.value.bgp_asn
  device_name = each.value.device_name
  type        = each.value.type
  tags        = each.value.tags
}

resource "aws_ec2_transit_gateway" "this" {
  for_each = var.transit_gateways

  description                     = coalesce(each.value.description, each.value.name)
  amazon_side_asn                 = each.value.amazon_side_asn
  auto_accept_shared_attachments  = each.value.auto_accept_shared_attachments
  default_route_table_association = each.value.default_route_table_association
  default_route_table_propagation = each.value.default_route_table_propagation

  tags = merge({ Name = each.value.name }, each.value.tags)
}

resource "aws_ec2_transit_gateway_vpc_attachment_accepter" "this" {
  for_each = var.tgw_attachment_accepters

  transit_gateway_attachment_id                   = each.value.transit_gateway_attachment_id
  transit_gateway_default_route_table_association = each.value.transit_gateway_default_route_table_association
  transit_gateway_default_route_table_propagation = each.value.transit_gateway_default_route_table_propagation

  tags = each.value.tags
}

resource "aws_ec2_transit_gateway_peering_attachment" "this" {
  for_each = var.tgw_peering_attachments

  transit_gateway_id      = each.value.transit_gateway_id
  peer_transit_gateway_id = each.value.peer_transit_gateway_id
  peer_account_id         = each.value.peer_account_id
  peer_region             = each.value.peer_region

  tags = each.value.tags
}

resource "aws_ec2_transit_gateway_peering_attachment_accepter" "this" {
  for_each = var.tgw_peering_accepters

  transit_gateway_attachment_id = each.value.transit_gateway_attachment_id

  tags = each.value.tags
}

resource "aws_ec2_transit_gateway_route_table" "this" {
  for_each = var.tgw_route_tables

  transit_gateway_id = each.value.transit_gateway_id

  tags = each.value.tags
}

resource "aws_ec2_transit_gateway_route" "this" {
  for_each = { for r in local.tgw_routes : r.key => r }

  destination_cidr_block         = each.value.destination_cidr_block
  transit_gateway_route_table_id = each.value.route_table_id
  transit_gateway_attachment_id  = each.value.transit_gateway_attachment_id
  blackhole                      = each.value.blackhole
}

resource "aws_ec2_transit_gateway_route_table_association" "this" {
  for_each = { for a in local.tgw_rt_associations : a.key => a }

  transit_gateway_attachment_id  = each.value.transit_gateway_attachment_id
  transit_gateway_route_table_id = each.value.route_table_id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "this" {
  for_each = { for p in local.tgw_rt_propagations : p.key => p }

  transit_gateway_attachment_id  = each.value.transit_gateway_attachment_id
  transit_gateway_route_table_id = each.value.route_table_id
}

resource "aws_vpn_gateway" "this" {
  for_each = var.vpn_gateways

  amazon_side_asn = each.value.amazon_side_asn
  vpc_id          = each.value.vpc_id
  tags            = each.value.tags
}

resource "aws_vpn_connection" "this" {
  for_each = var.vpn_connections

  customer_gateway_id = each.value.customer_gateway_id
  transit_gateway_id  = each.value.transit_gateway_id
  vpn_gateway_id      = each.value.vpn_gateway_id
  type                = each.value.type
  static_routes_only  = each.value.static_routes_only
  tags                = each.value.tags

  tunnel1_inside_cidr   = each.value.tunnel1_inside_cidr
  tunnel2_inside_cidr   = each.value.tunnel2_inside_cidr
  tunnel1_preshared_key = try(var.vpn_sensitive_inputs[each.key].tunnel1_preshared_key, null) == "" ? null : try(var.vpn_sensitive_inputs[each.key].tunnel1_preshared_key, null)
  tunnel2_preshared_key = try(var.vpn_sensitive_inputs[each.key].tunnel2_preshared_key, null) == "" ? null : try(var.vpn_sensitive_inputs[each.key].tunnel2_preshared_key, null)

  tunnel1_ike_versions                 = each.value.tunnel1_ike_versions
  tunnel1_phase1_dh_group_numbers      = each.value.tunnel1_phase1_dh_group_numbers
  tunnel1_phase1_encryption_algorithms = each.value.tunnel1_phase1_encryption_algorithms
  tunnel1_phase1_integrity_algorithms  = each.value.tunnel1_phase1_integrity_algorithms
  tunnel1_phase1_lifetime_seconds      = each.value.tunnel1_phase1_lifetime_seconds
  tunnel1_phase2_dh_group_numbers      = each.value.tunnel1_phase2_dh_group_numbers
  tunnel1_phase2_encryption_algorithms = each.value.tunnel1_phase2_encryption_algorithms
  tunnel1_phase2_integrity_algorithms  = each.value.tunnel1_phase2_integrity_algorithms
  tunnel1_phase2_lifetime_seconds      = each.value.tunnel1_phase2_lifetime_seconds
  tunnel1_startup_action               = each.value.tunnel1_startup_action
  tunnel1_dpd_timeout_action           = each.value.tunnel1_dpd_timeout_action
  tunnel1_dpd_timeout_seconds          = each.value.tunnel1_dpd_timeout_seconds

  tunnel2_ike_versions                 = each.value.tunnel2_ike_versions
  tunnel2_phase1_dh_group_numbers      = each.value.tunnel2_phase1_dh_group_numbers
  tunnel2_phase1_encryption_algorithms = each.value.tunnel2_phase1_encryption_algorithms
  tunnel2_phase1_integrity_algorithms  = each.value.tunnel2_phase1_integrity_algorithms
  tunnel2_phase1_lifetime_seconds      = each.value.tunnel2_phase1_lifetime_seconds
  tunnel2_phase2_dh_group_numbers      = each.value.tunnel2_phase2_dh_group_numbers
  tunnel2_phase2_encryption_algorithms = each.value.tunnel2_phase2_encryption_algorithms
  tunnel2_phase2_integrity_algorithms  = each.value.tunnel2_phase2_integrity_algorithms
  tunnel2_phase2_lifetime_seconds      = each.value.tunnel2_phase2_lifetime_seconds
  tunnel2_startup_action               = each.value.tunnel2_startup_action
  tunnel2_dpd_timeout_action           = each.value.tunnel2_dpd_timeout_action
  tunnel2_dpd_timeout_seconds          = each.value.tunnel2_dpd_timeout_seconds

  lifecycle {
    ignore_changes = [
      tunnel1_ike_versions, tunnel1_phase1_dh_group_numbers,
      tunnel1_phase1_encryption_algorithms, tunnel1_phase1_integrity_algorithms,
      tunnel1_phase2_dh_group_numbers, tunnel1_phase2_encryption_algorithms,
      tunnel1_phase2_integrity_algorithms,
      tunnel2_ike_versions, tunnel2_phase1_dh_group_numbers,
      tunnel2_phase1_encryption_algorithms, tunnel2_phase1_integrity_algorithms,
      tunnel2_phase2_dh_group_numbers, tunnel2_phase2_encryption_algorithms,
      tunnel2_phase2_integrity_algorithms,
    ]
  }
}
