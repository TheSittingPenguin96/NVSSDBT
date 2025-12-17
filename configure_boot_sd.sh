#!/bin/bash

# Configure Boot microSD Card
# This script sets up the microSD card as a dedicated boot device
# - Renames the partition label to BOOT_SD
# - Mounts it read-only to prevent accidental modifications

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Configure Boot microSD Card ===${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root (use sudo)${NC}"
    exit 1
fi

# Detect microSD card (usually mmcblk0p1 or mmcblk1p1)
SD_PARTITION=""
if [ -b /dev/mmcblk0p1 ]; then
    SD_PARTITION="/dev/mmcblk0p1"
elif [ -b /dev/mmcblk1p1 ]; then
    SD_PARTITION="/dev/mmcblk1p1"
else
    echo -e "${RED}Could not detect microSD card partition${NC}"
    echo "Please specify it manually"
    exit 1
fi

echo -e "${GREEN}Found microSD partition: ${SD_PARTITION}${NC}"

# Get current mount point
SD_MOUNT=$(findmnt -n -o TARGET ${SD_PARTITION} 2>/dev/null || echo "")

if [ -z "$SD_MOUNT" ]; then
    echo -e "${YELLOW}microSD is not currently mounted${NC}"
    SD_MOUNT="/media/BOOT_SD"
    mkdir -p ${SD_MOUNT}
fi

echo "Current mount point: ${SD_MOUNT}"
echo ""

# Rename the partition label
echo -e "${GREEN}Renaming partition label to BOOT_SD...${NC}"
e2label ${SD_PARTITION} BOOT_SD

# Update fstab to mount as read-only
echo -e "${GREEN}Updating /etc/fstab for read-only boot partition...${NC}"

# Remove existing entry for this partition if any
sed -i "\|${SD_PARTITION}|d" /etc/fstab
sed -i '/BOOT_SD/d' /etc/fstab

# Add new read-only entry
echo "# Boot microSD card (read-only)" >> /etc/fstab
echo "LABEL=BOOT_SD  /media/BOOT_SD  ext4  ro,noatime  0  2" >> /etc/fstab

# Create mount point
mkdir -p /media/BOOT_SD

echo ""
echo -e "${GREEN}=== Configuration Complete! ===${NC}"
echo ""
echo "The microSD card is now labeled as BOOT_SD"
echo "It will be mounted read-only at /media/BOOT_SD on next boot"
echo ""
echo -e "${YELLOW}Important notes:${NC}"
echo "- Keep the microSD card inserted for the Jetson to boot"
echo "- The bootloader and kernel load from the microSD"
echo "- The root filesystem runs from your SSD"
echo "- The microSD is protected from accidental writes"
echo ""
echo "If you need to update boot files (kernel, extlinux.conf):"
echo "  sudo mount -o remount,rw /media/BOOT_SD"
echo "  # Make your changes"
echo "  sudo mount -o remount,ro /media/BOOT_SD"
echo ""

read -p "Would you like to remount the microSD as read-only now? (yes/no): " remount
if [ "$remount" = "yes" ]; then
    umount ${SD_PARTITION} 2>/dev/null || true
    mount -a
    echo -e "${GREEN}microSD remounted as read-only${NC}"
    mount | grep BOOT_SD
fi