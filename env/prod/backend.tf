terraform {
  backend "s3" {
    bucket  = "terraform-bucket-tf-state-prod"
    key     = "terraform.tfstate"
    region  = "ap-northeast-1"
    encrypt = true
  }
}
