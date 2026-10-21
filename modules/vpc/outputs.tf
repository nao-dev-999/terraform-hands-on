output "vpc_id" {
  value = aws_vpc.this.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id

  # スリープ解除時、NAT経由の経路ができる前にECSタスクが起動してECRからのpullに失敗しないよう、
  # このサブネットを使うリソースはルートテーブルの関連付け完了を待つ。
  depends_on = [aws_route_table_association.private]
}
