variable "project" {
  type = string
}

variable "env" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "notification_emails" {
  type    = list(string)
  default = []
}

variable "app_log_group_name" {
  type = string
}

variable "ecs_cluster_name" {
  type = string
}

variable "ecs_service_name" {
  type = string
}

variable "alb_arn_suffix" {
  type = string
}

variable "alb_target_group_arn_suffix" {
  type = string
}

variable "alb_elb_5xx_threshold" {
  type    = number
  default = 5
}

variable "alb_target_response_time_threshold" {
  type    = number
  default = 3
}

variable "alb_rejected_connections_threshold" {
  type    = number
  default = 1
}

variable "rds_instance_id" {
  type = string
}

variable "rds_database_connections_threshold" {
  type    = number
  default = 80
}

variable "redis_cluster_id" {
  type = string
}

variable "waf_web_acl_metric_name" {
  type = string
}

variable "waf_auth_rate_limit_metric_name" {
  type = string
}

variable "waf_blocked_requests_threshold" {
  type    = number
  default = 100
}

variable "waf_auth_rate_limit_threshold" {
  type    = number
  default = 1
}
