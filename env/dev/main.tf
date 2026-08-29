# VPC Module
module "vpc" {
  source = "../../modules/vpc"

  project              = var.project
  env                  = var.env
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
  nat_gateway_count    = var.nat_gateway_count
}

# ECS Module
module "ecs" {
  source = "../../modules/ecs"

  project = var.project
  env     = var.env

  aws_region = var.aws_region

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  alb_sg_id          = module.alb.alb_sg_id
  target_group_arn   = module.alb.target_group_arn

  app_image_url    = var.app_image_url
  app_image_tag    = var.app_image_tag
  flyway_image_url = var.flyway_image_url
  flyway_image_tag = var.flyway_image_tag

  db_password_secret_arn = module.rds.rds_secret_arn

  desired_count = var.desired_count
  min_capacity  = var.min_capacity
  max_capacity  = var.max_capacity

  batch_schedule_expression = var.batch_schedule_expression
}

# RDS Module
module "rds" {
  source = "../../modules/rds"

  project    = var.project
  env        = var.env
  aws_region = var.aws_region

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
  ecs_sg_id  = module.ecs.ecs_sg_id

  identifier     = var.rds_identifier
  database_name  = var.rds_database_name
  instance_class = var.rds_instance_class
  engine_version = var.rds_engine_version

  multi_az                = var.rds_multi_az
  backup_retention_period = var.rds_backup_retention_period
  skip_final_snapshot     = var.rds_skip_final_snapshot
  deletion_protection     = var.rds_deletion_protection

  max_connections_threshold = var.rds_max_connections_threshold
  alarm_sns_topic_arn       = module.alarms.sns_topic_arn

  monthly_limit_usd   = var.monthly_limit_usd
  notification_emails = var.notification_emails
}

# ALB Module
module "alb" {
  source = "../../modules/alb"

  project           = var.project
  env               = var.env
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  target_port       = 8080
  health_check_path = "/actuator/health"

  enable_deletion_protection = false # devでは頻繁に作り直すためfalse。本番環境ではtrueにすること

  alarm_sns_topic_arns = [module.alarms.sns_topic_arn]
}

# モジュール間の循環参照を避けるため、このルールはenv層で両モジュールのSG IDを参照する形で定義する。
# aws_security_group.alb はインラインルールを一切持たない(modules/alb/main.tf参照)ため、
# この別リソースとの混在によるルール競合・永続的diffは発生しない。
resource "aws_vpc_security_group_egress_rule" "alb_egress_to_ecs" {
  security_group_id            = module.alb.alb_sg_id
  description                  = "Allow to ECS Fargate tasks (app port)"
  from_port                    = 8080
  to_port                      = 8080
  ip_protocol                  = "tcp"
  referenced_security_group_id = module.ecs.ecs_sg_id
}

# Alarms Module
module "alarms" {
  source = "../../modules/alarms"

  project    = var.project
  env        = var.env
  aws_region = var.aws_region

  notification_emails = var.notification_emails

  app_log_group_name = module.ecs.app_log_group_name
  ecs_cluster_name   = module.ecs.cluster_name
  ecs_service_name   = module.ecs.service_name

  alb_arn_suffix              = module.alb.alb_arn_suffix
  alb_target_group_arn_suffix = module.alb.target_group_arn_suffix

  rds_instance_id  = module.rds.rds_instance_id
  redis_cluster_id = module.ecs.redis_cluster_id

  waf_web_acl_metric_name         = module.waf.web_acl_metric_name
  waf_auth_rate_limit_metric_name = module.waf.auth_rate_limit_metric_name
}