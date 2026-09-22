terraform {
  backend "s3" {
    bucket  = "terraform-bucket-tf-state-staging"
    key     = "terraform.tfstate"
    region  = "ap-northeast-1"
    encrypt = true
  }
}
