variable "project" {
  type = string
}

variable "env" {
  type = string
}

variable "alb_arn" {
  type = string
}

variable "general_rate_limit" {
  type    = number
  default = 2000
}

variable "auth_rate_limit" {
  type    = number
  default = 300
}

variable "waf_log_retention_days" {
  type    = number
  default = 30
}

variable "managed_rules_count_mode" {
  type    = bool
  default = false
}
