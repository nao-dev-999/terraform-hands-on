output "web_acl_arn" {
  value = aws_wafv2_web_acl.this.arn
}

output "web_acl_id" {
  value = aws_wafv2_web_acl.this.id
}

output "waf_log_bucket_name" {
  value       = aws_s3_bucket.waf_logs.id
  description = "WAFログを保存するS3バケット名(将来Athenaでの分析等に使用)"
}

output "waf_log_bucket_arn" {
  value       = aws_s3_bucket.waf_logs.arn
  description = "WAFログを保存するS3バケットのARN"
}

output "web_acl_metric_name" {
  value       = aws_wafv2_web_acl.this.visibility_config[0].metric_name
  description = "WebACL全体のCloudWatchメトリクス名(AWS/WAFV2名前空間のWebACLディメンションに使用)"
}

output "auth_rate_limit_metric_name" {
  value       = "${var.project}-${var.env}-auth-rate-limit"
  description = "auth-rate-limitルールのCloudWatchメトリクス名(AWS/WAFV2名前空間のRuleディメンションに使用)"
}

output "general_rate_limit_metric_name" {
  value       = "${var.project}-${var.env}-general-rate-limit"
  description = "general-rate-limitルールのCloudWatchメトリクス名(AWS/WAFV2名前空間のRuleディメンションに使用)"
}
