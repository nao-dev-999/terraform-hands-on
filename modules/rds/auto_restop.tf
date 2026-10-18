# 停止中のRDSが7日経過でAWSにより自動起動された場合に、自動で停止し直す仕組み。
# instance_state = "stopped" の間だけ作成する。
#
# 流れ: RDS-EVENT-0154(停止期間の上限超過による起動)をEventBridgeで検知
#       → SSM Automationで「available になるのを待ってから StopDBInstance」を実行
#
# RDS-EVENT-0154 はAWSによる自動起動の時だけ発行され、terraform apply(sleep_mode = false)による
# 通常の起動では発行されないため、スリープ解除の妨げにはならない。
# 起動処理中(starting)は停止できないため、AWS管理のAWS-StopRdsInstanceではなく待機付きの独自ドキュメントを使う。

locals {
  auto_restop_enabled = var.instance_state == "stopped"
}

data "aws_caller_identity" "current" {}

resource "aws_ssm_document" "restop" {
  count = local.auto_restop_enabled ? 1 : 0

  name            = "${var.project}-${var.env}-rds-restop"
  document_type   = "Automation"
  document_format = "JSON"

  content = jsonencode({
    schemaVersion = "0.3"
    description   = "自動起動されたRDSインスタンスを、起動完了を待ってから停止する"
    assumeRole    = "{{ AutomationAssumeRole }}"
    parameters = {
      InstanceId           = { type = "String" }
      AutomationAssumeRole = { type = "String" }
    }
    mainSteps = [
      {
        name           = "WaitForAvailable"
        action         = "aws:waitForAwsResourceProperty"
        timeoutSeconds = 3600
        inputs = {
          Service              = "rds"
          Api                  = "DescribeDBInstances"
          DBInstanceIdentifier = "{{ InstanceId }}"
          PropertySelector     = "$.DBInstances[0].DBInstanceStatus"
          DesiredValues        = ["available"]
        }
      },
      {
        name   = "StopInstance"
        action = "aws:executeAwsApi"
        inputs = {
          Service              = "rds"
          Api                  = "StopDBInstance"
          DBInstanceIdentifier = "{{ InstanceId }}"
        }
      }
    ]
  })
}

# SSM Automationが実行時に引き受けるロール(RDSの参照・停止のみ)
resource "aws_iam_role" "restop_automation" {
  count = local.auto_restop_enabled ? 1 : 0

  name = "${var.project}-${var.env}-rds-restop-automation"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "ssm.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "restop_automation" {
  count = local.auto_restop_enabled ? 1 : 0

  name = "rds-stop"
  role = aws_iam_role.restop_automation[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["rds:DescribeDBInstances", "rds:StopDBInstance"]
        Resource = aws_db_instance.this.arn
      }
    ]
  })
}

# EventBridgeがSSM Automationを起動するためのロール
resource "aws_iam_role" "restop_events" {
  count = local.auto_restop_enabled ? 1 : 0

  name = "${var.project}-${var.env}-rds-restop-events"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "events.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "restop_events" {
  count = local.auto_restop_enabled ? 1 : 0

  name = "start-rds-restop-automation"
  role = aws_iam_role.restop_events[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "ssm:StartAutomationExecution"
        Resource = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:automation-definition/${aws_ssm_document.restop[0].name}:*"
      },
      {
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = aws_iam_role.restop_automation[0].arn
      }
    ]
  })
}

resource "aws_cloudwatch_event_rule" "restop" {
  count = local.auto_restop_enabled ? 1 : 0

  name        = "${var.project}-${var.env}-rds-auto-started"
  description = "停止中のRDSが7日経過で自動起動されたことを検知する(RDS-EVENT-0154)"

  event_pattern = jsonencode({
    source        = ["aws.rds"]
    "detail-type" = ["RDS DB Instance Event"]
    detail = {
      SourceArn = [aws_db_instance.this.arn]
      EventID   = ["RDS-EVENT-0154"]
    }
  })
}

resource "aws_cloudwatch_event_target" "restop" {
  count = local.auto_restop_enabled ? 1 : 0

  rule     = aws_cloudwatch_event_rule.restop[0].name
  arn      = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:automation-definition/${aws_ssm_document.restop[0].name}:$DEFAULT"
  role_arn = aws_iam_role.restop_events[0].arn

  input = jsonencode({
    InstanceId           = [aws_db_instance.this.identifier]
    AutomationAssumeRole = [aws_iam_role.restop_automation[0].arn]
  })
}
