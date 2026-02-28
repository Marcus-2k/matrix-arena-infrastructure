
data "aws_eip" "existing" {
  id = var.eip_allocation_id
}

resource "aws_eip_association" "minecraft_eip" {
  instance_id   = aws_instance.minecraft_server.id
  allocation_id = data.aws_eip.existing.id
}
