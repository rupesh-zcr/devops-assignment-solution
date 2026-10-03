variable "ami_id" {
  description = "AMI used by the fleet."
  type        = string
}

variable "subnet_id" {
  description = "Subnet used by the fleet."
  type        = string
}

variable "security_group_ids" {
  description = "Security groups attached to all instances."
  type        = list(string)
}

variable "instances" {
  description = "Instance definitions keyed by Name tag value."
  type = map(object({
    instance_type    = string
    root_volume_type = string
    root_volume_size = number
    key_name         = string
    environment      = string
    owner            = string
    iops             = optional(number)
  }))
}

variable "protected_instance_name" {
  description = "Instance key protected with prevent_destroy."
  type        = string
}
