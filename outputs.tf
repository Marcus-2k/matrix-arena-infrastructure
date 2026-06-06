output "minecraft_server_ip" {
  value = aws_eip_association.minecraft_eip.public_ip
}

output "instance_id" {
  value = aws_instance.minecraft_server.id
}