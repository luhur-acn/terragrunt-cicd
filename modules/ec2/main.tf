resource "aws_ebs_volume" "this" {
  for_each = var.ebs_volumes

  availability_zone    = each.value.availability_zone
  size                 = each.value.size
  type                 = each.value.type
  encrypted            = each.value.encrypted
  kms_key_id           = each.value.kms_key_id
  iops                 = each.value.iops
  throughput           = each.value.throughput
  snapshot_id          = each.value.snapshot_id
  outpost_arn          = each.value.outpost_arn
  multi_attach_enabled = each.value.multi_attach_enabled

  tags = each.value.tags
}

resource "aws_instance" "this" {
  for_each = var.instances

  ami                    = each.value.ami
  instance_type          = each.value.instance_type
  subnet_id              = lookup(var.subnet_id_map, each.value.subnet_id, each.value.subnet_id)
  vpc_security_group_ids = [for g in each.value.vpc_security_group_ids : lookup(var.sg_id_map, g, g)]
  iam_instance_profile   = each.value.iam_instance_profile
  key_name               = each.value.key_name
  private_ip             = each.value.private_ip
  availability_zone      = each.value.availability_zone
  ebs_optimized          = each.value.ebs_optimized
  source_dest_check      = each.value.source_dest_check
  user_data              = each.value.user_data

  dynamic "metadata_options" {
    for_each = each.value.metadata_options != null ? [each.value.metadata_options] : []
    content {
      http_endpoint               = metadata_options.value.http_endpoint
      http_tokens                 = metadata_options.value.http_tokens
      http_put_response_hop_limit = metadata_options.value.http_put_response_hop_limit
    }
  }

  dynamic "root_block_device" {
    for_each = each.value.root_block_device != null ? [each.value.root_block_device] : []
    content {
      volume_size           = root_block_device.value.volume_size
      volume_type           = root_block_device.value.volume_type
      encrypted             = root_block_device.value.encrypted
      kms_key_id            = root_block_device.value.kms_key_id
      delete_on_termination = root_block_device.value.delete_on_termination
      iops                  = root_block_device.value.iops
      throughput            = root_block_device.value.throughput
      tags                  = root_block_device.value.tags
    }
  }

  tags = each.value.tags

  lifecycle {
    ignore_changes = [
      ami,
      tags["InstanceScheduler-LastAction"],
      tags["_GX_AMI_"],
      tags_all,
      user_data_replace_on_change,
    ]
  }
}

# Flatten instance.ebs_volumes into one aws_volume_attachment per (instance, device).
resource "aws_volume_attachment" "this" {
  for_each = merge([
    for instance_key, instance_val in var.instances : {
      for vol_key, vol_val in instance_val.ebs_volumes :
      "${instance_key}-${vol_key}" => {
        instance_key = instance_key
        device_name  = vol_val.device_name
        volume_id    = vol_val.volume_key != null ? aws_ebs_volume.this[vol_val.volume_key].id : vol_val.volume_id
      }
    }
  ]...)

  device_name = each.value.device_name
  volume_id   = each.value.volume_id
  instance_id = aws_instance.this[each.value.instance_key].id
}

# =============================================================================
# Application Load Balancers (inlined from modules/ec2-alb).
# Resource names use .alb suffix to avoid collision with NLBs (aws_lb.nlb below).
# =============================================================================

resource "aws_lb" "alb" {
  for_each = var.albs

  name               = each.value.name
  internal           = each.value.internal
  load_balancer_type = "application"
  security_groups    = [for g in each.value.security_groups : lookup(var.sg_id_map, g, g)]
  subnets            = [for s in each.value.subnets : lookup(var.subnet_id_map, s, s)]
  ip_address_type    = each.value.ip_address_type

  tags = each.value.tags
}

locals {
  # Resolve logical keys (from inventory) to created-resource IDs/ARNs so the
  # inventory can reference target groups and instances by name, not by ID.
  tg_arns      = { for k, v in aws_lb_target_group.this : k => v.arn }
  instance_ids = { for k, v in aws_instance.this : k => v.id }

  alb_listeners = merge([
    for lb_key, lb_val in var.albs : {
      for listener_key, listener_val in lb_val.listeners :
      "${lb_key}-${listener_key}" => merge(listener_val, { lb_key = lb_key })
    }
  ]...)

  alb_rules = merge([
    for l_key, l_val in local.alb_listeners : {
      for rule_key, rule_val in l_val.rules :
      "${l_key}-${rule_key}" => merge(rule_val, { listener_key = l_key })
    }
  ]...)
}

