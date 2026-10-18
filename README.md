# terraform-hands-on

## dev環境のスリープモード（コスト削減）

使わない間は `destroy` せずに、`sleep_mode` を切り替えて時間課金のリソースだけを止められます。

```bash
cd env/dev

# 寝かせる（NAT Gateway・ALB・WAF・Redisを削除し、ECSタスクを0、RDSを停止）
terraform apply -var="sleep_mode=true"

# 起こす（10〜15分ほどで元の構成に戻る）
terraform apply -var="sleep_mode=false"
```

`terraform.tfvars` に `sleep_mode = true` と書いておく運用でも構いません。

| リソース | スリープ中 |
|---|---|
| NAT Gateway / EIP | 削除（プライベートサブネットはVPC内通信のみ） |
| ALB / リスナー | 削除（ターゲットグループ・SG・証明書は残す） |
| WAF WebACL | 削除（ログバケットは残す） |
| ElastiCache Redis | 削除（中身のデータは消える） |
| ECSサービス | 残す（オートスケールのmin/maxを0にしてタスク数0） |
| RDS | 停止（データは残る。ストレージ料金のみ） |
| 日次バッチのスケジュール | 無効化 |
| VPC・ECR・IAM・CodePipeline・S3・アラーム等 | そのまま |

注意点

- RDSはAWSの仕様で、停止から7日経つと自動で起動します。長く寝かせる場合は、時々 `terraform apply -var="sleep_mode=true"` を実行して停止し直してください。
- スリープ中はRDSが停止しているため、RDSの設定変更（インスタンスクラス等）は適用できません。起こしてから変更してください。
- ALBは作り直しのたびにDNS名が変わります（EC2コンソールのロードバランサー画面で確認してください）。
- スリープ中にCodePipelineが動いた場合、デプロイは失敗します。
- 起こした後にアプリがRedisへ接続できない場合は、CodePipelineを再実行するか `aws ecs update-service --force-new-deployment` で再デプロイしてください。
