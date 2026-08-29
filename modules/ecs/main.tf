resource "aws_ecs_cluster" "this" {
  name = "${var.project}-${var.env}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name       = aws_ecs_cluster.this.name
  capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
  }
}

resource "aws_iam_role" "task_execution" {
  name = "${var.project}-${var.env}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "ecs-tasks.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "task_execution_managed" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "task_execution_secrets" {
  name = "${var.project}-${var.env}-ecs-task-execution-secrets"
  role = aws_iam_role.task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "secretsmanager:GetSecretValue"
        Resource = var.db_password_secret_arn
      }
    ]
  })
}

resource "aws_iam_role" "task" {
  name = "${var.project}-${var.env}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "ecs-tasks.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "task_ssm_exec" {
  name = "${var.project}-${var.env}-ecs-task-ssm-exec"
  role = aws_iam_role.task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.project}-${var.env}-app"
  retention_in_days = 14
}

resource "aws_ecs_task_definition" "app" {
  family                   = "${var.project}-${var.env}-app"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name        = "app"
      image       = "${var.app_image_url}:${var.app_image_tag}"
      essential   = true
      stopTimeout = 30

      portMappings = [{ containerPort = 8080, protocol = "tcp" }]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.app.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "app"
        }
      }

      secrets = [
        {
          name      = "SPRING_DATASOURCE_USERNAME"
          valueFrom = "${var.db_password_secret_arn}:username::"
        },
        {
          name      = "SPRING_DATASOURCE_PASSWORD"
          valueFrom = "${var.db_password_secret_arn}:password::"
        }
      ]

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:8080/actuator/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])
}

resource "aws_ecs_task_definition" "flyway" {
  family = "${var.project}-${var.env}-flyway"
  cpu    = "512"
  memory = "1024"

  container_definitions = jsonencode([
    {
      name  = "flyway"
      image = "${var.flyway_image_url}:${var.flyway_image_tag}"

      readonlyRootFilesystem = true
      mountPoints = [
        { sourceVolume = "tmp", containerPath = "/tmp", readOnly = false }
      ]

      command = ["migrate"]
    }
  ])

  volume {
    name = "tmp"
  }
}

resource "aws_ecs_service" "app" {
  name            = "${var.project}-${var.env}-app-service"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  health_check_grace_period_seconds = 120
  availability_zone_rebalancing     = "ENABLED"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = "app"
    container_port   = 8080
  }

  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }
}

resource "aws_security_group" "ecs" {
  name   = "${var.project}-${var.env}-ecs-sg"
  vpc_id = var.vpc_id

  ingress {
    description     = "Allow from ALB"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [var.alb_sg_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "redis" {
  name   = "${var.project}-${var.env}-redis-sg"
  vpc_id = var.vpc_id

  ingress {
    description     = "Allow from ECS tasks"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }
}

resource "aws_elasticache_subnet_group" "redis" {
  name       = "${var.project}-${var.env}-redis-subnet-group"
  subnet_ids = var.private_subnet_ids
}

resource "aws_elasticache_cluster" "redis" {
  cluster_id         = "${var.project}-${var.env}-redis"
  engine             = "redis"
  engine_version     = "7.1"
  node_type          = "cache.t4g.micro"
  num_cache_nodes    = 1
  port               = 6379
  subnet_group_name  = aws_elasticache_subnet_group.redis.name
  security_group_ids = [aws_security_group.redis.id]

  tags = {
    Name = "${var.project}-${var.env}-redis"
  }
}

resource "aws_appautoscaling_target" "ecs" {
  max_capacity       = var.max_capacity
  min_capacity       = var.min_capacity
  resource_id        = "service/${aws_ecs_cluster.this.name}/${aws_ecs_service.app.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "cpu" {
  name               = "${var.project}-${var.env}-ecs-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 70.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

resource "aws_ecs_task_definition" "batch" {
  family                   = "${var.project}-${var.env}-batch"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name      = "batch"
      image     = "${var.app_image_url}:${var.app_image_tag}"
      essential = true
    }
  ])
}

resource "aws_iam_role" "sfn_batch_orchestrator" {
  name = "${var.project}-${var.env}-sfn-batch-orchestrator-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "states.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "sfn_batch_orchestrator_run_task" {
  name = "${var.project}-${var.env}-sfn-run-task"
  role = aws_iam_role.sfn_batch_orchestrator.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ecs:RunTask", "ecs:StopTask", "ecs:DescribeTasks"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = [aws_iam_role.task_execution.arn, aws_iam_role.task.arn]
      },
      {
        Effect   = "Allow"
        Action   = ["events:PutTargets", "events:PutRule", "events:DescribeRule"]
        Resource = "*"
      }
    ]
  })
}

