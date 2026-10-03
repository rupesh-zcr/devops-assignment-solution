variable "aws_region" {
  description = "AWS region used in both accounts."
  type        = string
  default     = "us-east-1"
}

variable "account_a_profile" {
  description = "Optional local AWS CLI profile for Account A; leave null in CI."
  type        = string
  default     = null
  nullable    = true
}

variable "account_b_profile" {
  description = "Optional local AWS CLI profile for Account B; leave null in CI."
  type        = string
  default     = null
  nullable    = true
}

variable "ami_id" {
  description = "AMI ID used by all five EC2 instances."
  type        = string
}

variable "subnet_id" {
  description = "Subnet in Account A in which the EC2 instances are created."
  type        = string
}

variable "security_group_ids" {
  description = "Security groups to attach to every EC2 instance."
  type        = list(string)
  default     = []
}

variable "instances" {
  description = "Five EC2 instance definitions keyed by instance name."
  type = map(object({
    instance_type    = string
    root_volume_type = string
    root_volume_size = number
    key_name         = string
    environment      = string
    owner            = string
    iops             = optional(number)
  }))

  validation {
    condition     = length(var.instances) == 5
    error_message = "Exactly five instance definitions must be supplied."
  }

  validation {
    condition = (
      length(distinct([for instance in values(var.instances) : instance.instance_type])) == 5 &&
      length(distinct([for instance in values(var.instances) : instance.root_volume_type])) == 5 &&
      length(distinct([for instance in values(var.instances) : instance.root_volume_size])) == 5 &&
      length(distinct([for instance in values(var.instances) : instance.key_name])) == 5
    )
    error_message = "All five instances must have different instance types, root volume types, root volume sizes, and key pairs."
  }

  validation {
    condition = alltrue([
      for instance in values(var.instances) :
      contains(["standard", "gp2", "gp3", "io1", "io2", "sc1", "st1"], instance.root_volume_type)
    ])
    error_message = "Every root_volume_type must be a valid EBS volume type."
  }

  validation {
    condition = anytrue([
      for instance in values(var.instances) :
      contains(["io1", "io2"], instance.root_volume_type)
    ])
    error_message = "At least one instance must use io1 or io2 storage."
  }

  validation {
    condition = alltrue([
      for instance in values(var.instances) :
      !contains(["io1", "io2"], instance.root_volume_type) || try(instance.iops, null) != null
    ])
    error_message = "Instances using io1 or io2 must specify iops."
  }
}

variable "protected_instance_name" {
  description = "The one instance whose Terraform lifecycle prevents deletion."
  type        = string
  default     = "database"

  validation {
    condition     = contains(keys(var.instances), var.protected_instance_name)
    error_message = "protected_instance_name must match a key in instances."
  }
}

variable "account_b_bucket_name" {
  description = "Existing bucket in Account B to which roleC receives full access."
  type        = string
  default     = "company-cross-account-data"
}

variable "ci_ecr_repository_name" {
  description = "Existing ECR repository to which ci may push."
  type        = string
  default     = "application"
}

variable "ci_ecs_cluster_name" {
  description = "Existing ECS cluster containing the deployment target."
  type        = string
  default     = "production"
}

variable "ci_ecs_service_name" {
  description = "Existing ECS service that ci may update."
  type        = string
  default     = "application"
}

variable "ci_artifact_bucket_name" {
  description = "Existing S3 bucket from which ci may read build artifacts."
  type        = string
  default     = "company-build-artifacts"
}

variable "ci_task_role_arns" {
  description = "Exact ECS task and execution role ARNs that ci may pass."
  type        = set(string)
  default = [
    "arn:aws:iam::000000000000:role/ecsTaskExecutionRole",
    "arn:aws:iam::000000000000:role/applicationTaskRole"
  ]
}

variable "credential_pgp_key" {
  description = "Optional PGP public key used only if legacy IAM credentials are intentionally provisioned."
  type        = string
  default     = null
  nullable    = true
}

variable "provision_legacy_iam_credentials" {
  description = "Create encrypted access keys and console passwords for the assessment users. Keep false in production."
  type        = bool
  default     = false

  validation {
    condition     = !var.provision_legacy_iam_credentials || var.credential_pgp_key != null
    error_message = "credential_pgp_key is required when legacy IAM credentials are provisioned."
  }
}
