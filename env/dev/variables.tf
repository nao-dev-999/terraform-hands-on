variable "project" {type = string}
variable "env" {type = string}

# VPC
variable "vpc_cidr" {type = string}
variable "public_subnet_cidrs" { type = list(string) }
variable "private_subnet_cidrs" { type = list(string) }
variable "availability_zones" { type = list(string) }
variable "nat_gateway_count" { type = number }
