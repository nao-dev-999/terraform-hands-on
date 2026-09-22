terraform {
  backend "s3" {
    bucket         = "terraform-bucket-tf-state-dev"
    key            = "terraform.tfstate"
    region         = "ap-northeast-1"
    encrypt        = true
    profile        = "dev"
    # dynamodb_table = "your-terraform-state-lock"
  }
}
