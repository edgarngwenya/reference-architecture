variable "environment_name" {
  type = string
}

variable "application_name" {
  type = string
}

variable "build_id" {
  type = string
}

variable "region" {
  type = string
}

variable "cidr_block" {
  type = string
}

variable "public_subnet_cidr_blocks" {
  type = list(string)
}

variable "private_subnet_cidr_blocks" {
  type = list(string)
}

variable "availability_zones" {
  type = list(string)
}
variable "certificate_arn" {
  type = string
}

variable "host_zone_id" {
  type = string
}

variable "docker_port_number" {
  type = number
  default = 3000
}

data "aws_caller_identity" "current" {}
