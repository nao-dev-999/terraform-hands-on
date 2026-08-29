variable "project" {type = string}
variable "env" {type = string}
variable "aws_region" {type = string}

# VPC
variable "vpc_cidr" {type = string}
variable "public_subnet_cidrs" { type = list(string) }
variable "private_subnet_cidrs" { type = list(string) }
variable "availability_zones" { type = list(string) }
variable "nat_gateway_count" { type = number }

# ECS
variable "app_image_url" {
  type = string
}

variable "app_image_tag" {
  type = string
}

variable "flyway_image_url" {
  type = string
}

variable "flyway_image_tag" {
  type = string
}

variable "desired_count" {
  type    = number
  default = 1
}

variable "min_capacity" {
  type    = number
  default = 1
}

variable "max_capacity" {
  type    = number
  default = 4
}

variable "batch_schedule_expression" {
  type    = string
  default = "cron(0 17 * * ? *)"
}
