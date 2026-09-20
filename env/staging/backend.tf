terraform {
  backend "s3" {
    bucket  = "terraform-bucket-tf-state"
    key     = "env/staging/terraform.tfstate"
    region  = "ap-northeast-1"
    encrypt = true
  }
}
