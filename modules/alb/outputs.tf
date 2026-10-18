# enable_alb = false の間、ALB本体に紐づく値はnullになる

output "alb_dns_name" {
  value = one(aws_lb.this[*].dns_name)
}

output "alb_arn" {
  value = one(aws_lb.this[*].arn)
}

output "target_group_arn" {
  value = aws_lb_target_group.this.arn

  # ECSはALBに紐づいていないターゲットグループへタスクを登録できないため、
  # このターゲットグループを使うリソース(ECSサービスのスケール等)はリスナー作成後に処理させる。
  depends_on = [aws_lb_listener.http, aws_lb_listener.https]
}

output "alb_sg_id" {
  value = aws_security_group.alb.id
}

output "alb_arn_suffix" {
  description = "CloudWatchメトリクスのLoadBalancerディメンションに使うarn_suffix"
  value       = one(aws_lb.this[*].arn_suffix)
}

output "target_group_arn_suffix" {
  description = "CloudWatchメトリクスのTargetGroupディメンションに使うarn_suffix"
  value       = aws_lb_target_group.this.arn_suffix
}
