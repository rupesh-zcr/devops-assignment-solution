locals {
  all_instances = merge(aws_instance.standard, aws_instance.protected)
}

output "instance_ids" {
  description = "Map of instance name to instance ID."
  value = {
    for name, instance in local.all_instances : name => instance.id
  }
}

output "instance_private_ips" {
  description = "Map of instance name to private IP."
  value = {
    for name, instance in local.all_instances : name => instance.private_ip
  }
}
