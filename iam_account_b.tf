data "aws_iam_policy_document" "role_c_trust" {
  provider = aws.account_b

  statement {
    sid     = "AllowOnlyRoleB"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.role_b.arn]
    }
  }
}

resource "aws_iam_role" "role_c" {
  provider           = aws.account_b
  name               = "roleC"
  assume_role_policy = data.aws_iam_policy_document.role_c_trust.json
}

data "aws_iam_policy_document" "role_c_s3" {
  provider = aws.account_b

  statement {
    sid     = "BucketLevelAccess"
    effect  = "Allow"
    actions = ["s3:*"]
    resources = [
      "arn:aws:s3:::${var.account_b_bucket_name}"
    ]
  }

  statement {
    sid     = "ObjectLevelAccess"
    effect  = "Allow"
    actions = ["s3:*"]
    resources = [
      "arn:aws:s3:::${var.account_b_bucket_name}/*"
    ]
  }
}

resource "aws_iam_role_policy" "role_c_s3" {
  provider = aws.account_b
  name     = "single-bucket-full-access"
  role     = aws_iam_role.role_c.id
  policy   = data.aws_iam_policy_document.role_c_s3.json
}
