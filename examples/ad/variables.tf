variable "key_name" {
  description = "Name of the EC2 key pair to associate with the servers"
  type        = string
}

variable "no_proxy_extra" {
  description = "List of additonial endpoints in the VPC to include in no_proxy settings. For AWS PrivateLink endpoints, use the regional version, e.g. dkr.ecr.use-east-1.amazonaws.com."
  type        = string
  default     = ""
}

variable "project_env" {
  description = "Project environment"
  type        = string
}

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "proxy_url" {
  description = "URL of a http proxy, if applicable"
  type        = string
  default     = ""
}

variable "repo_path" {
  description = "Local path to the srds repo"
  type        = string
}

variable "vpc_name" {
  description = "Name of the VPC where project should be deployed. Subnets should be named vpc_name-subnet-(public or private) - if not, modify values in the data.tf file."
}
