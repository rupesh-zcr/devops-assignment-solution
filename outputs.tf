output "instance_ids" {
  description = "Map of instance name to EC2 instance ID."
  value       = module.ec2_fleet.instance_ids
}

output "instance_private_ips" {
  description = "Map of instance name to private IP address."
  value       = module.ec2_fleet.instance_private_ips
}

output "legacy_access_key_ids" {
  description = "Access-key IDs created only when the legacy credential switch is enabled."
  value = {
    for name, key in aws_iam_access_key.programmatic : name => key.id
  }
}

output "legacy_encrypted_secrets" {
  description = "PGP-encrypted access-key secrets; decrypt locally with the matching private key."
  value = {
    for name, key in aws_iam_access_key.programmatic : name => key.encrypted_secret
  }
  sensitive = true
}

output "legacy_encrypted_console_passwords" {
  description = "PGP-encrypted initial console passwords for group2 members."
  value = {
    for name, profile in aws_iam_user_login_profile.console : name => profile.encrypted_password
  }
  sensitive = true
}
