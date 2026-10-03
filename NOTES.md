# DevOps Assignment Notes

## Task 1 Multi Instance EC2 Provisioning

All five instances are supplied through the single `instances` map. Validation requires exactly five entries and ensures their instance types, root-volume types, root-volume sizes, and key pairs are all unique. The module filters that map into a four-instance standard set and a one-instance protected set. This uses two generic `for_each` resources rather than five hardcoded resources.

The split is necessary because Terraform lifecycle values such as `prevent_destroy` must be literal and apply to an entire resource block; they cannot be calculated differently for individual `for_each` instances. The `database` instance is the protected item because its persistent workload and potential data loss give it the highest replacement risk. Its `io2` root volume also satisfies the provisioned-IOPS requirement.

The module produces two maps: instance name to instance ID, and instance name to private IP. Every instance receives `Name`, `Environment`, and `Owner` tags, and every root volume is encrypted.

## Task 2 Remote State and Locking

With local state, each engineer has a separate view of the infrastructure. If two people run `terraform apply` at the same time, neither process can see or lock the other person's local file. Both can plan against stale state and issue overlapping AWS changes; whichever state file is saved does not reliably describe the combined result. This can cause duplicate resources, failed API operations, configuration drift, or later destructive reconciliation.

The S3 backend gives the team one shared state object. The DynamoDB table stores a lock record keyed by `LockID`; a state-changing operation acquires that lock before it writes, so another operation waits or fails instead of modifying the same state concurrently. S3 versioning provides recovery from accidental state overwrites, server-side encryption protects the stored object, and public access is blocked.

The backend is partial because backend blocks cannot use normal Terraform variables or resources. `bootstrap/backend` creates the bucket and table first; `terraform init -backend-config=backend.hcl` then configures and migrates the main state.

## Task 3 Multi Account IAM and Cross Account Access

Account A contains:

- `group1`, with the programmatic-only users `engine` and `ci`.
- `group2`, with the named users `maya` and `noah`, plus administrative authorization and optional console and CLI credentials.
- `roleA`, whose policy allows all actions and then explicitly denies `iam:*`. The explicit deny ensures an overlapping allow cannot restore IAM access.
- `roleB`, whose only identity-policy permission is `sts:AssumeRole` on the exact `roleC` ARN in Account B. Its trust policy allows only `engine` to assume it, and `engine` receives the matching caller-side permission.

Account B contains `roleC`. Its trust policy names the exact `roleB` ARN. Its permissions policy grants `s3:*` only on the named bucket ARN and that bucket's object ARN. Both ARNs are required because bucket-level actions target the bucket while object-level actions target `bucket/*`.

### Would I create IAM users and access keys for engine and ci in production

No. For a human engineer, I would use AWS IAM Identity Center with the organization's identity provider, MFA, permission sets, and short-lived role sessions. For CI, I would use workload identity federation, such as GitHub Actions OIDC or the CI platform's native OIDC provider, so each job receives short-lived credentials for a tightly scoped role. Long-lived IAM access keys create rotation, leakage, attribution, and offboarding risks.

The resources remain in this assessment because the brief explicitly asks for IAM users. Long-lived keys and console passwords are behind `provision_legacy_iam_credentials`, defaulting to false, and are PGP-encrypted if deliberately enabled.

### Why roleC trusts roleB instead of the Account A root principal

Trusting `arn:aws:iam::000000000000:root` delegates trust to the whole Account A. Any principal in that account that an Account A administrator later grants `sts:AssumeRole` could become eligible to reach `roleC`. Trusting `arn:aws:iam::000000000000:role/roleB` narrows the trust boundary to one role. The caller still needs the identity-side permission, but unrelated Account A users and roles are not accepted by roleC's trust policy.

## Task 4 Least Privilege CI Policy

`ci-policy.json` is the requested policy JSON. `ci_policy.tf` builds the same policy from variables and attaches it directly to `ci`.

The policy allows only:

- ECR authentication plus the five upload actions on one repository.
- Registering and reading task definitions, for which AWS does not offer useful resource-level scoping.
- Describing and updating one ECS service.
- Listing one artifact bucket and reading objects and object versions from that bucket.
- Passing only the named ECS task roles, and only to `ecs-tasks.amazonaws.com`.

I deliberately left out ECR deletion and repository administration; ECS cluster, service-creation, service-deletion, execute-command, and capacity operations; S3 writes and deletes; arbitrary `iam:PassRole`; and general IAM or STS access. Those permissions are not needed by the stated pipeline and would expand its blast radius. `ecr:GetAuthorizationToken`, `ecs:RegisterTaskDefinition`, and `ecs:DescribeTaskDefinition` use `Resource: "*"` because those API actions cannot be restricted to the target repository or task-definition ARN in an identity policy.

## Task 5 Bug Fix

The trust-policy principal in the broken snippet is an IAM user ARN:

```text
arn:aws:iam::000000000000:user/roleB
```

`roleB` is a role, so roleC must trust its role ARN:

```text
arn:aws:iam::000000000000:role/roleB
```

The original trust failed because STS evaluated a different principal type and identity; a user named `roleB` is not the `roleB` role session.

The second issue is roleC's `s3:*` permission on `Resource: "*"`. That grants access to every S3 resource the role can reach rather than the single required bucket. The fix scopes bucket-level actions to:

```text
arn:aws:s3:::company-cross-account-data
```

and object-level actions to:

```text
arn:aws:s3:::company-cross-account-data/*
```

The corrected implementation is in `iam_account_b.tf`. The caller-side `roleB` policy in `iam_account_a.tf` is also restricted to the exact roleC ARN, so both sides of the cross-account handshake are explicit.

## Assumptions

- The supplied account IDs are assessment placeholders.
- The named VPC, EC2 key pairs, AMI, ECR repository, ECS service, task roles, and data buckets already exist.
- The same AWS region is used for the regional resources in both accounts.
- Real credentials are supplied outside Terraform and are never committed.
