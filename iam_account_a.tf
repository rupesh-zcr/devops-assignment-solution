locals {
  account_a_id = "000000000000"
  account_b_id = "111111111111"

  group1_users = toset(["engine", "ci"])
  group2_users = toset(["maya", "noah"])
  all_users    = setunion(local.group1_users, local.group2_users)
}

resource "aws_iam_group" "group1" {
  provider = aws.account_a
  name     = "group1"
}

resource "aws_iam_group" "group2" {
  provider = aws.account_a
  name     = "group2"
}

resource "aws_iam_user" "users" {
  provider = aws.account_a
  for_each = local.all_users

  name          = each.key
  force_destroy = false
}

resource "aws_iam_group_membership" "group1" {
  provider = aws.account_a
  name     = "group1-members"
  group    = aws_iam_group.group1.name
  users    = [for name in local.group1_users : aws_iam_user.users[name].name]
}

resource "aws_iam_group_membership" "group2" {
  provider = aws.account_a
  name     = "group2-members"
  group    = aws_iam_group.group2.name
  users    = [for name in local.group2_users : aws_iam_user.users[name].name]
}

# "Full console + CLI access" is represented here as administrative
# authorization plus optional credentials below. In production, use IAM
# Identity Center and short-lived role sessions instead.
resource "aws_iam_group_policy_attachment" "group2_administrator" {
  provider   = aws.account_a
  group      = aws_iam_group.group2.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_access_key" "programmatic" {
  provider = aws.account_a
  for_each = var.provision_legacy_iam_credentials ? local.all_users : toset([])

  user    = aws_iam_user.users[each.key].name
  pgp_key = var.credential_pgp_key
}

resource "aws_iam_user_login_profile" "console" {
  provider = aws.account_a
  for_each = var.provision_legacy_iam_credentials ? local.group2_users : toset([])

  user                    = aws_iam_user.users[each.key].name
  pgp_key                 = var.credential_pgp_key
  password_reset_required = true
}

data "aws_iam_policy_document" "role_a_trust" {
  provider = aws.account_a

  statement {
    sid     = "AllowAccountAPrincipals"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.account_a_id}:root"]
    }
  }
}

resource "aws_iam_role" "role_a" {
  provider           = aws.account_a
  name               = "roleA"
  assume_role_policy = data.aws_iam_policy_document.role_a_trust.json
}

data "aws_iam_policy_document" "role_a_permissions" {
  provider = aws.account_a

  statement {
    sid       = "AllowAllServices"
    effect    = "Allow"
    actions   = ["*"]
    resources = ["*"]
  }

  statement {
    sid       = "DenyIAM"
    effect    = "Deny"
    actions   = ["iam:*"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "role_a_permissions" {
  provider = aws.account_a
  name     = "admin-except-iam"
  role     = aws_iam_role.role_a.id
  policy   = data.aws_iam_policy_document.role_a_permissions.json
}

data "aws_iam_policy_document" "role_b_trust" {
  provider = aws.account_a

  statement {
    sid     = "AllowEngineToAssumeRoleB"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = [aws_iam_user.users["engine"].arn]
    }
  }
}

resource "aws_iam_role" "role_b" {
  provider           = aws.account_a
  name               = "roleB"
  assume_role_policy = data.aws_iam_policy_document.role_b_trust.json
}

data "aws_iam_policy_document" "role_b_permissions" {
  provider = aws.account_a

  statement {
    sid       = "AssumeOnlyRoleC"
    effect    = "Allow"
    actions   = ["sts:AssumeRole"]
    resources = ["arn:aws:iam::${local.account_b_id}:role/roleC"]
  }
}

resource "aws_iam_role_policy" "role_b_permissions" {
  provider = aws.account_a
  name     = "assume-roleC-only"
  role     = aws_iam_role.role_b.id
  policy   = data.aws_iam_policy_document.role_b_permissions.json
}

data "aws_iam_policy_document" "engine_assume_role_b" {
  provider = aws.account_a

  statement {
    effect    = "Allow"
    actions   = ["sts:AssumeRole"]
    resources = [aws_iam_role.role_b.arn]
  }
}

resource "aws_iam_user_policy" "engine_assume_role_b" {
  provider = aws.account_a
  name     = "assume-roleB"
  user     = aws_iam_user.users["engine"].name
  policy   = data.aws_iam_policy_document.engine_assume_role_b.json
}
