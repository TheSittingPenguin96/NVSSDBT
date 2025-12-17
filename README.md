# Jetson Orin Nano Super - SSD Boot Setup

## Overview

This repository contains scripts to configure your NVIDIA Jetson Orin Nano Super Developer Kit to boot the root filesystem from an NVMe SSD instead of the microSD card. This provides a **significant performance improvement** for disk I/O operations.

## ⚠️ Important: This is a Temporary Solution

**This method is designed as a quick workaround to enable SSD speeds when you don't have immediate access to an x86 host PC.** While functional and stable, it is **not the recommended long-term solution** from NVIDIA.

### Why is this temporary?

This script only moves the **root filesystem** to the SSD. The bootloader, kernel, and device tree **still reside on the microSD card**. This means:

- ✅ You get the speed benefits of SSD for your applications and data
- ✅ Works without needing a host PC or SDK Manager
- ❌ The microSD card **must remain inserted** for the device to boot
- ❌ The boot chain is split across two storage devices
- ❌ Not the official NVIDIA-supported configuration

### The Proper Solution (When You Have Access to an x86 Host PC)

The **correct and recommended method** is to flash the entire system (including bootloader) directly to the SSD using NVIDIA's official tools:

#### Requirements for Proper Flashing:
- **x86 host PC** running Ubuntu 18.04 or later (or Windows with WSL2)
- **USB-C cable** to connect Jetson to host PC
- **NVIDIA SDK Manager** or command-line flash tools (L4T)
- The Jetson device in **recovery mode**

#### Proper Flashing Process:
1. Put your Jetson Orin Nano Super into **recovery mode**:
   - Power off the device
   - Connect USB-C cable between Jetson and host PC
   - Press and hold the recovery button
   - Press the power button
   - Release both buttons
   
2. On your x86 host PC, use **NVIDIA SDK Manager** to:
   - Select the Jetson Orin Nano Super as target
   - Choose to install to NVMe SSD
   - Flash the complete system to the SSD

3. After flashing, the Jetson will boot entirely from the SSD without needing the microSD card

#### Benefits of Proper Flashing:
- ✅ Boots entirely from SSD (no microSD required)
- ✅ Official NVIDIA-supported configuration
- ✅ Cleaner boot process
- ✅ Maximum performance
- ✅ Easier to maintain and update

For detailed instructions, see:
- [NVIDIA SDK Manager Documentation](https://docs.nvidia.com/sdk-manager/)
- [Jetson Linux Developer Guide](https://docs.nvidia.com/jetson/archives/r36.4/DeveloperGuide/IN/QuickStart.html)

## When to Use This Script

Use this temporary solution if:
- ✅ You need SSD performance **now** and don't have access to an x86 host PC
- ✅ You're setting up a development environment and need faster build times
- ✅ You're running disk-intensive applications (databases, ML training, etc.)
- ✅ You plan to properly flash the device later when you have access to proper tools

**Do NOT use this script if:**
- ❌ You have access to an x86 host PC (use SDK Manager instead)
- ❌ You need a production-ready configuration
- ❌ You cannot keep the microSD card permanently inserted

## Performance Comparison

### microSD Card (Class 10 / UHS-I)
- Sequential Read: ~90 MB/s
- Sequential Write: ~40 MB/s
- Random IOPS: Poor

### NVMe SSD (e.g., Samsung 970 EVO)
- Sequential Read: ~3,500 MB/s (38x faster)
- Sequential Write: ~2,500 MB/s (62x faster)
- Random IOPS: Excellent

**Real-world impact:**
- Faster application launches
- Quicker compilation times
- Better database performance
- Smoother Docker container operations

## What This Script Does

1. **Detects** your NVMe SSD
2. **Partitions and formats** the SSD as ext4
3. **Clones** your entire root filesystem from microSD to SSD using rsync
4. **Updates boot configuration** (extlinux.conf) to mount the SSD as root
5. **Configures** the microSD card as a dedicated boot device (read-only)

## Usage

### Step 1: Clone Root Filesystem to SSD

```bash
chmod +x ssd_boot_setup.sh
sudo ./ssd_boot_setup.sh
```

Follow the prompts and reboot when complete.

### Step 2: Configure microSD as Boot Device

After rebooting and verifying the SSD is working:

```bash
chmod +x configure_boot_sd.sh
sudo ./configure_boot_sd.sh
```

This will:
- Rename the microSD partition to `BOOT_SD`
- Mount it read-only to prevent accidental modifications
- Clearly identify it as the boot device

## Verification

After rebooting, verify your setup:

```bash
# Check that root filesystem is on SSD
df -h /
# Should show /dev/nvme0n1p1 mounted on /

# Check all mounted devices
lsblk
# Should show:
# - nvme0n1p1 mounted on /
# - mmcblk0p1 mounted on /media/BOOT_SD (boot partition)

# Test SSD performance
sudo hdparm -Tt /dev/nvme0n1
```

## Current Configuration

After running these scripts, your Jetson will have:

```
┌─────────────────────────────────────┐
│  Boot Process                       │
├─────────────────────────────────────┤
│  1. Bootloader (microSD)            │
│  2. Kernel (microSD)                │
│  3. Device Tree (microSD)           │
│  4. Root Filesystem (SSD) ← Fast!   │
└─────────────────────────────────────┘
```

**Note:** The microSD card must remain inserted at all times.

## Troubleshooting

### Device won't boot without microSD
This is expected behavior. The bootloader and kernel are on the microSD card.

### Need to update kernel or boot configuration
Remount the microSD as read-write:
```bash
sudo mount -o remount,rw /media/BOOT_SD
# Make your changes to /media/BOOT_SD/boot/extlinux/extlinux.conf
sudo mount -o remount,ro /media/BOOT_SD
```

### Want to revert to booting from microSD
```bash
sudo mv /boot/extlinux/extlinux.conf.backup /boot/extlinux/extlinux.conf
sudo reboot
```

## Migration Path to Proper Setup

When you gain access to an x86 host PC:

1. **Back up your data** from the SSD
2. **Download NVIDIA SDK Manager** on your x86 host
3. Put your Jetson into **recovery mode**
4. **Flash the complete system** to the SSD using SDK Manager
5. **Restore your data** to the newly flashed SSD
6. **Remove the microSD card** (no longer needed!)

## License

These scripts are provided as-is for convenience. Use at your own risk.

## References

- [NVIDIA Jetson Orin Nano Developer Kit User Guide](https://developer.nvidia.com/embedded/learn/jetson-orin-nano-devkit-user-guide)
- [NVIDIA SDK Manager](https://developer.nvidia.com/nvidia-sdk-manager)
- [Jetson Linux Documentation](https://docs.nvidia.com/jetson/)
