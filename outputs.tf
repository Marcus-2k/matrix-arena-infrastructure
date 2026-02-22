output "minecraft_server_ip" {
  value = aws_eip.minecraft_eip.public_ip
}

output "s3_bucket_name" {
  value = data.aws_s3_bucket.spigot_jar.bucket
}