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
  #
  # aws_elasticache_replication_group.redis.member_clusters はapply後にしか確定しない値のため、
  # これをそのままalarmsモジュール側のfor_eachに渡すと、新規作成時のplanが
  # "Invalid for_each argument" エラーで失敗する。AWSはnum_cache_clustersで
  # ノードを作成する際、replication_group_idに3桁の連番("-001"、"-002"...)を
  # 付与したIDを自動採番する仕様のため、ここではその命名規則に基づいてplan時点で
  # 確定できる値としてノードIDを組み立てる。
  value = [
    for i in range(1, var.redis_num_cache_clusters + 1) :
    format("%s-%03d", aws_elasticache_replication_group.redis.replication_group_id, i)
  ]
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
