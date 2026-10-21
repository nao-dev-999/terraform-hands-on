variable "project" {
  type = string
}

variable "env" {
  type = string
}

variable "enabled" {
  type        = bool
  default     = true
  description = "falseにするとWebACLを削除する(検証環境のスリープ用)。ALBを削除する場合はfalseにすること"
}

variable "alb_arn" {
  type        = string
  description = "WebACLを関連付けるALBのARN。enabled = false の場合はnullでよい"
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
