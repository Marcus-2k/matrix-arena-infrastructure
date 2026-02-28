#!/bin/bash
set -euo pipefail

# -----------------------------
# 1) Variables
# -----------------------------
DEVICE="/dev/nvme1n1"

REPO_DIR="/opt/matrix-arena-server"
DATA_DIR="$REPO_DIR/minecraft-data"

BACKUP_BUCKET="matrix-arena-backup"
BACKUP_SUFFIX=".tar.gz"

TMP_BACKUP="/tmp/mc_backup_latest.tar.gz"
RESTORE_MARKER="$DATA_DIR/.restored"

# -----------------------------
# 2) Update all packages
# -----------------------------
apt-get update -y
apt-get upgrade -y

# -----------------------------
# 3) Install required packages (awscli + archiver/unarchiver)
# -----------------------------
apt-get install -y awscli tar gzip pigz ca-certificates docker.io docker-compose
systemctl enable --now docker

# -----------------------------
# 4) Prepare dirs + mount EBS to DATA_DIR
# -----------------------------
mkdir -p "$REPO_DIR"
mkdir -p "$DATA_DIR"

# Wait for EBS NVMe disk to attach
sleep 20

# Format disk only if not already formatted
if ! blkid "$DEVICE" >/dev/null 2>&1; then
  mkfs -t ext4 "$DEVICE"
fi

# Mount disk
mount "$DEVICE" "$DATA_DIR"

# Make mount persistent after reboot (avoid duplicates)
grep -q "^$DEVICE $DATA_DIR " /etc/fstab || \
  echo "$DEVICE $DATA_DIR ext4 defaults,nofail 0 2" >> /etc/fstab

# -----------------------------
# 5) Download latest backup from S3 (root)
# -----------------------------
# -----------------------------
# 6) Guard: don't restore if already restored / not empty
# -----------------------------
if [ -f "$RESTORE_MARKER" ]; then
  echo "Restore marker exists ($RESTORE_MARKER). Skipping restore."
  exit 0
fi

if [ -n "$(ls -A "$DATA_DIR" | grep -v '^lost+found$')" ]; then
  echo "DATA_DIR contains real files. Skipping restore."
  exit 0
fi

echo "DATA_DIR is empty. Restoring latest backup from s3://$BACKUP_BUCKET/"

LATEST_KEY="$(aws s3api list-objects-v2 \
  --bucket "$BACKUP_BUCKET" \
  --query "reverse(sort_by(Contents[?ends_with(Key, \`$BACKUP_SUFFIX\`)], &LastModified))[0].Key" \
  --output text)"

if [ -z "$LATEST_KEY" ] || [ "$LATEST_KEY" = "None" ]; then
  echo "ERROR: No backup files (*$BACKUP_SUFFIX) found in s3://$BACKUP_BUCKET/" >&2
  exit 1
fi

echo "Latest backup key: $LATEST_KEY"

# Download with retries (IAM creds/network can take a bit)
for i in {1..20}; do
  aws s3 cp "s3://$BACKUP_BUCKET/$LATEST_KEY" "$TMP_BACKUP" && break
  sleep 5
done

if [ ! -f "$TMP_BACKUP" ]; then
  echo "ERROR: Backup not downloaded: s3://$BACKUP_BUCKET/$LATEST_KEY" >&2
  exit 1
fi

# -----------------------------
# 7) Extract backup into DATA_DIR
# -----------------------------
# Archive should contain the full minecraft-data contents at top level:
# world/, plugins/, server.properties, etc.
tar -xzf "$TMP_BACKUP" -C "$DATA_DIR"
rm -f "$TMP_BACKUP"

# Mark successful restore
touch "$RESTORE_MARKER"

echo "Restore complete."