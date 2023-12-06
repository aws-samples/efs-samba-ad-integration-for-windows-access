data "aws_partition" "current" {}
data "aws_region" "current" {}
data "aws_availability_zones" "available" {}
data "aws_caller_identity" "current" {}

data "aws_ssm_parameter" "SambaServerRoleName" {
  name = "/${var.project_name}/${var.project_env}/iam/SambaServer/role_name"
}

data "aws_ssm_parameter" "SecurityGroupId" {
  name = "/${var.project_name}/${var.project_env}/SecurityGroupId/id"
}

data "aws_vpc" "this" {
  filter {
    name   = "tag:Name"
    values = [var.vpc_name]
  }
}

data "aws_subnets" "private" {
  filter {
    name   = "tag:Name"
    values = ["${var.vpc_name}-subnet-private*"]
  }
}

data "aws_subnets" "public" {
  filter {
    name   = "tag:Name"
    values = ["${var.vpc_name}-subnet-public*"]
  }
}

data "aws_ami" "al2" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "template_cloudinit_config" "samba_server_user_data" {
  gzip          = false
  base64_encode = true

  part {
    content_type = "text/x-shellscript"
    content      = templatefile(local.samba_server.user_data_opts.path, local.samba_server.user_data_vars)
  }

}
