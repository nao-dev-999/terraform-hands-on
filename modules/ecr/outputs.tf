output "app_repository_url" {
  value = aws_ecr_repository.app.repository_url
}

output "flyway_repository_url" {
  value = aws_ecr_repository.flyway.repository_url
}

output "batch_repository_url" {
  value = aws_ecr_repository.batch.repository_url
}
