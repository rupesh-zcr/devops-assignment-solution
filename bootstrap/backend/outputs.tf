output "backend_config" {
  description = "Values to use with terraform init -backend-config."
  value = {
    bucket         = aws_s3_bucket.state.id
    key            = "devops-assignment/terraform.tfstate"
    region         = var.aws_region
    dynamodb_table = aws_dynamodb_table.locks.name
    encrypt        = true
  }
}
