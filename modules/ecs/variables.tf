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

variable "task_cpu" {
  type    = string
  default = "512"
}

variable "task_memory" {
  type    = string
  default = "1024"
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
