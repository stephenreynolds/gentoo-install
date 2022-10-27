#!/bin/bash

################################################
# Partitioning
################################################

# Partition the main drive
fdisk /dev/nvme0n1 -w always
fdisk /dev/nvme0n1
# Boot partition
n # New partition
1 # First partition
  # Start at beginning of disk
+256M # Size of partition
t # Partition type
1 # Select EFI System partition
# Root partition
n
2
  # Start at end of partition 1
  # Use remaining space
w # Write changes

# Partition the second drive
fdisk /dev/nvme1n1 -w always
fdisk /dev/nvme1n1
# Root partition
n # New partition
1 # First partition
  # Start at beginning of disk
  # Use remaining space
w

###################################################
# Formatting
###################################################

# Format the boot partition
mkfs.vfat -n BOOT /dev/nvme0n1p1
# Format the root partitions
mkfs.btrfs -L ROOT -m raid1 -d single /dev/nvme0n1p2 /dev/nvme1n1p1

###################################################
# Create Btrfs Subvolumes
###################################################

MOUNT_OPTS=defaults,noatime,nodiratime,compress-force=zstd,ssd,space_cache=v2
MOUNT=/mnt/gentoo

mount -t btrfs -o $MOUNT_OPTS -L ROOT $MOUNT
btrfs subvolume create $MOUNT/@
btrfs subvolume create $MOUNT/@home
btrfs subvolume create $MOUNT/@distfiles
btrfs subvolume create $MOUNT/@repos
umount $MOUNT

###################################################
# Mount the subvolumes and partitions
###################################################
 
mount -t btrfs -o $MOUNT_OPTS,subvol=@ -L ROOT $MOUNT
mkdir -p $MOUNT/{boot,home,var/gentoo/distfiles,var/db/repos}

mount -t btrfs -o $MOUNT_OPTS,subvol=@home -L ROOT $MOUNT/home
mount -t btrfs -o $MOUNT_OPTS,subvol=@distfiles -L ROOT $MOUNT/var/gentoo/distfiles
mount -t btrfs -o $MOUNT_OPTS,subvol=@repos -L ROOT $MOUNT/var/db/repos

###################################################
# Install Stage 3
###################################################

STAGE3_TAR="https://bouncer.gentoo.org/fetch/root/all/releases/amd64/autobuilds/20221016T170545Z/stage3-amd64-systemd-20221016T170545Z.tar.xz"

cd $MOUNT
wget $STAGE3_TAR
tar xpvf stage3-*.tar.xz --xattrs-include='*.*' --numeric-owner
rm stage3-*.tar.xz

###################################################
# Configure compile options
###################################################

