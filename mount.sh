
#!/usr/bin/env bash

set -e

MOUNT_POINT="/mnt/ssd2"

read -rp "Enter mount point [$MOUNT_POINT]: " INPUT
MOUNT_POINT="${INPUT:-$MOUNT_POINT}"

echo -e "\nDISKS AND PARTITIONS\n"

# 1. List disks and partitions
lsblk -f

# 2. Request partition UUID
echo
read -rp "Enter partition UUID: " UUID

# 3. Validate UUID
DEVICE=$(sudo blkid -U "$UUID" 2>/dev/null || true)

if [[ -z "$DEVICE" ]]; then
    echo "Error: UUID not found."
    exit 1
fi

echo "Device found: $DEVICE"

# 4. Check filesystem type
FSTYPE=$(sudo blkid -s TYPE -o value "$DEVICE")

if [[ "$FSTYPE" != "ext4" ]]; then
    echo "Error: filesystem is $FSTYPE, not ext4."
    exit 1
fi

# 5. Create mount point
sudo mkdir -p "$MOUNT_POINT"

# 6. Check for existing fstab entry
if ! grep -Eq "^[[:space:]]*UUID=$UUID[[:space:]]" /etc/fstab; then

    sudo cp /etc/fstab "/etc/fstab.bak.$(date +%Y%m%d-%H%M%S)"

    echo "UUID=$UUID $MOUNT_POINT ext4 defaults,nofail 0 2" \
        | sudo tee -a /etc/fstab

else
    echo "UUID already exists in fstab."
fi

# 7. Check if the partition is already mounted
if mountpoint -q "$MOUNT_POINT"; then
    echo "Partition is already mounted."
else
    echo "Attempting to mount partition..."
    sudo mount "$MOUNT_POINT"
fi

# 8. Verify mount status
if ! mountpoint -q "$MOUNT_POINT"; then
    echo "Error: unable to mount partition."
    exit 1
fi

# 9. Set directory ownership
sudo chown "$USER:$(id -gn)" "$MOUNT_POINT"

# 10. Test write permissions
TEST_FILE="$MOUNT_POINT/.permission_test"

if touch "$TEST_FILE"; then
    rm "$TEST_FILE"
    echo "Write permissions OK!"
else
    echo "Error: insufficient write permissions."
    exit 1
fi

# 11. Display results
echo
echo "Success! Partition/disk mounted at: $MOUNT_POINT"

findmnt "$MOUNT_POINT"
df -h "$MOUNT_POINT"
