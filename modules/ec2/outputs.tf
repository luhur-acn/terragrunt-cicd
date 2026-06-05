output "instance_ids" {
  description = "Map of resource key to EC2 instance ID."
  value       = { for k, v in aws_instance.this : k => v.id }
}

output "instance_arns" {
  description = "Map of resource key to EC2 instance ARN."
  value       = { for k, v in aws_instance.this : k => v.arn }
}

output "private_ips" {
  description = "Map of resource key to instance primary private IP."
  value       = { for k, v in aws_instance.this : k => v.private_ip }
}

output "availability_zones" {
  description = "Map of resource key to instance AZ."
  value       = { for k, v in aws_instance.this : k => v.availability_zone }
}

output "ebs_volume_ids" {
  description = "Map of resource key to EBS volume ID."
  value       = { for k, v in aws_ebs_volume.this : k => v.id }
}

output "ebs_volume_arns" {
  description = "Map of resource key to EBS volume ARN."
  value       = { for k, v in aws_ebs_volume.this : k => v.arn }
}

output "volume_attachment_ids" {
  description = "Map of attachment key to aws_volume_attachment ID."
  value       = { for k, v in aws_volume_attachment.this : k => v.id }
}

output "alb_arns" {
  description = "Map of ALB resource key to ARN."
  value       = { for k, v in aws_lb.alb : k => v.arn }
}

output "alb_dns_names" {
  description = "Map of ALB resource key to DNS name."
  value       = { for k, v in aws_lb.alb : k => v.dns_name }
}

output "alb_zone_ids" {
  description = "Map of ALB resource key to canonical hosted zone ID."
  value       = { for k, v in aws_lb.alb : k => v.zone_id }
}

output "alb_listener_arns" {
  description = "Map of \"<alb_key>-<listener_key>\" to listener ARN."
  value       = { for k, v in aws_lb_listener.alb_listener : k => v.arn }
}

output "nlb_arns" {
  description = "Map of NLB resource key to ARN."
  value       = { for k, v in aws_lb.nlb : k => v.arn }
}

output "nlb_dns_names" {
  description = "Map of NLB resource key to DNS name."
  value       = { for k, v in aws_lb.nlb : k => v.dns_name }
}

output "nlb_zone_ids" {
  description = "Map of NLB resource key to canonical hosted zone ID."
  value       = { for k, v in aws_lb.nlb : k => v.zone_id }
}

output "nlb_listener_arns" {
  description = "Map of \"<nlb_key>-<listener_key>\" to listener ARN."
  value       = { for k, v in aws_lb_listener.nlb_listener : k => v.arn }
}

output "target_group_arns" {
  description = "Map of resource key to target-group ARN."
  value       = { for k, v in aws_lb_target_group.this : k => v.arn }
}

output "target_group_ids" {
  description = "Map of resource key to target-group ID."
  value       = { for k, v in aws_lb_target_group.this : k => v.id }
}
