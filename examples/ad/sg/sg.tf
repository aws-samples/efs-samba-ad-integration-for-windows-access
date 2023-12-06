data "aws_partition" "current" {}
data "aws_region" "current" {}

data "aws_vpc" "this" {
  filter {
    name   = "tag:Name"
    values = [var.vpc_name]
  }
}

data "aws_ssm_parameter" "this" {
  name = "remote_instances_cidr_blocks"
}

data "aws_directory_service_directory" "this" {
  directory_id = "d-90678b7f62"
}

locals {

  security_group = {
    remote_prefix_lists = ["pl-60b85b09"]
  }

  vpc = {
    vpc_name = "mad"
  }

  global = {
    tags = {
      Application = var.project_name
      ProjectEnv  = var.project_env
    }
  }
}

resource "aws_security_group" "this" {
  #checkov:skip=CKV2_AWS_5: The security group is attached to resources in the main stack
  description = "Allows Samba server to communicated with EFS, AD, WorkSpaces, and remote admins"
  name        = "${var.project_name}-${var.project_env}"
  vpc_id      = data.aws_vpc.this.id

  tags = local.global.tags
}

resource "aws_ssm_parameter" "this" {
  #checkov:skip=CKV_AWS_337: The parameter is encrypted with an AWS managed key
  #checkov:skip=CKV2_AWS_34: The parameter is encrypted with an AWS managed key
  name  = "/${var.project_name}/${var.project_env}/SecurityGroupId/id"
  type  = "String"
  value = aws_security_group.this.id
}

resource "aws_security_group_rule" "nfs_ingress" {
  security_group_id        = aws_security_group.this.id
  type                     = "ingress"
  from_port                = 2049
  to_port                  = 2049
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.this.id
  description              = "NFS ingress within SG"
}

resource "aws_security_group_rule" "nfs_egress" {
  security_group_id        = aws_security_group.this.id
  type                     = "egress"
  from_port                = 2049
  to_port                  = 2049
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.this.id
  description              = "NFS egress within SG"
}

resource "aws_security_group_rule" "ssh_remote_ingress" {
  security_group_id = aws_security_group.this.id
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = [data.aws_ssm_parameter.this.value]
  description       = "SSH ingress from remote instances"
}

resource "aws_security_group_rule" "ssh_sg_ingress" {
  security_group_id        = aws_security_group.this.id
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.this.id
  description              = "SSH ingress within SG"
}

resource "aws_security_group_rule" "ssh_pl_ingress" {
  count = data.aws_partition.current.partition == "aws" && data.aws_region.current.name == "us-east-1" ? 1 : 0 # Cannot create, manage, or use customer-managed prefix lists in aws-iso

  security_group_id = aws_security_group.this.id
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  prefix_list_ids   = local.security_group.remote_prefix_lists
  description       = "SSH ingress from remote IPs in prefix list (for Samba server)"
}

resource "aws_security_group_rule" "ssh_sg_egress" {
  security_group_id        = aws_security_group.this.id
  type                     = "egress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.this.id
  description              = "SSH egress within SG"
}

resource "aws_security_group_rule" "https_egress" {
  security_group_id = aws_security_group.this.id
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "HTTPS egress for Session Manager"
}

resource "aws_security_group_rule" "http_egress" {
  security_group_id = aws_security_group.this.id
  type              = "egress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "HTTP egress for repositories"
}

resource "aws_security_group_rule" "rdp_sg_ingress" {
  security_group_id = aws_security_group.this.id
  type              = "ingress"
  from_port         = 3389
  to_port           = 3389
  protocol          = "tcp"
  cidr_blocks       = [data.aws_ssm_parameter.this.value]
  description       = "RDP ingress from remote instances (for WindowsServer)"
}

resource "aws_security_group_rule" "rdp_sg_ingress2" {
  count = data.aws_partition.current.partition == "aws" && data.aws_region.current.name == "us-east-1" ? 1 : 0 # Cannot create, manage, or use customer-managed prefix lists in aws-iso

  security_group_id = aws_security_group.this.id
  type              = "ingress"
  from_port         = 3389
  to_port           = 3389
  protocol          = "tcp"
  prefix_list_ids   = local.security_group.remote_prefix_lists
  description       = "RDP ingress from remote IPs in prefix list (for WindowsServer)"
}

resource "aws_security_group_rule" "smb_ingress_tcp" {
  security_group_id = aws_security_group.this.id
  type              = "ingress"
  from_port         = 445
  to_port           = 445
  protocol          = "tcp"
  cidr_blocks       = [data.aws_vpc.this.cidr_block]
  description       = "SMB ingress for Samba; replication, user and computer authentication, group policy, trusts"
}

resource "aws_security_group_rule" "smb_ingress_udp" {
  security_group_id = aws_security_group.this.id
  type              = "ingress"
  from_port         = 445
  to_port           = 445
  protocol          = "udp"
  cidr_blocks       = [data.aws_vpc.this.cidr_block]
  description       = "SMB ingress for Samba; replication, user and computer authentication, group policy, trusts"
}

resource "aws_security_group_rule" "smb_egress_tcp" {
  security_group_id = aws_security_group.this.id
  type              = "egress"
  from_port         = 445
  to_port           = 445
  protocol          = "tcp"
  cidr_blocks       = [data.aws_vpc.this.cidr_block]
  description       = "SMB egress for Samba; replication, user and computer authentication, group policy, trusts"
}

