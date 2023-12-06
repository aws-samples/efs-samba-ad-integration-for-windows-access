module "efs" {
  source = "git::https://github.com/terraform-aws-modules/terraform-aws-efs.git?ref=8cdc5b65d3b92f4211271621a567e4ce6b4dc469"

  # File system
  name = "${var.project_name}-${var.project_env}"

  encrypted        = true
  performance_mode = "generalPurpose"

  lifecycle_policy = {
    transition_to_ia                    = "AFTER_30_DAYS"
    transition_to_primary_storage_class = "AFTER_1_ACCESS"
  }

  # File system policy
  attach_policy                      = false
  bypass_policy_lockout_safety_check = false
  policy_statements = [
    {
      sid     = "Example"
      actions = ["elasticfilesystem:ClientMount"]
      principals = [
        {
          type        = "AWS"
          identifiers = [data.aws_caller_identity.current.arn]
        }
      ]
    }
  ]

  # Mount targets / security groups
  create_security_group = false

  # Just creating a single mount target in the same private subnet as the Samba server
  mount_targets = [
    {
      subnet_id = element(data.aws_subnets.private.ids, 0)
      security_groups = [data.aws_ssm_parameter.SecurityGroupId.value]
    }
  ]
  # Use this to create mount targets for each private subnet in a VPC
  # mount_targets = {
    # for k, v in zipmap(local.project.azs, data.aws_subnets.private.ids) : k => { subnet_id = v, security_groups = [data.aws_ssm_parameter.SecurityGroupId.value] }
  # }

  create_backup_policy = false
  enable_backup_policy = false

  tags = merge(local.project.tags,
    {
      Repository = "https://github.com/terraform-aws-modules/terraform-aws-efs"
    }
  )
}

# This parameter is just for use with initial testing
resource "aws_ssm_parameter" "this" {
  #checkov:skip=CKV_AWS_337: The parameter is encrypted with an AWS managed key
  #checkov:skip=CKV2_AWS_34: The parameter is encrypted with an AWS managed key
  for_each = toset(local.samba_config.users)

  name  = "/${var.project_name}/${var.project_env}/samba/${each.key}"
  type  = "SecureString"
  value = "samba"
}

resource "local_file" "user-data-samba" {
  count    = local.samba_server.user_data_opts.write_rendered_output == true ? 1 : 0
  content  = templatefile(local.samba_server.user_data_opts.path, local.samba_server.user_data_vars)
  filename = "${path.cwd}/user-data-samba.sh"
}

# Deploying individual instances instead of an ASG to take advantage of simplified instance recovery with consistent IP mapping
module "samba_server" {
  source = "git::https://github.com/terraform-aws-modules/terraform-aws-ec2-instance.git?ref=6c13542c52e4ed87ca959b2027c85146e8548ac6"
  count  = local.samba.enable_ha == true ? 2 : 1
  # Hidden dependencies on the EFS file systems and (temp) parameters that are referenced in the user-data
  depends_on = [
    module.efs,
    aws_ssm_parameter.this
  ]

  name                   = "SambaServer-${var.project_env}"
  ami                    = data.aws_ami.al2.id
  ignore_ami_changes     = true
  instance_type          = "t2.micro"
  key_name               = var.key_name
  subnet_id              = element(data.aws_subnets.private.ids, 0)
  vpc_security_group_ids = [data.aws_ssm_parameter.SecurityGroupId.value]

  associate_public_ip_address = false

  maintenance_options = {
    auto_recovery = "default"
  }

  create_iam_instance_profile = false
  iam_instance_profile        = data.aws_ssm_parameter.SambaServerRoleName.value

  user_data_base64 = data.template_cloudinit_config.samba_server_user_data.rendered

  enable_volume_tags = false
  root_block_device = [
    {
      delete_on_termination = true
      encrypted             = true
      volume_type           = "gp2"
      volume_size           = 30
      tags                  = merge(local.project.tags)
    }
  ]

  metadata_options = {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "enabled"
  }

  tags = merge(local.project.tags,
    {
      Repository = "https://github.com/terraform-aws-modules/terraform-aws-ec2-instance"
    }
  )
}

output "samba_server_private_ip_addresses" {
  value = tomap({ for k, v in module.samba_server[*].private_ip : "server${k}" => v })
}
