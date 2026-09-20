terraform {
  backend "s3" {
    bucket  = "terraform-bucket-tf-state"
    key     = "env/prod/terraform.tfstate"
    region  = "ap-northeast-1"
    encrypt = true
  }
}
