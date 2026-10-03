provider "aws" {
  alias  = "account_a"
  region = var.aws_region

  # In a real deployment, credentials come from AWS SSO or the environment.
  # The profile is optional so this works in CI with workload identity too.
  profile = var.account_a_profile

  default_tags {
    tags = {
      ManagedBy = "Terraform"
      Project   = "devops-assignment"
    }
  }
}

provider "aws" {
  alias   = "account_b"
  region  = var.aws_region
  profile = var.account_b_profile

  default_tags {
    tags = {
      ManagedBy = "Terraform"
      Project   = "devops-assignment"
    }
  }
}
