module "ec2_fleet" {
  source = "./modules/ec2_fleet"

  providers = {
    aws = aws.account_a
  }

  ami_id                  = var.ami_id
  subnet_id               = var.subnet_id
  security_group_ids      = var.security_group_ids
  instances               = var.instances
  protected_instance_name = var.protected_instance_name
}
