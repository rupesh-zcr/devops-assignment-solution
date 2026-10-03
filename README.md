# DevOps Assignment Solution

This repository answers all five tasks in the supplied assessment. It provisions a five-instance EC2 fleet from one input, bootstraps remote state and locking, defines the cross-account IAM path, and attaches a least-privilege CI policy.

The account IDs in the brief (`000000000000` and `111111111111`) are placeholders. Replace them, along with the example resource names and ARNs, before applying.

## Repository layout

```text
.
├── backend.tf                 # Partial S3 backend declaration
├── backend.hcl.example        # Backend values supplied during terraform init
├── bootstrap/backend/         # One-time S3 bucket and DynamoDB table bootstrap
├── ci-policy.json             # Reviewable JSON form of the CI policy
├── ci_policy.tf               # Terraform-generated equivalent attached to ci
├── iam_account_a.tf           # Users, groups, roleA, and roleB
├── iam_account_b.tf           # roleC and its one-bucket policy
├── modules/ec2_fleet/         # Reusable EC2 module
├── NOTES.md                   # Design decisions and direct written answers
└── terraform.tfvars.example   # Five distinct instance definitions
```

## Prerequisites

- Terraform 1.5 or later
- AWS credentials for both accounts, preferably short-lived sessions from AWS IAM Identity Center
- Existing VPC subnet, security groups, AMI, EC2 key pairs, ECR repository, ECS service, ECS task roles, and S3 data buckets
- Permission to create the resources declared here

No access key, secret key, password, or private key is stored in this repository.

## Bootstrap remote state

The backend must exist before the main configuration can use it. Run the small bootstrap configuration once with Account A credentials:

```bash
cd bootstrap/backend
terraform init
terraform apply -var='state_bucket_name=replace-with-a-globally-unique-name'
```

Copy `backend.hcl.example` to `backend.hcl`, set the created bucket name, then initialize the root configuration:

```bash
cd ../..
cp backend.hcl.example backend.hcl
terraform init -backend-config=backend.hcl
```

For a real environment, preserve or migrate the bootstrap state to protected remote storage after creation. Do not commit `backend.hcl` if it contains environment-specific details.

## Configure and review

```bash
cp terraform.tfvars.example terraform.tfvars
terraform fmt -recursive -check
terraform validate
terraform plan
```

Replace every sample value in `terraform.tfvars`. The five named key pairs must already exist in Account A and the selected region.

## Apply

The root configuration uses two aliased AWS providers. With local profiles, set:

```hcl
account_a_profile = "account-a"
account_b_profile = "account-b"
```

In CI, leave those variables null and use injected short-lived AWS credentials or workload identity. Because a process normally has only one active AWS credential chain, a production implementation would commonly configure Account B through `assume_role` from a deployment role rather than two local profiles.

After reviewing the plan:

```bash
terraform apply
```

`database` is protected by `prevent_destroy`. Terraform will intentionally reject a plan that destroys or replaces it. To perform an approved destructive change, remove the protection in a reviewed code change, apply, and restore the protection afterward.

## Legacy IAM credentials

The configuration models the access modes in the brief but does not create long-lived credentials by default. If an assessor needs to demonstrate them, set `provision_legacy_iam_credentials = true` and provide `credential_pgp_key`. Secrets and initial console passwords are then PGP-encrypted in Terraform output. This switch should remain false in production.
