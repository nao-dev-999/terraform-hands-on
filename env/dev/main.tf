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