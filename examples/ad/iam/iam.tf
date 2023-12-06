data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

locals {

  policy_vars = {
    Partition    = data.aws_partition.current.partition
    Region       = data.aws_region.current.name
    Account      = data.aws_caller_identity.current.account_id
    project_name = var.project_name
    project_env  = var.project_env
  }

  # Add name of policy to this list to create customer managed policy and role of the same name
  roles = toset([
    "SambaServer"
  ])

}

resource "aws_iam_role" "this" {
  for_each = local.roles

  name        = "${each.key}-${var.project_env}"
  description = "Customer CAP role"

  assume_role_policy = jsonencode(
    {
      Version = "2012-10-17"
      Statement = [
        {
          Sid    = "EC2AssumeRole"
          Effect = "Allow"
          Principal = {
            Service = "ec2.${data.aws_partition.current.dns_suffix}"
          }
          Action = ["sts:AssumeRole"]
        }
      ]
    }
  )

  tags = {
    Application = local.policy_vars.project_name
    Environment = local.policy_vars.project_env
  }
}

resource "aws_iam_instance_profile" "this" {
  for_each = local.roles

  name = "${each.key}-${var.project_env}"
  role = aws_iam_role.this[each.key].name
}

resource "aws_ssm_parameter" "role_name" {
  #checkov:skip=CKV_AWS_337: The parameter is encrypted with an AWS managed key
  #checkov:skip=CKV2_AWS_34: The parameter is encrypted with an AWS managed key
  for_each = local.roles

  name  = "/${local.policy_vars.project_name}/${local.policy_vars.project_env}/iam/${each.key}/role_name"
  type  = "String"
  value = aws_iam_role.this[each.key].name
}

resource "aws_iam_policy" "this" {
  for_each = local.roles

  name        = "${each.key}-${var.project_env}"
  description = "Customer managed policy for the efs-windows feature"
  policy      = templatefile("${var.repo_path}/iam/policies/${each.key}.json", local.policy_vars)

  tags = {
    Application = local.policy_vars.project_name
    Environment = local.policy_vars.project_env
  }
}

resource "aws_iam_role_policy_attachment" "this" {
  for_each = local.roles

  role       = aws_iam_role.this[each.key].name
  policy_arn = aws_iam_policy.this[each.key].arn
}
