data "aws_s3_bucket" "server_backup" {
  bucket = "${var.project_name}-${var.environment}-world-backup"
}
