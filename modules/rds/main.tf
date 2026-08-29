resource "aws_db_instance" "this" {
  identifier                  = var.identifier
  engine                      = var.engine
  engine_version              = var.engine_version
  instance_class              = var.instance_class
  allocated_storage           = 20
  max_allocated_storage       = var.max_allocated_storage
  storage_type                = "gp3"
  db_name                     = var.database_name
  username                    = var.master_username
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  port                   = 5432

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  multi_az = var.multi_az # 検証環境: false / 本番環境: true

  backup_retention_period = var.backup_retention_period # 例: 7（7日分保持）
  backup_window           = "17:00-17:30"               # UTC。JSTでは深夜2:00-2:30
  copy_tags_to_snapshot   = true

  skip_final_snapshot       = var.skip_final_snapshot # 検証: true / 本番: false
  final_snapshot_identifier = "${var.identifier}-final-snapshot"
  deletion_protection       = var.deletion_protection # 検証: false / 本番: true

  performance_insights_enabled          = true
  performance_insights_retention_period = 7 # 無料枠は7日

  parameter_group_name = aws_db_parameter_group.this.name

  maintenance_window         = "sun:18:00-sun:19:00" # UTC。JSTでは月曜3:00-4:00
  auto_minor_version_upgrade = false

  tags = {
    Name = "${var.project}-${var.env}-rds"
  }

  lifecycle {
    ignore_changes = [
      engine_version, # auto_minor_version_upgradeによる自動更新の差分を無視
      password,       # Secrets Managerのローテーションによる差分を無視
    ]
  }
}

resource "aws_db_subnet_group" "this" {
  name        = "${var.project}-${var.env}-rds-subnet-group"
  subnet_ids  = var.subnet_ids
  description = "RDS subnet group for ${var.project} ${var.env}"

  tags = {
    Name = "${var.project}-${var.env}-rds-subnet-group"
  }
}

resource "aws_security_group" "rds" {
  name        = "${var.project}-${var.env}-rds-sg"
  description = "Security group for rds"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.ecs_sg_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = []
    # 必要な場合のみ、拡張機能の取得先などを個別に許可する
  }

  tags = {
    Name = "${var.project}-${var.env}-rds-sg"
  }
}

resource "aws_serverlessapplicationrepository_cloudformation_stack" "rds_rotation" {
  name             = "${var.project}-${var.env}-rds-rotation"
  application_id   = "arn:aws:serverlessrepo:us-east-1:297356227824:applications/SecretsManagerRDSPostgreSQLRotationSingleUser"
  semantic_version = "1.1.60"
  capabilities     = ["CAPABILITY_IAM", "CAPABILITY_RESOURCE_POLICY"]

  parameters = {
    endpoint            = "https://secretsmanager.${var.aws_region}.amazonaws.com"
    functionName        = "${var.project}-${var.env}-rds-rotation"
    vpcSecurityGroupIds = aws_security_group.rds.id
    vpcSubnetIds        = join(",", var.subnet_ids)
  }
}

resource "aws_secretsmanager_secret_rotation" "rds_master" {
  secret_id           = aws_db_instance.this.master_user_secret[0].secret_arn
  rotation_lambda_arn = aws_serverlessapplicationrepository_cloudformation_stack.rds_rotation.outputs["RotationLambdaARN"]

  rotation_rules {
    automatically_after_days = 90
  }
}

resource "aws_db_parameter_group" "this" {
  name   = "${var.project}-${var.env}-pg-params"
  family = "postgres16" # engineのメジャーバージョンに合わせて指定する

  # スロークエリログ: 指定ミリ秒以上かかったクエリを記録する
  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }

  # 監査ログ: pgaudit拡張をプリロードする(static。再起動が必要)
  parameter {
    name         = "shared_preload_libraries"
    value        = "pgaudit"
    apply_method = "pending-reboot"
  }

  # 監査対象: DDL(スキーマ変更)とWRITE(更新系)を記録する
  parameter {
    name  = "pgaudit.log"
    value = "ddl,write"
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  alarm_name          = "${var.project}-${var.env}-rds-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "RDS CPU使用率が80%を3回連続で超過"
  dimensions = {
    DBInstanceIdentifier = aws_db_instance.this.id
  }
  alarm_actions = [var.alarm_sns_topic_arn]
}

resource "aws_cloudwatch_metric_alarm" "rds_free_storage" {
  alarm_name          = "${var.project}-${var.env}-rds-storage-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 2147483648 # 2GiB
  alarm_description   = "RDS空きストレージが2GiBを下回った"
  dimensions = {
    DBInstanceIdentifier = aws_db_instance.this.id
  }
  alarm_actions = [var.alarm_sns_topic_arn]
}

resource "aws_cloudwatch_metric_alarm" "rds_connections" {
  alarm_name          = "${var.project}-${var.env}-rds-connections-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = var.max_connections_threshold
  alarm_description   = "RDS接続数が閾値を超過。コネクションリークやスケールアウトの過多を疑う"
  dimensions = {
    DBInstanceIdentifier = aws_db_instance.this.id
  }
  alarm_actions = [var.alarm_sns_topic_arn]
}

resource "aws_db_event_subscription" "this" {
  name        = "${var.project}-${var.env}-rds-events"
  sns_topic   = var.alarm_sns_topic_arn
  source_type = "db-instance"
  source_ids  = [aws_db_instance.this.id]

  event_categories = [
    "failover",
    "failure",
    "low storage",
    "maintenance",
    "notification",
  ]
}

resource "aws_budgets_budget" "monthly_cost" {
  name         = "${var.project}-${var.env}-monthly-cost"
  budget_type  = "COST"
  limit_amount = var.monthly_limit_usd
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  # メールアドレス未設定の場合は予算のみ作成し、通知は行わない
  # (通知ブロックは購読者0件だとAPIエラーになるため)
  dynamic "notification" {
    for_each = length(var.notification_emails) > 0 ? [80, 100] : []
    content {
      comparison_operator        = "GREATER_THAN"
      threshold                  = notification.value
      threshold_type             = "PERCENTAGE"
      notification_type          = notification.value < 100 ? "ACTUAL" : "FORECASTED"
      subscriber_email_addresses = var.notification_emails
    }
  }
}
