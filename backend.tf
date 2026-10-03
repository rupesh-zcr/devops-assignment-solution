terraform {
  # Values are supplied with -backend-config because a backend cannot refer to
  # Terraform variables or to resources in the same state.
  backend "s3" {}
}
