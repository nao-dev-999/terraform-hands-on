output "rds_endpoint" {
  value = aws_db_instance.this.address
}

output "rds_port" {
  value = aws_db_instance.this.port
}

output "rds_secret_arn" {
  description = "The ARN of the Secrets Manager secret created by AWS for the RDS master user"
  value       = aws_db_instance.this.master_user_secret[0].secret_arn
}
