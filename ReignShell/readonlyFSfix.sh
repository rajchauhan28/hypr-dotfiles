96;9u#!/bin/bash

# Update this with the correct partition (e.g., /dev/sda3)
PARTITION="/dev/nvme0n1p4"
MOUNTPOINT="/hoem/reign/ddrive"

# Create mount point if it doesn't exist
sudo mkdir -p "$MOUNTPOINT"

# Unmount if already mounted
sudo umount "$PARTITION" 2>/dev/null

# Optional: run fsck to fix file system errors (not for NTFS)
echo "Checking file system (skip for NTFS)..."
sudo fsck -y "$PARTITION"

# Mount as read-write
echo "Mounting as read-write..."
sudo mount -o rw "$PARTITION" "$MOUNTPOINT"

echo "Mounted $PARTITION at $MOUNTPOINT as read-write"
