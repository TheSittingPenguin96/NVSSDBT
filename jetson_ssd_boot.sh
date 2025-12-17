#!/bin/bash

# Jetson Orin Nano Super - Boot from SSD Setup Script
# This script clones the root filesystem to SSD and configures boot
# Run this script on the Jetson itself while booted from microSD

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Jetson Orin Nano Super - SSD Boot Setup ===${NC}"
echo "This script will:"
echo "1. Detect your SSD"
echo "2. Format and partition the SSD"
echo "3. Clone your root filesystem to the SSD"
echo "4. Update boot configuration to use SSD"
echo ""
echo -e "${YELLOW}WARNING: This will erase ALL data on the target SSD!${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root (use sudo)${NC}"
    exit 1
fi

# Install required dependencies
echo -e "${GREEN}Installing dependencies...${NC}"
apt-get update
apt-get install -y parted rsync gdisk

# Detect SSD
echo -e "${GREEN}Detecting NVMe SSD...${NC}"
if [ -b /dev/nvme0n1 ]; then
    SSD_DEVICE="/dev/nvme0n1"
    SSD_PARTITION="${SSD_DEVICE}p1"
elif [ -b /dev/sda ]; then
    SSD_DEVICE="/dev/sda"
    SSD_PARTITION="${SSD_DEVICE}1"
else
    echo -e "${RED}No SSD detected! Please ensure your SSD is properly connected.${NC}"
    exit 1
fi

echo -e "${GREEN}Found SSD: ${SSD_DEVICE}${NC}"

# Show disk info
echo ""
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT | grep -E "nvme|sda|mmcblk"
echo ""

read -p "Is this the correct SSD device? This will ERASE all data on ${SSD_DEVICE}! (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 1
fi

# Unmount all partitions on the SSD
echo -e "${GREEN}Unmounting all SSD partitions...${NC}"
for partition in ${SSD_DEVICE}*; do
    if [[ $partition == ${SSD_DEVICE}p* ]] || [[ $partition == ${SSD_DEVICE}[0-9]* ]]; then
        umount $partition 2>/dev/null || true
    fi
done

# Disable swap if it's on the SSD
echo -e "${GREEN}Checking for swap on SSD...${NC}"
SWAP_DEVICES=$(swapon --show=NAME --noheadings)
for swap in $SWAP_DEVICES; do
    if [[ $swap == ${SSD_DEVICE}* ]]; then
        echo "Disabling swap on $swap"
        swapoff $swap
    fi
done

# Force unmount and clear any remaining usage
fuser -km ${SSD_DEVICE}* 2>/dev/null || true
sleep 2

# Wipe filesystem signatures
echo -e "${GREEN}Wiping filesystem signatures...${NC}"
wipefs -a ${SSD_DEVICE}
sleep 2

# Use dd to zero out the beginning of the disk
echo -e "${GREEN}Clearing partition table...${NC}"
dd if=/dev/zero of=${SSD_DEVICE} bs=1M count=10 status=progress
sync
sleep 2

# Force kernel to re-read partition table
echo -e "${GREEN}Reloading partition table...${NC}"
partprobe ${SSD_DEVICE}
sleep 2

# Partition the SSD using sgdisk (more reliable than parted for this)
echo -e "${GREEN}Partitioning SSD...${NC}"
sgdisk -Z ${SSD_DEVICE}
sgdisk -n 1:0:0 -t 1:8300 ${SSD_DEVICE}
partprobe ${SSD_DEVICE}
sleep 3

# Format the partition
echo -e "${GREEN}Formatting SSD partition as ext4...${NC}"
mkfs.ext4 -F ${SSD_PARTITION}
sleep 2

# Create mount point and mount
MOUNT_POINT="/mnt/ssd_root"
mkdir -p ${MOUNT_POINT}
mount ${SSD_PARTITION} ${MOUNT_POINT}

# Get UUID of the SSD partition
SSD_UUID=$(blkid -s UUID -o value ${SSD_PARTITION})
echo -e "${GREEN}SSD partition UUID: ${SSD_UUID}${NC}"

# Clone root filesystem to SSD
echo -e "${GREEN}Cloning root filesystem to SSD (this may take 10-20 minutes)...${NC}"
rsync -axHAWX --numeric-ids --info=progress2 --exclude={"/dev/*","/proc/*","/sys/*","/tmp/*","/run/*","/mnt/*","/media/*","/lost+found"} / ${MOUNT_POINT}/

# Create necessary directories on SSD
mkdir -p ${MOUNT_POINT}/{dev,proc,sys,tmp,run,mnt,media}

# Update fstab on SSD to mount itself as root
echo -e "${GREEN}Updating fstab on SSD...${NC}"
cat > ${MOUNT_POINT}/etc/fstab << EOF
# /etc/fstab: static file system information.
UUID=${SSD_UUID}  /  ext4  defaults  0  1
EOF

# Get current root UUID (microSD)
CURRENT_ROOT_UUID=$(findmnt -n -o UUID /)

# Backup and update extlinux.conf
EXTLINUX_CONF="/boot/extlinux/extlinux.conf"
if [ -f ${EXTLINUX_CONF} ]; then
    echo -e "${GREEN}Backing up and updating extlinux.conf...${NC}"
    cp ${EXTLINUX_CONF} ${EXTLINUX_CONF}.backup
    
    # Replace root UUID in extlinux.conf
    sed -i "s/root=UUID=${CURRENT_ROOT_UUID}/root=UUID=${SSD_UUID}/g" ${EXTLINUX_CONF}
    sed -i "s|root=/dev/mmcblk0p1|root=UUID=${SSD_UUID}|g" ${EXTLINUX_CONF}
    
    echo -e "${GREEN}Updated boot configuration.${NC}"
else
    echo -e "${YELLOW}Warning: extlinux.conf not found at expected location.${NC}"
    echo "You may need to manually update boot configuration."
fi

# Sync and unmount
sync
umount ${MOUNT_POINT}

echo ""
echo -e "${GREEN}=== Setup Complete! ===${NC}"
echo ""
echo "Your Jetson is now configured to boot from SSD."
echo ""
echo -e "${YELLOW}IMPORTANT: Please reboot your system now.${NC}"
echo ""
echo "After reboot, verify with: df -h /"
echo "You should see your root (/) mounted on ${SSD_PARTITION}"
echo ""
echo "If something goes wrong, you can:"
echo "1. Power off and remove the SSD"
echo "2. Boot from microSD"
echo "3. Restore extlinux.conf: sudo mv /boot/extlinux/extlinux.conf.backup /boot/extlinux/extlinux.conf"
echo ""
read -p "Would you like to reboot now? (yes/no): " reboot_confirm
if [ "$reboot_confirm" = "yes" ]; then
    echo "Rebooting in 5 seconds..."
    sleep 5
    reboot
fi