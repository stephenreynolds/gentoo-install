# Step 1

## Connect to the network

`net-setup wlp4s0`

### Partitioning
`fdisk /dev/nvme0n1`

#### Partition /dev/nvme0n1 to match the below table (with GPT)

 |  Partition       |   SIZE      |  TYPE                |
 |------------------|-------------|----------------------|
 | /dev/nvme0n1p1   |  128M       | EFI System Partition |
 | /dev/nvme0n1p2   |  Remaining  | Linux Filesystem     |

`fdisk /dev/nvme1n1`

#### Partition /dev/nvme1n1 to match the below table (with GPT)

 |  Partition      |    SIZE      |  TYPE             |
 |-----------------|--------------|-------------------|
 | /dev/nvme1n1p1  |   Remaining  | Linux Filesystem  |

### Make filesystems

```
mkfs.vfat -n BOOT /dev/nvme0n1p1
mkfs.btrfs -L ROOT -m raid0 -d raid0 /dev/nvme0n1p2 /dev/nvme1n1p1
```

## Make subvolumes and mount

### Make subvolumes

```
mount -t btrfs -o defaults,noatime,compress-force=zstd:2,ssd,space_cache=v2 -L ROOT /mnt/gentoo
btrfs subvolume create /mnt/gentoo/@
btrfs subvolume create /mnt/gentoo/@home
btrfs subvolume create /mnt/gentoo/@snapshots
btrfs subvolume create /mnt/gentoo/@binpkgs
btrfs subvolume create /mnt/gentoo/@distfiles
btrfs subvolume create /mnt/gentoo/@repos
umount /mnt/gentoo
```

### Mount the subvolumes and boot partition

```

mount -t btrfs -o noatime,compress-force=zstd:2,ssd,space_cache=v2,subvol=@ -L ROOT /mnt/gentoo
mkdir -p /mnt/gentoo/{boot,home,var/cache/binpkgs,var/cache/distfiles,var/db/repos}

mount /dev/nvme0n1p1 /mnt/gentoo/boot
mount -t btrfs -o noatime,compress-force=zstd:2,ssd,space_cache=v2,subvol=@home -L ROOT /mnt/gentoo/home
mount -t btrfs -o noatime,compress-force=zstd:2,ssd,space_cache=v2,subvol=@snapshots -L ROOT /mnt/gentoo/.snapshots
mount -t btrfs -o noatime,compress-force=zstd:2,ssd,space_cache=v2,subvol=@binpkgs -L ROOT /mnt/gentoo/var/cache/binpkgs
mount -t btrfs -o noatime,compress-force=zstd:2,ssd,space_cache=v2,subvol=@distfiles -L ROOT /mnt/gentoo/var/cache/distfiles
mount -t btrfs -o noatime,compress-force=zstd:2,ssd,space_cache=v2,subvol=@repos -L ROOT /mnt/gentoo/var/db/repos
```

## Install Stage 3

`cd /mnt/gentoo`

### Download the x86_64 OpenRC non-desktop profile

`links https://www.gentoo.org/downloads/mirrors/`

### Unpack the tarball

```
tar xpvf stage3-*.tar.xz --xattrs-include='*.*' --numeric-owner
rm stage3-*.tar.xz
```

### Configure compile options

`nano /mnt/gentoo/etc/portage/make.conf`

Add the following flags to make.conf: 
```
COMMON_FLAGS="-march=skylake -O2 -pipe"
MAKEOPTS="-j4"
EMERGE_DEFAULT_OPTS="--jobs=2 --load-average=7.6 --ask --quiet --verbose"
PORTAGE_NICENESS="15"
FEATURES="parallel-install"
```

### Configure mirrors

Select mirrors that are nearby geographically.
`mirrorselect -i -o >> /mnt/gentoo/etc/portage/make.conf`

### Set up Gentoo ebuild repos

```
mkdir --parents /mnt/gentoo/etc/portage/repos.conf
cp /mnt/gentoo/usr/share/portage/config/repos.conf /mnt/gentoo/etc/portage/repos.conf/gentoo.conf
```
### Copy DNS info

`cp --dereference /etc/resolv.conf /mnt/gentoo/etc/`

### Mount necessary filesystems

```
mount --types proc /proc /mnt/gentoo/proc
mount --rbind /sys /mnt/gentoo/sys
mount --make-rslave /mnt/gentoo/sys
mount --rbind /dev /mnt/gentoo/dev
mount --make-rslave /mnt/gentoo/dev
mount --bind /run /mnt/gentoo/run
mount --make-slave /mnt/gentoo/run
```

### Enter the new environment

