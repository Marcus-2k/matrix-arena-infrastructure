############################################
# IAM Role for EC2 (S3 access)
############################################

resource "aws_iam_role" "minecraft_role" {
  name = "minecraft-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "minecraft_s3_readonly" {
  role       = aws_iam_role.minecraft_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

resource "aws_iam_instance_profile" "minecraft_profile" {
  name = "minecraft-instance-profile"
  role = aws_iam_role.minecraft_role.name
}

############################################
# EC2 Instance
############################################

resource "aws_instance" "minecraft_server" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = "access-key"
  vpc_security_group_ids      = [aws_security_group.minecraft_sg.id]
  subnet_id                   = aws_subnet.minecraft_subnet.id
  associate_public_ip_address = true
  iam_instance_profile = aws_iam_instance_profile.minecraft_profile.name

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  user_data = file("user_data.sh")

  tags = {
    Name = "MinecraftServer"
  }
}

############################################
# Latest Ubuntu AMI
############################################

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

############################################
# EBS Volume for World
############################################

resource "aws_ebs_volume" "minecraft_world" {
  availability_zone = aws_instance.minecraft_server.availability_zone
  size              = var.world_volume
  type              = "gp3"

  tags = {
    Name = "MinecraftWorldVolume"
  }
}

resource "aws_volume_attachment" "minecraft_world_attach" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.minecraft_world.id
  instance_id = aws_instance.minecraft_server.id
}