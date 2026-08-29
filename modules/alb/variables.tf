variable "project" {
  type = string
}

variable "env" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "target_port" {
  type    = number
  default = 8080
}

variable "health_check_path" {
  type    = string
  default = "/actuator/health"
}

variable "deregistration_delay" {
  type    = number
  default = 30
}

variable "idle_timeout" {
  type    = number
  default = 60
}

variable "enable_waf_fail_open" {
  type    = bool
  default = false
}

variable "enable_deletion_protection" {
  type    = bool
  default = false
}

variable "maintenance_mode_enabled" {
  type    = bool
  default = false
}

variable "access_log_expiration_days" {
  type    = number
  default = 365
}

variable "alarm_sns_topic_arns" {
  type    = list(string)
  default = []
}
