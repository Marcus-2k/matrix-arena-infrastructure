#!/bin/bash
set -e

# Update system
apt-get update -y
apt-get upgrade -y

# Install required packages (IMPORTANT: awscli + screen)
apt-get install -y openjdk-21-jdk awscli screen

# Wait for EBS NVMe disk to attach
sleep 20

# Format disk only if not already formatted
if ! blkid /dev/nvme1n1; then
  mkfs -t ext4 /dev/nvme1n1
fi

# Create mount directory
mkdir -p /minecraft-data

# Mount disk
mount /dev/nvme1n1 /minecraft-data

# Make mount persistent after reboot (avoid duplicates)
grep -q '^/dev/nvme1n1 /minecraft-data ' /etc/fstab || \
  echo "/dev/nvme1n1 /minecraft-data ext4 defaults,nofail 0 2" >> /etc/fstab

# Create minecraft user (ignore error if already exists)
useradd -m -d /minecraft-data minecraft || true

# Set ownership
chown -R minecraft:minecraft /minecraft-data

# Download jar with retries (IAM creds can take a bit)
for i in {1..20}; do
  aws s3 cp s3://minecraft-spigot-jar/spigot.jar /minecraft-data/spigot.jar && break
  sleep 5
done

# Fail loudly if jar still missing
if [ ! -f /minecraft-data/spigot.jar ]; then
  echo "ERROR: spigot.jar not downloaded from S3" >&2
  exit 1
fi

# Accept EULA
echo "eula=true" > /minecraft-data/eula.txt
chown minecraft:minecraft /minecraft-data/eula.txt /minecraft-data/spigot.jar

# Start server in screen under minecraft user
sudo -u minecraft bash << 'EOF'
cd /minecraft-data
screen -dmS mc java -Xms2G -Xmx2G -jar spigot.jar nogui
EOF