variable "project" {
  type = string
}

variable "env" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "github_repository" {
  type = string
}

variable "github_branch" {
  type    = string
  default = "main"
}

variable "app_repository_url" {
  type = string
}

variable "flyway_repository_url" {
  type = string
}

variable "batch_repository_url" {
  type = string
}

variable "ecs_cluster_name" {
  type = string
}

variable "ecs_service_name" {
  type = string
}

variable "task_execution_role_arn" {
  type = string
}

variable "task_role_arn" {
  type = string
}

variable "flyway_task_definition_family" {
  type = string
}

variable "flyway_subnet_id" {
  type = string
}

variable "flyway_sg_id" {
  type = string
}

variable "batch_task_definition_family" {
  type = string
}
