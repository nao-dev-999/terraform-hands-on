output "ecs_sg_id" {
  value = aws_security_group.ecs.id
}

output "app_log_group_name" {
  value = aws_cloudwatch_log_group.app.name
}

output "redis_cluster_id" {
  value = aws_elasticache_cluster.redis.cluster_id
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
  value = aws_elasticache_cluster.redis.cache_nodes[0].address
}
