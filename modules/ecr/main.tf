# 書籍では前提としてmodule "ecr"のcodepipeline/ecsからの出力名のみが登場し、
# コードの全容は掲載されていない（第12章12.9節）。CI/CDパイプライン(第10章)・
# ECSタスク定義(第6章)が実際に動作するために必要な最小構成として、他モジュールと
# 同じセキュリティ水準（イメージスキャン・ライフサイクルによる自動整理）で追加した。

resource "aws_ecr_repository" "app" {
  name                 = "${var.project}-${var.env}-app"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name = "${var.project}-${var.env}-app"
  }
}

resource "aws_ecr_repository" "flyway" {
  name                 = "${var.project}-${var.env}-flyway"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name = "${var.project}-${var.env}-flyway"
  }
}

resource "aws_ecr_repository" "batch" {
  name                 = "${var.project}-${var.env}-batch"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name = "${var.project}-${var.env}-batch"
  }
}

locals {
  # 未タグ付け(タグ上書きで浮いた旧イメージ)はビルドのたびに増え続けるため、
  # 直近を残しつつ一定数を超えたら古いものから自動削除する。
  # タグ付きイメージ(実際にデプロイされ得るもの)は対象外。
  lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images older than the newest ${var.untagged_image_retention_count}"
        selection = {
          tagStatus   = "untagged"
          countType   = "imageCountMoreThan"
          countNumber = var.untagged_image_retention_count
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name
  policy     = local.lifecycle_policy
}

resource "aws_ecr_lifecycle_policy" "flyway" {
  repository = aws_ecr_repository.flyway.name
  policy     = local.lifecycle_policy
}

resource "aws_ecr_lifecycle_policy" "batch" {
  repository = aws_ecr_repository.batch.name
  policy     = local.lifecycle_policy
}
