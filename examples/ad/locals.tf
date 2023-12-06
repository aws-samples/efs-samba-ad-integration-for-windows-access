locals {

  project = {
    azs = slice(data.aws_availability_zones.available.names, 0, length(data.aws_subnets.private.ids))
    tags = {
      Application = var.project_name
      ProjectEnv  = var.project_env
    }
  }

  downloads = {
    amazon_efs_utils = {
      aws     = "https://github.com/aws/efs-utils"
      aws-iso = "https://s3.us-iso-east-1.c2s.ic.gov/s3-efs-utils-mvp-prod-us-iso-east-1/linux/efs-utils.tar.gz"
    }
  }

  samba_config = {
    enable_ha                   = false
    workgroup                   = "CORP"
    realm                       = "CORP.EXAMPLE.COM"
    efs_share_name              = "shared"
    samba_secret_parameter_path = "/${var.project_name}/${var.project_env}/samba"
    ad_secret_parameter_path    = "/${var.project_name}/${var.project_env}/ad"
    users                       = ["user1", "user2"]
    group                       = "workspaces"
  }

  samba_server = {
    user_data_opts = {
      path                  = "${var.repo_path}/scripts/user-data.tftpl"
      write_rendered_output = true
    }
    user_data_vars = {
      enable_log                    = true # Set to true and a log of the user data for development and troubleshooting will be created in /var/log/user-data.log. Set to false for operations otherwise secrets for configuring the Samba server may be exposed; the standard user data log can be found in /var/log/cloud-init-output.log.
      efs_file_system_id            = module.efs.id
      efs_mount_point               = "/"
      ec2_mount_dir                 = "/mnt/efs"
      samba_config                  = local.samba_config
      region                        = data.aws_region.current.name
      ami_os                        = "al2"
      proxy_url                     = var.proxy_url
      no_proxy_extra                = var.no_proxy_extra
      amazon_efs_utils_download_url = lookup(local.downloads.amazon_efs_utils, data.aws_partition.current.partition)
      key_name                      = var.key_name
    }
  }

}