locals {
  batch_run_task_retry = [
    {
      ErrorEquals     = ["ECS.AmazonECSException", "States.Timeout"]
      IntervalSeconds = 10
      MaxAttempts     = 2
      BackoffRate     = 2.0
    }
  ]

  batch_network_configuration = {
    AwsvpcConfiguration = {
      Subnets        = var.private_subnet_ids
      SecurityGroups = [aws_security_group.ecs.id]
      AssignPublicIp = "DISABLED"
    }
  }

  batch_run_task_parameters = {
    LaunchType           = "FARGATE"
    Cluster              = aws_ecs_cluster.this.arn
    TaskDefinition       = aws_ecs_task_definition.batch.arn
    NetworkConfiguration = local.batch_network_configuration
  }
}

resource "aws_sfn_state_machine" "batch_orchestrator" {
  name     = "${var.project}-${var.env}-batch-orchestrator"
  role_arn = aws_iam_role.sfn_batch_orchestrator.arn
  type     = "STANDARD"

  definition = jsonencode({
    StartAt        = "PaymentIntakeJob"
    TimeoutSeconds = 10800
    States = {
      PaymentIntakeJob = {
        Type     = "Task"
        Resource = "arn:aws:states:::ecs:runTask.sync"
        Parameters = merge(local.batch_run_task_parameters, {
          Overrides = {
            ContainerOverrides = [
              {
                Name    = "batch"
                Command = ["payment-intake"]
              }
            ]
          }
        })
        Retry = local.batch_run_task_retry
        Next  = "SalesAggregationJob"
      }
      SalesAggregationJob = {
        Type     = "Task"
        Resource = "arn:aws:states:::ecs:runTask.sync"
        Parameters = merge(local.batch_run_task_parameters, {
          Overrides = {
            ContainerOverrides = [
              {
                Name    = "batch"
                Command = ["sales-aggregation"]
              }
            ]
          }
        })
        Retry = local.batch_run_task_retry
        Next  = "SettlementExportJob"
      }
      SettlementExportJob = {
        Type     = "Task"
        Resource = "arn:aws:states:::ecs:runTask.sync"
        Parameters = merge(local.batch_run_task_parameters, {
          Overrides = {
            ContainerOverrides = [
              {
                Name    = "batch"
                Command = ["settlement-export"]
              }
            ]
          }
        })
        Retry = local.batch_run_task_retry
        End   = true
      }
    }
  })
}

resource "aws_iam_role" "batch_scheduler" {
  name = "${var.project}-${var.env}-batch-scheduler-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "scheduler.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "batch_scheduler_start_execution" {
  name = "${var.project}-${var.env}-batch-scheduler-start-execution"
  role = aws_iam_role.batch_scheduler.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "states:StartExecution"
        Resource = aws_sfn_state_machine.batch_orchestrator.arn
      }
    ]
  })
}

resource "aws_scheduler_schedule" "batch_daily" {
  name       = "${var.project}-${var.env}-batch-daily"
  group_name = "default"

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression          = var.batch_schedule_expression
  schedule_expression_timezone = "UTC"

  target {
    arn      = aws_sfn_state_machine.batch_orchestrator.arn
    role_arn = aws_iam_role.batch_scheduler.arn
  }
}

resource "aws_ecs_task_definition" "db_debug" {
  family                   = "${var.project}-${var.env}-db-debug"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name      = "db-debug"
      image     = "public.ecr.aws/docker/library/postgres:16-alpine"
      essential = true
      command   = ["sleep", "infinity"]
      linuxParameters = {
        initProcessEnabled = true
      }
    }
  ])
}
