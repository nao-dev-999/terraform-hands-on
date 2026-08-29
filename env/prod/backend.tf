terraform {
  backend "s3" {
    bucket  = "terraform-bucket-tf-state"
    key     = "envs/prod/terraform.tfstate"
    region  = "ap-northeast-1"
    encrypt = true
    # dynamodb_table = "your-terraform-state-lock"
  }
}
