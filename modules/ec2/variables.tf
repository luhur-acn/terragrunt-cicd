# ─────────────────────────────────────────────────────────────────────────────
# Cross-module ID maps (from the vpc unit, via Terragrunt dependency).
# Let the inventory reference subnets / SGs / VPCs by logical key; resolved to
# real IDs internally via lookup(). Default {} so real IDs pass through.
# ─────────────────────────────────────────────────────────────────────────────
variable "subnet_id_map" {
  description = "Logical subnet key (\"<vpc>:<subnet>\") → real subnet ID."
  type        = map(string)
  default     = {}
}

variable "sg_id_map" {
  description = "Logical security group key → real security group ID."
  type        = map(string)
  default     = {}
}

variable "vpc_id_map" {
  description = "Logical VPC key → real VPC ID."
  type        = map(string)
  default     = {}
}

variable "instances" {
  description = "Map of EC2 instances. Volume attachments are nested inside each instance via ebs_volumes."
  type = map(object({
    ami                    = string
    instance_type          = string
    subnet_id              = string
    vpc_security_group_ids = list(string)
    iam_instance_profile   = optional(string)
    key_name               = optional(string)
    private_ip             = optional(string)
    availability_zone      = optional(string)
    ebs_optimized          = optional(bool, true)
    source_dest_check      = optional(bool, true)
    user_data              = optional(string)
    tags                   = optional(map(string), {})

    metadata_options = optional(object({
      http_endpoint               = optional(string, "enabled")
      http_tokens                 = optional(string, "required")
      http_put_response_hop_limit = optional(number, 2)
    }))

    root_block_device = optional(object({
      volume_size           = optional(number)
      volume_type           = optional(string)
      encrypted             = optional(bool)
      kms_key_id            = optional(string)
      delete_on_termination = optional(bool)
      iops                  = optional(number)
      throughput            = optional(number)
      tags                  = optional(map(string), {})
    }))

    ebs_volumes = optional(map(object({
      device_name           = string
      volume_id             = optional(string)
      volume_key            = optional(string)
      delete_on_termination = optional(bool, false)
    })), {})
  }))
  default = {}
}

variable "ebs_volumes" {
  description = "Map of EBS volumes. Co-located with EC2 in the same unit."
  type = map(object({
    availability_zone    = string
    size                 = number
    type                 = string
    encrypted            = bool
    kms_key_id           = optional(string)
    iops                 = optional(number)
    throughput           = optional(number)
    snapshot_id          = optional(string)
    outpost_arn          = optional(string)
    multi_attach_enabled = optional(bool)
    tags                 = optional(map(string), {})
  }))
  default = {}
}

variable "albs" {
  description = "Map of Application Load Balancers (aws_lb with load_balancer_type = application)."
  type = map(object({
    name            = string
    internal        = optional(bool, false)
    security_groups = list(string)
    subnets         = list(string)
    ip_address_type = optional(string, "ipv4")
    tags            = optional(map(string), {})

    listeners = map(object({
      port            = number
      protocol        = string
      ssl_policy      = optional(string)
      certificate_arn = optional(string)
      default_actions = list(object({
        type             = string
        target_group_arn = optional(string)
        redirect = optional(object({
          port        = optional(string)
          protocol    = optional(string)
          status_code = string
          host        = optional(string)
          path        = optional(string)
          query       = optional(string)
        }))
        fixed_response = optional(object({
          content_type = string
          message_body = optional(string)
          status_code  = string
        }))
        forward = optional(object({
          target_groups = list(object({
            target_group_arn = string
            weight           = optional(number)
          }))
          stickiness = optional(object({
            enabled  = bool
            duration = optional(number, 3600)
          }), { enabled = false })
        }))
      }))
      rules = optional(map(object({
        priority = number
        actions = list(object({
          type             = string
          target_group_arn = optional(string)
          redirect = optional(object({
            port        = optional(string)
            protocol    = optional(string)
            status_code = string
            host        = optional(string)
            path        = optional(string)
            query       = optional(string)
          }))
          fixed_response = optional(object({
            content_type = string
            message_body = optional(string)
            status_code  = string
          }))
          forward = optional(object({
            target_groups = list(object({
              target_group_arn = string
              weight           = optional(number)
            }))
            stickiness = optional(object({
              enabled  = bool
              duration = optional(number, 3600)
            }), { enabled = false })
          }))
        }))
        conditions = list(object({
          host_header  = optional(list(string))
          path_pattern = optional(list(string))
          http_header = optional(object({
            http_header_name = string
            values           = list(string)
          }))
        }))
      })), {})
    }))
  }))
  default = {}
}

variable "nlbs" {
  description = "Map of Network Load Balancers (aws_lb with load_balancer_type = network)."
  type = map(object({
    name            = string
    internal        = optional(bool, false)
    security_groups = optional(list(string), [])
    subnets         = optional(list(string), [])
    subnet_mapping = optional(list(object({
      subnet_id     = string
      allocation_id = optional(string)
    })), [])
    ip_address_type = optional(string, "ipv4")
    tags            = optional(map(string), {})

    listeners = map(object({
      port            = number
      protocol        = string
      ssl_policy      = optional(string)
      certificate_arn = optional(string)
      default_actions = list(object({
        type             = string
        target_group_arn = optional(string)
        forward = object({
          target_groups = list(object({
            target_group_arn = string
            weight           = optional(number, 0)
          }))
        })
      }))
    }))
  }))
  default = {}
}

variable "target_groups" {
  description = "Map of Target Groups."
  type = map(object({
    name        = optional(string)
    port        = number
    protocol    = string
    vpc_id      = string
    target_type = string

    health_check = optional(object({
      enabled             = optional(bool, true)
      interval            = optional(number, 30)
      path                = optional(string)
      port                = optional(string, "traffic-port")
      protocol            = optional(string)
      timeout             = optional(number, 5)
      healthy_threshold   = optional(number, 3)
      unhealthy_threshold = optional(number, 3)
      matcher             = optional(string)
    }), {})

    attachments = optional(list(object({
      target_id = string
      port      = optional(number)
    })), [])

    tags = optional(map(string), {})
  }))
  default = {}
}
