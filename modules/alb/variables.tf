variable "project" {
  type = string
}

variable "env" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "target_port" {
  type    = number
  default = 8080
}

variable "health_check_path" {
  type    = string
  default = "/actuator/health"
}

variable "deregistration_delay" {
  type        = number
  default     = 30
  description = "ターゲット登録解除までの待機秒数（デフォルトは300秒）。ECS Fargateのローリングデプロイを速くするため短縮。ECSタスク定義のstopTimeout・アプリのグレースフルシャットダウン時間との整合を取ること。"
}

variable "idle_timeout" {
  type    = number
  default = 60
}

variable "enable_waf_fail_open" {
  type        = bool
  default     = false
  description = "WAFが応答不能な場合の挙動。false(fail closed)はセキュリティ優先でリクエストを拒否、trueは可用性優先でWAF未検査のままリクエストを通す。"
}

variable "enable_deletion_protection" {
  type        = bool
  default     = false
  description = "ALBの削除保護。誤ってterraform destroy/applyでALBを消してしまうことを防ぐ。devでは頻繁に作り直すためfalse、本番環境ではtrueにすること。"
}

variable "maintenance_mode_enabled" {
  type    = bool
  default = false
}

variable "access_log_expiration_days" {
  type    = number
  default = 365
}

variable "alarm_sns_topic_arns" {
  type    = list(string)
  default = []
}
