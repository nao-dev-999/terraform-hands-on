variable "project" {
  type = string
}

variable "env" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "public_subnet_cidrs" {
  type = list(string)
}

variable "private_subnet_cidrs" {
  type = list(string)
}

variable "availability_zones" {
  type = list(string)
}

variable "nat_gateway_count" {
  type        = number
  description = "NAT Gatewayの数。1（全AZ共有）または length(var.availability_zones)（AZごとに1台）を指定する"

  validation {
    condition     = var.nat_gateway_count == 1 || var.nat_gateway_count == length(var.availability_zones)
    error_message = "nat_gateway_count は 1 か、availability_zones の数と一致させてください。中間の値はAZ対応が崩れます。"
  }
}

variable "vpc_flow_log_retention_days" {
  type    = number
  default = 180
}
