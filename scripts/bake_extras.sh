#!/bin/bash
# 将 opi-extras (motd/orangepi-config/lcd_set/issue) 烘焙进镜像
set -e
IMG="$1"; MNT=/mnt/bake
[ -f "$IMG" ] || { echo "no image $IMG"; exit 1; }
sudo umount "$MNT" 2>/dev/null || true
sudo mkdir -p "$MNT"
sudo mount -o rw,loop,offset=$((65536*512)) "$IMG" "$MNT"
sudo mkdir -p "$MNT/etc/update-motd.d" "$MNT/etc/default" "$MNT/etc/profile.d" "$MNT/usr/bin"
sudo cp -a work/opi-extras/usr/bin/* "$MNT/usr/bin/"
sudo cp -a work/opi-extras/etc/update-motd.d/* "$MNT/etc/update-motd.d/"
sudo cp -a work/opi-extras/etc/default/orangepi-motd "$MNT/etc/default/"
sudo cp -a work/opi-extras/etc/profile.d/98-orangepi-welcome.sh "$MNT/etc/profile.d/"
sudo cp -a work/opi-extras/etc/issue "$MNT/etc/issue"
sudo chmod 755 "$MNT/usr/bin/orangepi-config" "$MNT/usr/bin/lcd_set" "$MNT"/etc/update-motd.d/* "$MNT/etc/profile.d/98-orangepi-welcome.sh"
sudo chmod 644 "$MNT/etc/issue" "$MNT/etc/default/orangepi-motd"
sudo sync
sudo umount "$MNT"
echo "BAKED $IMG"
