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

variable "ssh_ip" {
  type = string
}

variable "s3_bucket" {
  type = string
}

variable "access_key" {
  type = string
}

variable "secret_key" {
  type = string
}