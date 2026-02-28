variable "region" {
  type    = string
  default = "eu-central-1"
}

variable "instance_type" {
  type    = string
}

variable "world_volume" {
  type    = number
}

variable "s3_bucket_server_backup" {
  type = string
}

variable "access_key" {
  type = string
}

variable "secret_key" {
  type = string
}

variable "eip_allocation_id" {
  type        = string
  description = "Allocation ID of the existing Elastic IP (e.g., eipalloc-xxxxx)"
}