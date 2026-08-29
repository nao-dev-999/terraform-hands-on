variable "project" {
  type = string
}

variable "env" {
  type = string
}

variable "untagged_image_retention_count" {
  type        = number
  default     = 5
  description = "タグなしイメージを直近何件残すか。これを超えた分は自動的に期限切れとして削除される"
}
