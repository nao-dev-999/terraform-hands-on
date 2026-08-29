variable "project" { type = string }
variable "env" { type = string }
variable "aws_region" { type = string }

# VPC
variable "vpc_cidr" { type = string }
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

# ALB
variable "alb_enable_deletion_protection" {
  type        = bool
  default     = false
  description = "ALBの削除保護。devでは頻繁に作り直すためfalse、本番環境ではtrueにすること。"
}

# RDS
variable "rds_identifier" {
  type = string
}

variable "rds_database_name" {
  type = string
}

variable "rds_instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "rds_engine_version" {
  type    = string
  default = "16"
}

variable "rds_multi_az" {
  type    = bool
  default = false
}

variable "rds_backup_retention_period" {
  type    = number
  default = 7
}

variable "rds_skip_final_snapshot" {
  type    = bool
  default = true
}

variable "rds_deletion_protection" {
  type    = bool
  default = false
}

variable "rds_max_connections_threshold" {
  type    = number
  default = 80
}

variable "monthly_limit_usd" {
  type    = number
  default = 50
}

variable "notification_emails" {
  type    = list(string)
  default = []
}

# CI/CD
variable "github_repository" {
  type = string
}

variable "github_branch" {
  type    = string
  default = "main"
}
