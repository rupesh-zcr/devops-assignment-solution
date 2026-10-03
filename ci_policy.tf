data "aws_partition" "current" {
  provider = aws.account_a
}

data "aws_iam_policy_document" "ci_least_privilege" {
  provider = aws.account_a

  statement {
    sid       = "GetECRAuthorizationToken"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid    = "PushImageToOneRepository"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart"
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:ecr:${var.aws_region}:${local.account_a_id}:repository/${var.ci_ecr_repository_name}"
    ]
  }

  # RegisterTaskDefinition and DescribeTaskDefinition do not support resource-
  # level permissions, so AWS requires Resource "*" for these actions.
  statement {
    sid    = "RegisterAndReadTaskDefinition"
    effect = "Allow"
    actions = [
      "ecs:RegisterTaskDefinition",
      "ecs:DescribeTaskDefinition"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "DeployOnlyToNamedService"
    effect = "Allow"
    actions = [
      "ecs:DescribeServices",
      "ecs:UpdateService"
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:ecs:${var.aws_region}:${local.account_a_id}:service/${var.ci_ecs_cluster_name}/${var.ci_ecs_service_name}"
    ]
  }

  statement {
    sid       = "ListArtifactBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = ["arn:${data.aws_partition.current.partition}:s3:::${var.ci_artifact_bucket_name}"]
  }

  statement {
    sid       = "ReadArtifactObjects"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:GetObjectVersion"]
    resources = ["arn:${data.aws_partition.current.partition}:s3:::${var.ci_artifact_bucket_name}/*"]
  }

  statement {
    sid       = "PassOnlyApprovedECSTaskRoles"
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = var.ci_task_role_arns

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_user_policy" "ci_least_privilege" {
  provider = aws.account_a
  name     = "ci-pipeline-least-privilege"
  user     = aws_iam_user.users["ci"].name
  policy   = data.aws_iam_policy_document.ci_least_privilege.json
}
