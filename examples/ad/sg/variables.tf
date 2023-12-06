variable "project_env" {
  description = "Project environment"
  type        = string
}

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "repo_path" {
  description = "Local path to the srds repo"
  type        = string
}

variable "vpc_name" {
  description = "Name of the VPC where project should be deployed. Subnets should be named vpc_name-subnet-(public or private) - if not, modify values in the data.tf file."
}
