output "ecs_sg_id" {
  value = aws_security_group.ecs.id
}

output "app_log_group_name" {
  value = aws_cloudwatch_log_group.app.name
}

output "redis_cluster_ids" {
  # レプリケーショングループを構成する全ノードのIDを公開しています。
  # AWS/ElastiCacheの標準メトリクス（EngineCPUUtilization等）はノード単位（CacheClusterId）でしか
  # 発行されず、レプリケーショングループ全体やプライマリ/レプリカの役割を表すディメンションは存在しないため、
  # 先頭ノードだけでなく全ノードをfor_eachで監視できるよう、リストとして公開しています。
  value = aws_elasticache_replication_group.redis.member_clusters
}

output "cluster_name" {
  value = aws_ecs_cluster.this.name
}

output "service_name" {
  value = aws_ecs_service.app.name
}

output "task_execution_role_arn" {
  value = aws_iam_role.task_execution.arn
}

output "task_role_arn" {
  value = aws_iam_role.task.arn
}

output "flyway_task_definition_family" {
  value = aws_ecs_task_definition.flyway.family
}

output "batch_task_definition_family" {
  value = aws_ecs_task_definition.batch.family
}

output "redis_host" {
  value = aws_elasticache_replication_group.redis.primary_endpoint_address
}
