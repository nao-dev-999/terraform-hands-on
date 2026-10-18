output "rds_instance_id" {
  value = aws_db_instance.this.id
}

output "rds_endpoint" {
  value = aws_db_instance.this.address

  # スリープ解除時、DBが起動しきる前にECSタスクが起動しないよう、起動完了を待たせる
  depends_on = [aws_rds_instance_state.this]
}

output "rds_port" {
  value = aws_db_instance.this.port
}

output "rds_secret_arn" {
  description = "The ARN of the Secrets Manager secret created by AWS for the RDS master user"
  value       = aws_db_instance.this.master_user_secret[0].secret_arn
}
