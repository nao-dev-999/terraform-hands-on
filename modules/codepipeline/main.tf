resource "aws_s3_bucket" "artifacts" {
  bucket        = "${var.project}-${var.env}-pipeline-artifacts"
  force_destroy = true

  tags = {
    Project = var.project
    Env     = var.env
  }
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    id     = "expire-pipeline-artifacts"
    status = "Enabled"

    filter {}

    expiration {
      days = 30
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_iam_role" "pipeline" {
  name = "${var.project}-${var.env}-codepipeline-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "codepipeline.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "pipeline" {
  name = "pipeline-policy"
  role = aws_iam_role.pipeline.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:GetBucketVersioning", "s3:ListBucket"]
        Resource = ["${aws_s3_bucket.artifacts.arn}", "${aws_s3_bucket.artifacts.arn}/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["codebuild:BatchGetBuilds", "codebuild:StartBuild"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = ["ecs:DescribeServices", "ecs:DescribeTaskDefinition", "ecs:DescribeTasks",
          "ecs:ListTasks", "ecs:RegisterTaskDefinition", "ecs:UpdateService", "ecs:TagResource"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["codestar-connections:UseConnection", "codestar-connections:PassConnection"]
        Resource = aws_codestarconnections_connection.github.arn
      },
      {
        Effect   = "Allow"
        Action   = ["ecs:RunTask"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = ["iam:PassRole"]
        Resource = [
          var.task_execution_role_arn,
          var.task_role_arn
        ]
      }
    ]
  })
}

resource "aws_iam_role" "codebuild" {
  name = "${var.project}-${var.env}-codebuild-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "codebuild.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "codebuild" {
  name = "codebuild-policy"
  role = aws_iam_role.codebuild.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:GetBucketVersioning"]
        Resource = ["${aws_s3_bucket.artifacts.arn}", "${aws_s3_bucket.artifacts.arn}/*"]
      },
      {
        Effect = "Allow"
        Action = ["ecr:GetAuthorizationToken", "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer", "ecr:BatchGetImage", "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart", "ecr:CompleteLayerUpload", "ecr:PutImage"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["ecs:RunTask", "ecs:DescribeTasks", "ecs:DescribeTaskDefinition", "ecs:RegisterTaskDefinition"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["iam:PassRole"]
        Resource = [var.task_execution_role_arn, var.task_role_arn]
      }
    ]
  })
}

resource "aws_codestarconnections_connection" "github" {
  name          = "${var.project}-${var.env}-github"
  provider_type = "GitHub"
}

resource "aws_cloudwatch_log_group" "codebuild" {
  name              = "/codebuild/${var.project}-${var.env}"
  retention_in_days = 14
}

resource "aws_codebuild_project" "build" {
  name          = "${var.project}-${var.env}-build"
  description   = "Build Docker image and push to ECR"
  build_timeout = 20
  service_role  = aws_iam_role.codebuild.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true # Docker-in-Docker に必要

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.aws_region
    }
    environment_variable {
      name  = "ECR_REPO_URI"
      value = var.app_repository_url
    }
    environment_variable {
      name  = "FLYWAY_ECR_REPO_URI"
      value = var.flyway_repository_url
    }
    environment_variable {
      name  = "ECS_CLUSTER"
      value = var.ecs_cluster_name
    }
    environment_variable {
      name  = "FLYWAY_TASK_DEF_FAMILY"
      value = var.flyway_task_definition_family
    }
    environment_variable {
      name  = "FLYWAY_SUBNET"
      value = var.flyway_subnet_id
    }
    environment_variable {
      name  = "FLYWAY_SG"
      value = var.flyway_sg_id
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "backend/buildspec.yml"
  }

  logs_config {
    cloudwatch_logs {
      group_name = aws_cloudwatch_log_group.codebuild.name
    }
  }

  tags = {
    Project = var.project
    Env     = var.env
  }
}

locals {
  api_tag_pattern   = "api-${var.env}-v*"
  batch_tag_pattern = "batch-${var.env}-v*"
}

resource "aws_codepipeline" "this" {
  name          = "${var.project}-${var.env}-pipeline"
  role_arn      = aws_iam_role.pipeline.arn
  pipeline_type = "V2"

  artifact_store {
    location = aws_s3_bucket.artifacts.bucket
    type     = "S3"
  }

  # タグ "api-${env}-vX.Y.Z" のpushでのみ起動する（ブランチへの通常pushでは起動しない）
  trigger {
    provider_type = "CodeStarSourceConnection"

    git_configuration {
      source_action_name = "GitHub_Source"

      push {
        tags {
          includes = [local.api_tag_pattern]
        }
      }
    }
  }

  stage {
    name = "Source"

    action {
      name             = "GitHub_Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn        = aws_codestarconnections_connection.github.arn
        FullRepositoryId     = var.github_repository # "owner/repo"
        BranchName           = var.github_branch
        OutputArtifactFormat = "CODE_ZIP"
        DetectChanges        = "false"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "CodeBuild"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]

      configuration = {
        ProjectName = aws_codebuild_project.build.name
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "ECS_Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      version         = "1"
      input_artifacts = ["build_output"]

      configuration = {
        ClusterName = var.ecs_cluster_name
        ServiceName = var.ecs_service_name
        FileName    = "imagedefinitions.json"
      }
    }
  }
}

resource "aws_codebuild_project" "batch_build" {
  name          = "${var.project}-${var.env}-batch-build"
  description   = "Build batch Docker image, push to ECR and register a new task definition revision"
  build_timeout = 20
  service_role  = aws_iam_role.codebuild.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true # Docker-in-Docker に必要

    environment_variable {
      name  = "ECR_REPO_URI"
      value = var.batch_repository_url
    }
    environment_variable {
      name  = "BATCH_TASK_DEF_FAMILY"
      value = var.batch_task_definition_family
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "batch/buildspec.yml"
  }

  logs_config {
    cloudwatch_logs {
      group_name = aws_cloudwatch_log_group.codebuild.name
    }
  }
}

resource "aws_codepipeline" "batch" {
  name          = "${var.project}-${var.env}-batch-pipeline"
  role_arn      = aws_iam_role.pipeline.arn
  pipeline_type = "V2"

  artifact_store {
    location = aws_s3_bucket.artifacts.bucket
    type     = "S3"
  }

  # タグ "batch-${env}-vX.Y.Z" のpushでのみ起動する
  trigger {
    provider_type = "CodeStarSourceConnection"
    git_configuration {
      source_action_name = "GitHub_Source"
      push {
        tags {
          includes = [local.batch_tag_pattern]
        }
      }
    }
  }

  stage {
    name = "Source"
    action {
      name             = "GitHub_Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]
      configuration = {
        ConnectionArn        = aws_codestarconnections_connection.github.arn
        FullRepositoryId     = var.github_repository
        BranchName           = var.github_branch
        OutputArtifactFormat = "CODE_ZIP"
        DetectChanges        = "false"
      }
    }
  }

  stage {
    name = "Build"
    action {
      name             = "CodeBuild"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      configuration = {
        ProjectName = aws_codebuild_project.batch_build.name
      }
    }
  }
  # Deployステージは存在しない（10.9.2節）
}
