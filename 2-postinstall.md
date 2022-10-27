# Post-Install

## Cnnect to wireless

```
systemctl enable --now iwd
iwctl
station wlan0 scan
station wlan0 connect "<ssid>"
```

## Time Syncronization

```
systemctl enable --now systemd-timesyncd.service
timedatectl set-ntp true 
```

## Install packages

```
emerge -a app-shells/zsh app-admin/sudo app-editors/vim dev-vcs/git app-portage/eix
```

## Create user

```
useradd -m -G users,wheel,audio -s /bin/zsh stephen
passwd stephen
```

Login as user.

## Configure BTRFS

```
sudo emerge -a app-backup/snapper
sudo umount /.snapshots
sudo rmdir /.snapshots
sudo snapper -c root create-config /
sudo btrfs subvolume delete /.snapshots
sudo mkdir /.snapshots
sudo mount -a
echo 'SUSE_BTRFS_SNAPSHOT_BOOTING="true" | sudo tee -a /etc/default/grub

sudo emerge app-eselect/eselect-repository
sudo eselect repository enable guru
sudo emerge --sync
sudo emerge grub-btrfs

sudo grub-mkconfig -o /boot/grub/grub.cfg

sudo snapper -c root set-config ALLOW_USERS=$USER SYNC_ACL=yes
sudo chown -R :$USER /.snapshots
```