resource "aws_lb_listener" "alb_listener" {
  for_each = local.alb_listeners

  load_balancer_arn = aws_lb.alb[each.value.lb_key].arn
  port              = each.value.port
  protocol          = each.value.protocol
  ssl_policy        = each.value.ssl_policy
  certificate_arn   = each.value.certificate_arn

  dynamic "default_action" {
    for_each = each.value.default_actions
    content {
      type             = default_action.value.type
      target_group_arn = try(local.tg_arns[default_action.value.target_group_arn], default_action.value.target_group_arn)

      dynamic "redirect" {
        for_each = default_action.value.redirect != null ? [default_action.value.redirect] : []
        content {
          port        = redirect.value.port
          protocol    = redirect.value.protocol
          status_code = redirect.value.status_code
          host        = redirect.value.host
          path        = redirect.value.path
          query       = redirect.value.query
        }
      }

      dynamic "fixed_response" {
        for_each = default_action.value.fixed_response != null ? [default_action.value.fixed_response] : []
        content {
          content_type = fixed_response.value.content_type
          message_body = fixed_response.value.message_body
          status_code  = fixed_response.value.status_code
        }
      }

      dynamic "forward" {
        for_each = default_action.value.forward != null ? [default_action.value.forward] : []
        content {
          dynamic "target_group" {
            for_each = forward.value.target_groups
            content {
              arn    = try(local.tg_arns[target_group.value.target_group_arn], target_group.value.target_group_arn)
              weight = target_group.value.weight
            }
          }
          stickiness {
            enabled  = forward.value.stickiness.enabled
            duration = forward.value.stickiness.duration
          }
        }
      }
    }
  }
}

resource "aws_lb_listener_rule" "alb_rule" {
  for_each = local.alb_rules

  listener_arn = aws_lb_listener.alb_listener[each.value.listener_key].arn
  priority     = each.value.priority

  dynamic "action" {
    for_each = each.value.actions
    content {
      type             = action.value.type
      target_group_arn = try(local.tg_arns[action.value.target_group_arn], action.value.target_group_arn)

      dynamic "redirect" {
        for_each = action.value.redirect != null ? [action.value.redirect] : []
        content {
          port        = redirect.value.port
          protocol    = redirect.value.protocol
          status_code = redirect.value.status_code
          host        = redirect.value.host
          path        = redirect.value.path
          query       = redirect.value.query
        }
      }

      dynamic "fixed_response" {
        for_each = action.value.fixed_response != null ? [action.value.fixed_response] : []
        content {
          content_type = fixed_response.value.content_type
          message_body = fixed_response.value.message_body
          status_code  = fixed_response.value.status_code
        }
      }

      dynamic "forward" {
        for_each = action.value.forward != null ? [action.value.forward] : []
        content {
          dynamic "target_group" {
            for_each = forward.value.target_groups
            content {
              arn    = try(local.tg_arns[target_group.value.target_group_arn], target_group.value.target_group_arn)
              weight = target_group.value.weight
            }
          }
          stickiness {
            enabled  = forward.value.stickiness.enabled
            duration = forward.value.stickiness.duration
          }
        }
      }
    }
  }

  dynamic "condition" {
    for_each = each.value.conditions
    content {
      dynamic "host_header" {
        for_each = condition.value.host_header != null ? [condition.value.host_header] : []
        content {
          values = host_header.value
        }
      }
      dynamic "path_pattern" {
        for_each = condition.value.path_pattern != null ? [condition.value.path_pattern] : []
        content {
          values = path_pattern.value
        }
      }
      dynamic "http_header" {
        for_each = condition.value.http_header != null ? [condition.value.http_header] : []
        content {
          http_header_name = http_header.value.http_header_name
          values           = http_header.value.values
        }
      }
    }
  }
}

# =============================================================================
# Network Load Balancers (inlined from modules/ec2-nlb).
# =============================================================================