resource "aws_security_group_rule" "smb_egress_udp" {
  security_group_id = aws_security_group.this.id
  type              = "egress"
  from_port         = 445
  to_port           = 445
  protocol          = "udp"
  cidr_blocks       = [data.aws_vpc.this.cidr_block]
  description       = "SMB egress for Samba; replication, user and computer authentication, group policy, trusts"
}

# DNS egress is also needed for instances that aren't part of the domain if the AD DNS servers are being used in the VPC DHCP options set.
resource "aws_security_group_rule" "dns_egress_tcp" {
  security_group_id        = aws_security_group.this.id
  type                     = "egress"
  from_port                = 53
  to_port                  = 53
  protocol                 = "tcp"
  source_security_group_id = data.aws_directory_service_directory.this.security_group_id
  description              = "DNS; AD User and computer authentication, name resolution, trusts"
}

resource "aws_security_group_rule" "dns_egress_udp" {
  security_group_id        = aws_security_group.this.id
  type                     = "egress"
  from_port                = 53
  to_port                  = 53
  protocol                 = "udp"
  source_security_group_id = data.aws_directory_service_directory.this.security_group_id
  description              = "DNS; AD User and computer authentication, name resolution, trusts"
}

resource "aws_security_group_rule" "kerberos_egress_tcp" {
  security_group_id        = aws_security_group.this.id
  type                     = "egress"
  from_port                = 88
  to_port                  = 88
  protocol                 = "tcp"
  source_security_group_id = data.aws_directory_service_directory.this.security_group_id
  description              = "Kerberos; AD user and computer authentication"
}

resource "aws_security_group_rule" "kerberos_egress_udp" {
  security_group_id        = aws_security_group.this.id
  type                     = "egress"
  from_port                = 88
  to_port                  = 88
  protocol                 = "udp"
  source_security_group_id = data.aws_directory_service_directory.this.security_group_id
  description              = "Kerberos; AD user and computer authentication"
}

resource "aws_security_group_rule" "ldap_egress_tcp" {
  security_group_id        = aws_security_group.this.id
  type                     = "egress"
  from_port                = 389
  to_port                  = 389
  protocol                 = "tcp"
  source_security_group_id = data.aws_directory_service_directory.this.security_group_id
  description              = "LDAP; AD directory, replication, user and computer authentication group policy, trusts"
}

resource "aws_security_group_rule" "ldap_egress_udp" {
  security_group_id        = aws_security_group.this.id
  type                     = "egress"
  from_port                = 389
  to_port                  = 389
  protocol                 = "udp"
  source_security_group_id = data.aws_directory_service_directory.this.security_group_id
  description              = "LDAP; AD directory, replication, user and computer authentication group policy, trusts"
}

resource "aws_security_group_rule" "kerberos_pw_egress_tcp" {
  security_group_id        = aws_security_group.this.id
  type                     = "egress"
  from_port                = 464
  to_port                  = 464
  protocol                 = "tcp"
  source_security_group_id = data.aws_directory_service_directory.this.security_group_id
  description              = "Kerberos change/set password; AD replication, user and computer authentication, trusts"
}

resource "aws_security_group_rule" "kerberos_pw_egress_udp" {
  security_group_id        = aws_security_group.this.id
  type                     = "egress"
  from_port                = 464
  to_port                  = 464
  protocol                 = "udp"
  source_security_group_id = data.aws_directory_service_directory.this.security_group_id
  description              = "Kerberos change/set password; AD replication, user and computer authentication, trusts"
}

resource "aws_security_group_rule" "replication_egress" {
  security_group_id        = aws_security_group.this.id
  type                     = "egress"
  from_port                = 135
  to_port                  = 135
  protocol                 = "tcp"
  source_security_group_id = data.aws_directory_service_directory.this.security_group_id
  description              = "Replication; ADC RPC, EPM"
}

resource "aws_security_group_rule" "ldap_ssl_egress" {
  security_group_id        = aws_security_group.this.id
  type                     = "egress"
  from_port                = 636
  to_port                  = 636
  protocol                 = "tcp"
  source_security_group_id = data.aws_directory_service_directory.this.security_group_id
  description              = "LDAP SSL; AD Directory, replication, user and computer authentication, group policy, trusts"
}

resource "aws_security_group_rule" "rpc_egress" {
  security_group_id        = aws_security_group.this.id
  type                     = "egress"
  from_port                = 1024
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = data.aws_directory_service_directory.this.security_group_id
  description              = "RPC; AD replication, user and computer authentication, group policy, trusts"
}

resource "aws_security_group_rule" "ldap_gc_egress" {
  security_group_id        = aws_security_group.this.id
  type                     = "egress"
  from_port                = 3268
  to_port                  = 3269
  protocol                 = "tcp"
  source_security_group_id = data.aws_directory_service_directory.this.security_group_id
  description              = "LDAP GC & LDAP GC SSL; AD directory, replication, user and computer authentication, group policy, trusts"
}

resource "aws_security_group_rule" "windows_time_egress" {
  security_group_id        = aws_security_group.this.id
  type                     = "egress"
  from_port                = 123
  to_port                  = 123
  protocol                 = "udp"
  source_security_group_id = data.aws_directory_service_directory.this.security_group_id
  description              = "Windows time; AD Windows time, trusts"
}

resource "aws_security_group_rule" "dfsn_egress" {
  security_group_id        = aws_security_group.this.id
  type                     = "egress"
  from_port                = 138
  to_port                  = 138
  protocol                 = "udp"
  source_security_group_id = data.aws_directory_service_directory.this.security_group_id
  description              = "DFSN & NetLogon; AD DFS, group policy"
}