```
chroot /mnt/gentoo /bin/bash
source /etc/profile
export PS1="(chroot) ${PS1}"
```

### Update ebuild repos

```
emerge-webrsync
emerge --sync
```

### Select a profile

Make sure the correct profile is selected (replace 1 with correct number in the list): 
```
eselect profile list
eselect profile set 1
```

### Update the @world set

`emerge --ask --update --deep --newuse @world`

### Add CPU flags

```
emerge --ask app-portage/cpuid2cpuflags
echo "*/* $(cpuid2cpuflags)" > /etc/portage/package.use/00cpu-flags
touch /etc/portage/package.use/zz-autounmask
```

### Add USE flags and other make.conf variables

Use the following command to find flags for input devices:
`portageq envvar INPUT_DEVICES`

```
# append to /etc/portage/make.conf

USE="X"

INPUT_DEVICES="libinput"
VIDEO_CARDS="nvidia"
ACCEPT_LICENSE="*"
```

### Configure timezone

```
echo "America/Detroit" > /etc/timezone
ln -sf ../usr/share/zoneinfo/America/Detroit /etc/localtime
```

### Locale generation

Uncomment the following locales:
```
# /etc/locale.gen

en_US.UTF-8 UTF-8
ja_JP.UTF-8 UTF-8
```

`locale-gen`

Get a list of the enabled locales:
`eselect locale list`

Set the locale to use for the system (number from previous command):
`eselect locale set 4`

Reload the environment:
`env-update && source /etc/profile && export PS1="(chroot) ${PS1}"`

## Configuring the kernel

### Install kernel sources

```
emerge --ask sys-kernel/gentoo-sources
eselect kernel list
eselect kernel set 1
```

### Install firmware and microcode

`emerge --ask sys-kernel/linux-firmware sys-firmware/intel-microcode`

### Configure the kernel

Configure the kernel using the menu and save.
```
cd /usr/src/linux
make menuconfig
```

### Compile and install the kernel

`make -j8 && make modules_install && make install`

Generate initramfs:
```
emerge sys-kernel/dracut
dracut --kver=5.15.74-gentoo --zstd
```

## Create fstab

```
echo "" > /etc/fstab
echo "UUID=$(lsblk -no UUID /dev/nvme0n1p1)" >> /etc/fstab
for i in {1..5}; do echo "UUID=$(lsblk -no UUID /dev/nvme0n1p2)" >> /etc/fstab ; done
```

Located at /etc/fstab:
```
# /dev/nvme0n1p1
UUID=<UUID>     /boot/efi               vfat        noatime     0 2

# /dev/nvme0n1p2 and /dev/nvme1n1p1 in RAIDm1d0
UUID=<UUID>     /                       btrfs       noatime,compress=lzo,ssd,space_cache=v2,subvol=@           0 0
UUID=<UUID>     /home                   btrfs       noatime,compress=lzo,ssd,space_cache=v2,subvol=@home       0 0
UUID=<UUID>     /.snapshots             btrfs       noatime,compress=lzo,ssd,space_cache=v2,subvol=@snapshots  0 0
UUID=<UUID>     /var/db/repos           btrfs       noatime,compress=lzo,ssd,space_cache=v2,subvol=@repos      0 0
UUID=<UUID>     /var/cache/binpkgs      btrfs       noatime,compress=lzo,ssd,space_cache=v2,subvol=@binpkgs    0 0
UUID=<UUID>     /var/cache/distfiles    btrfs       noatime,compress=lzo,ssd,space_cache=v2,subvol=@distfiles  0 0

# tmpfs
tmpfs           /var/tmp/portage        tmpfs       rw,nosuid,noatime,nodev,size=16G,mode=775,uid=portage,gid=portage,x-mount.mkdir=775      0 0
```

## Networking

### Wi-Fi

```
emerge --ask net-wireless/iwd

echo "net-misc/networkmanager iwd" >> /etc/portage/package.use/net
emerge --ask net-misc/networkmanager
```

## System Services

### systemd

```
systemd-firstboot --prompt --setup-machine-id
systemctl preset-all --preset-mode=enable-only
```

### Root Password

`passwd`

### File Indexing

`emerge --ask sys-apps/mlocate`

### Filesystem Tools

`emerge --ask sys-fs/btrfs-progs`

## Bootlader

Using GRUB:
```
echo 'GRUB_PLATFORMS="efi-64"' >> /etc/portage/make.conf
emerge --ask sys-boot/grub sys-boot/os-prober
grub-install --target=x86_64-efi --efi-directory=/boot
grub-mkconfig -o /boot/grub/grub.cfg
```

## Reboot

```
exit
cd
umount -R /mnt/gentoo
reboot
```
