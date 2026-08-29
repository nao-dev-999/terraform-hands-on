# ここでの制限は全体を守るための粗いしきい値。エンドポイント単位・ユーザー単位の
# 細かい制限はアプリ側のRateLimitingFilter（Bucket4j+Redis）が担当する。

resource "aws_s3_bucket" "waf_logs" {
  bucket = "aws-waf-logs-${var.project}-${var.env}"

  tags = {
    Name = "aws-waf-logs-${var.project}-${var.env}"
  }
}

resource "aws_s3_bucket_public_access_block" "waf_logs" {
  bucket = aws_s3_bucket.waf_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "waf_logs" {
  bucket = aws_s3_bucket.waf_logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "waf_logs" {
  bucket = aws_s3_bucket.waf_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "waf_logs" {
  bucket = aws_s3_bucket.waf_logs.id

  rule {
    id     = "expire-waf-logs"
    status = "Enabled"

    filter {}

    expiration {
      days = var.waf_log_retention_days
    }

    # versioning有効化に伴い、旧バージョンも同様に整理する
    noncurrent_version_expiration {
      noncurrent_days = var.waf_log_retention_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_wafv2_web_acl" "this" {
  name        = "${var.project}-${var.env}-waf"
  description = "Rate limiting and managed rules for ${var.project}-${var.env} ALB"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "aws-managed-common-rule-set"
    priority = 1

    override_action {
      dynamic "count" {
        for_each = var.managed_rules_count_mode ? [1] : []
        content {}
      }
      dynamic "none" {
        for_each = var.managed_rules_count_mode ? [] : [1]
        content {}
      }
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"

        # POSTボディの大きいJSON(注文作成等)を誤って弾かないよう、サイズ制限ルールのみ
        # カウントモードで運用し、WAFログ/CloudWatchで実際の影響を監視してから判断する。
        rule_action_override {
          name = "SizeRestrictions_BODY"
          action_to_use {
            count {}
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project}-${var.env}-common-rule-set"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "aws-managed-known-bad-inputs"
    priority = 2

    override_action {
      dynamic "count" {
        for_each = var.managed_rules_count_mode ? [1] : []
        content {}
      }
      dynamic "none" {
        for_each = var.managed_rules_count_mode ? [] : [1]
        content {}
      }
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project}-${var.env}-known-bad-inputs"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "aws-managed-sqli-rule-set"
    priority = 3

    override_action {
      dynamic "count" {
        for_each = var.managed_rules_count_mode ? [1] : []
        content {}
      }
      dynamic "none" {
        for_each = var.managed_rules_count_mode ? [] : [1]
        content {}
      }
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project}-${var.env}-sqli-rule-set"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "aws-managed-ip-reputation"
    priority = 4

    override_action {
      dynamic "count" {
        for_each = var.managed_rules_count_mode ? [1] : []
        content {}
      }
      dynamic "none" {
        for_each = var.managed_rules_count_mode ? [] : [1]
        content {}
      }
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project}-${var.env}-ip-reputation"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "auth-rate-limit"
    priority = 5

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.auth_rate_limit
        aggregate_key_type = "IP"

        scope_down_statement {
          or_statement {
            statement {
              byte_match_statement {
                search_string         = "/auth/login"
                positional_constraint = "CONTAINS"
                field_to_match {
                  uri_path {}
                }
                text_transformation {
                  priority = 0
                  type     = "NONE"
                }
              }
            }
            statement {
              byte_match_statement {
                search_string         = "/auth/signup"
                positional_constraint = "CONTAINS"
                field_to_match {
                  uri_path {}
                }
                text_transformation {
                  priority = 0
                  type     = "NONE"
                }
              }
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project}-${var.env}-auth-rate-limit"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "general-rate-limit"
    priority = 6

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.general_rate_limit
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project}-${var.env}-general-rate-limit"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project}-${var.env}-waf"
    sampled_requests_enabled   = true
  }

  tags = {
    Name = "${var.project}-${var.env}-waf"
  }
}

resource "aws_wafv2_web_acl_association" "alb" {
  resource_arn = var.alb_arn
  web_acl_arn  = aws_wafv2_web_acl.this.arn
}

resource "aws_wafv2_web_acl_logging_configuration" "this" {
  resource_arn            = aws_wafv2_web_acl.this.arn
  log_destination_configs = [aws_s3_bucket.waf_logs.arn]

  # JWT認証のAuthorizationヘッダー、およびRedisセッションのCookieヘッダーは
  # 機密情報を含むため、ログから除外する。
  redacted_fields {
    single_header {
      name = "authorization"
    }
  }

  redacted_fields {
    single_header {
      name = "cookie"
    }
  }
}