resource "aws_lb" "nlb" {
  for_each = var.nlbs

  name               = each.value.name
  internal           = each.value.internal
  load_balancer_type = "network"
  security_groups    = length(each.value.security_groups) > 0 ? [for g in each.value.security_groups : lookup(var.sg_id_map, g, g)] : null
  subnets            = length(each.value.subnet_mapping) > 0 ? null : [for s in each.value.subnets : lookup(var.subnet_id_map, s, s)]
  ip_address_type    = each.value.ip_address_type

  dynamic "subnet_mapping" {
    for_each = each.value.subnet_mapping
    content {
      subnet_id     = lookup(var.subnet_id_map, subnet_mapping.value.subnet_id, subnet_mapping.value.subnet_id)
      allocation_id = subnet_mapping.value.allocation_id
    }
  }

  tags = each.value.tags
}

locals {
  nlb_listeners = merge([
    for lb_key, lb_val in var.nlbs : {
      for listener_key, listener_val in lb_val.listeners :
      "${lb_key}-${listener_key}" => merge(listener_val, { lb_key = lb_key })
    }
  ]...)
}

resource "aws_lb_listener" "nlb_listener" {
  for_each = local.nlb_listeners

  load_balancer_arn = aws_lb.nlb[each.value.lb_key].arn
  port              = each.value.port
  protocol          = each.value.protocol
  ssl_policy        = each.value.ssl_policy
  certificate_arn   = each.value.certificate_arn

  dynamic "default_action" {
    for_each = each.value.default_actions
    content {
      type             = default_action.value.type
      target_group_arn = try(local.tg_arns[default_action.value.target_group_arn], default_action.value.target_group_arn)

      forward {
        dynamic "target_group" {
          for_each = default_action.value.forward.target_groups
          content {
            arn    = try(local.tg_arns[target_group.value.target_group_arn], target_group.value.target_group_arn)
            weight = target_group.value.weight
          }
        }
      }
    }
  }

  lifecycle {
    # NLB listeners do not support target-group stickiness on default_action.forward,
    # but the AWS API still echoes a default stickiness block on read.
    ignore_changes = [default_action[0].forward[0].stickiness]
  }
}

# =============================================================================
# Target Groups (inlined from modules/ec2-target-group).
# =============================================================================

resource "aws_lb_target_group" "this" {
  for_each = var.target_groups

  name        = coalesce(each.value.name, each.key)
  port        = each.value.port
  protocol    = each.value.protocol
  vpc_id      = lookup(var.vpc_id_map, each.value.vpc_id, each.value.vpc_id)
  target_type = each.value.target_type
  tags        = each.value.tags

  dynamic "health_check" {
    for_each = each.value.health_check != null ? [each.value.health_check] : []
    content {
      enabled             = health_check.value.enabled
      interval            = health_check.value.interval
      path                = health_check.value.path
      port                = health_check.value.port
      protocol            = health_check.value.protocol
      timeout             = health_check.value.timeout
      healthy_threshold   = health_check.value.healthy_threshold
      unhealthy_threshold = health_check.value.unhealthy_threshold
      matcher             = health_check.value.matcher
    }
  }

  lifecycle {
    # These attributes are provider defaults that AWS does not return on import;
    # they show as + drift even though their values match the AWS defaults.
    ignore_changes = [deregistration_delay, lambda_multi_value_headers_enabled, proxy_protocol_v2, slow_start]
  }
}

locals {
  tg_attachments = merge([
    for tg_key, tg_val in var.target_groups : {
      for attachment in tg_val.attachments :
      "${tg_key}-${attachment.target_id}${attachment.port != null ? "-${attachment.port}" : ""}" => merge(attachment, {
        tg_key = tg_key
      })
    }
  ]...)
}

resource "aws_lb_target_group_attachment" "this" {
  for_each = local.tg_attachments

  target_group_arn = aws_lb_target_group.this[each.value.tg_key].arn
  # Resolve a logical instance key (e.g. "web-app-v2-01") to its instance ID;
  # passes through real IDs / IPs for ip/lambda target types.
  target_id = try(local.instance_ids[each.value.target_id], each.value.target_id)
  port      = each.value.port
}
