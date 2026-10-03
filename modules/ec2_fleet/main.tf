locals {
  protected_instance = {
    for name, config in var.instances : name => config
    if name == var.protected_instance_name
  }

  standard_instances = {
    for name, config in var.instances : name => config
    if name != var.protected_instance_name
  }
}

resource "aws_instance" "standard" {
  for_each = local.standard_instances

  ami                    = var.ami_id
  instance_type          = each.value.instance_type
  key_name               = each.value.key_name
  subnet_id              = var.subnet_id
  vpc_security_group_ids = var.security_group_ids

  root_block_device {
    volume_type = each.value.root_volume_type
    volume_size = each.value.root_volume_size
    iops        = contains(["io1", "io2", "gp3"], each.value.root_volume_type) ? try(each.value.iops, null) : null
    encrypted   = true
  }

  tags = {
    Name        = each.key
    Environment = each.value.environment
    Owner       = each.value.owner
  }
}

# Lifecycle meta-arguments cannot be dynamic. A second for_each resource keeps
# all instances driven by the same input while protecting exactly one of them.
resource "aws_instance" "protected" {
  for_each = local.protected_instance

  ami                    = var.ami_id
  instance_type          = each.value.instance_type
  key_name               = each.value.key_name
  subnet_id              = var.subnet_id
  vpc_security_group_ids = var.security_group_ids

  root_block_device {
    volume_type = each.value.root_volume_type
    volume_size = each.value.root_volume_size
    iops        = contains(["io1", "io2", "gp3"], each.value.root_volume_type) ? try(each.value.iops, null) : null
    encrypted   = true
  }

  tags = {
    Name        = each.key
    Environment = each.value.environment
    Owner       = each.value.owner
  }

  lifecycle {
    prevent_destroy = true
  }
}
