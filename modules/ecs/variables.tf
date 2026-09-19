variable "project" {
  type = string
}

variable "env" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "alb_sg_id" {
  type = string
}

variable "target_group_arn" {
  type = string
}

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

variable "db_password_secret_arn" {
  type = string
}

variable "db_endpoint" {
  type = string
}

variable "db_port" {
  type = number
}

variable "db_name" {
  type = string
}

variable "task_cpu" {
  type    = string
  default = "512"
}

variable "task_memory" {
  type    = string
  default = "1024"
}

variable "batch_cpu" {
  type    = string
  default = "512"
}

variable "batch_memory" {
  type    = string
  default = "1024"
}

variable "health_check_grace_period_seconds" {
  type    = number
  default = 120
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

variable "redis_node_type" {
  type    = string
  default = "cache.t4g.micro"
}

variable "redis_num_cache_clusters" {
  type    = number
  default = 1
}

variable "redis_notification_topic_arn" {
  type    = string
  default = null
}
