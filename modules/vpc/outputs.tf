output "vpc_id" {
  value = aws_vpc.this.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "public_route_table_id" {
  value = aws_route_table.public.id
}

output "vpc_flow_log_bucket_name" {
  value       = aws_s3_bucket.vpc_flow_logs.id
  description = "VPCフローログを保存するS3バケット名（将来Athenaでの分析等に使用）"
}

output "vpc_flow_log_bucket_arn" {
  value       = aws_s3_bucket.vpc_flow_logs.arn
  description = "VPCフローログを保存するS3バケットのARN"
}
