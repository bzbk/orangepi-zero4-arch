#!/bin/bash
# 将官方对齐的 MOTD/设备名/工具烘焙进镜像
set -e
IMG="$1"; MNT=/mnt/bake
[ -f "$IMG" ] || { echo "no image $IMG"; exit 1; }
sudo umount "$MNT" 2>/dev/null || true
sudo mkdir -p "$MNT"
sudo mount -o rw,loop,offset=$((65536*512)) "$IMG" "$MNT"
cleanup() { sudo umount "$MNT/proc" "$MNT/dev" "$MNT/sys" "$MNT/run" 2>/dev/null || true; sudo umount "$MNT" 2>/dev/null || true; }
trap cleanup EXIT
# 1) 复制官方对齐的文件
sudo mkdir -p "$MNT/etc/update-motd.d" "$MNT/etc/default" "$MNT/etc/profile.d" "$MNT/usr/share/orangepi" "$MNT/usr/bin"
sudo cp -f work/opi-extras2/etc/update-motd.d/* "$MNT/etc/update-motd.d/"
sudo cp -f work/opi-extras2/etc/orangepi-release "$MNT/etc/orangepi-release"
sudo cp -f work/opi-extras2/etc/issue "$MNT/etc/issue"
sudo cp -f work/opi-extras2/etc/default/orangepi-motd "$MNT/etc/default/orangepi-motd"
sudo cp -f work/opi-extras2/etc/profile.d/98-orangepi-welcome.sh "$MNT/etc/profile.d/"
sudo cp -f work/opi-extras2/usr/share/orangepi/orangepi-ascii "$MNT/usr/share/orangepi/"
sudo cp -f work/opi-extras2/usr/bin/orangepi-config work/opi-extras2/usr/bin/lcd_set "$MNT/usr/bin/"
sudo chmod 755 "$MNT"/etc/update-motd.d/* "$MNT/etc/profile.d/98-orangepi-welcome.sh" "$MNT/usr/bin/orangepi-config" "$MNT/usr/bin/lcd_set"
sudo chmod 644 "$MNT/etc/orangepi-release" "$MNT/etc/issue" "$MNT/etc/default/orangepi-motd" "$MNT/usr/share/orangepi/orangepi-ascii"
# 2) 设备名对齐
printf 'orangepizero4\n' | sudo tee "$MNT/etc/hostname" >/dev/null
if sudo grep -q "^127.0.1.1" "$MNT/etc/hosts"; then
  sudo sed -i 's/^127\.0\.1\.1.*/127.0.1.1   orangepizero4/' "$MNT/etc/hosts"
else
  printf '127.0.1.1   orangepizero4\n' | sudo tee -a "$MNT/etc/hosts" >/dev/null
fi
# 3) pacman DisableSandbox
sudo grep -q "^DisableSandbox" "$MNT/etc/pacman.conf" || sudo sed -i "/^\[options\]/a DisableSandbox" "$MNT/etc/pacman.conf"
# 4) 安装 MOTD 依赖 bc（chroot pacman）
sudo mount -t proc proc "$MNT/proc"; sudo mount --bind /dev "$MNT/dev"; sudo mount --bind /sys "$MNT/sys"; sudo mount --bind /run "$MNT/run"
sudo cp -f /etc/resolv.conf "$MNT/etc/resolv.conf" 2>/dev/null || true
sudo chroot "$MNT" /bin/bash -c 'pacman -S --noconfirm --needed bc inetutils >/tmp/pacman-extras.log 2>&1 || echo "pacman extra install failed (non fatal)"' || true
sudo sync
cleanup; trap - EXIT
echo "BAKED $IMG"
