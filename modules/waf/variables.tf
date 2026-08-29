variable "project" {
  type = string
}

variable "env" {
  type = string
}

variable "alb_arn" {
  type = string
}

variable "general_rate_limit" {
  type        = number
  default     = 2000
  description = "IPアドレス単位のリクエスト上限（5分間のローリングウィンドウ、AWS WAFv2の最小値は100）。全エンドポイント向けの粗い足切り。細かい制限はアプリ側のFilterで行う。"
}

variable "auth_rate_limit" {
  type        = number
  default     = 300
  description = "ログイン・サインアップ系エンドポイント（/auth/login, /auth/signup を含むパス）向けのIP単位リクエスト上限（5分間）。ブルートフォース・スパムアカウント作成対策。"
}

variable "waf_log_retention_days" {
  type    = number
  default = 30
}

variable "managed_rules_count_mode" {
  type    = bool
  default = false
}
