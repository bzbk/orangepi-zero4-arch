#!/bin/bash
# 将“官方原版”配置工具/MOTD/设备名烘焙进镜像（Arch 兼容层）
set -e
IMG="$1"; MNT=/mnt/bake
[ -f "$IMG" ] || { echo "no image $IMG"; exit 1; }
sudo umount "$MNT" 2>/dev/null || true
sudo mkdir -p "$MNT"
sudo mount -o rw,loop,offset=$((65536*512)) "$IMG" "$MNT"
cleanup() { sudo umount "$MNT/proc" "$MNT/dev" "$MNT/sys" "$MNT/run" 2>/dev/null || true; sudo umount "$MNT" 2>/dev/null || true; }
trap cleanup EXIT
sudo mount -t proc proc "$MNT/proc"; sudo mount --bind /dev "$MNT/dev"; sudo mount --bind /sys "$MNT/sys"; sudo mount --bind /run "$MNT/run"
sudo cp -f /etc/resolv.conf "$MNT/etc/resolv.conf" 2>/dev/null || true
# 1) 安装官方脚本依赖
sudo chroot "$MNT" /bin/bash -c 'pacman -S --noconfirm --needed toilet figlet run-parts dialog git lsb-release bc inetutils >/tmp/pacman-officialdeps.log 2>&1 || echo "pacman deps partial failure"'
# 2) 清理自定义实现
sudo rm -f "$MNT/usr/bin/lcd_set" "$MNT/usr/bin/orangepi-config" "$MNT/etc/profile.d/98-orangepi-welcome.sh" "$MNT/etc/update-motd.d/orangepi-ascii"
sudo rm -rf "$MNT/usr/share/orangepi"
# 3) 官方原版文件
sudo mkdir -p "$MNT/usr/lib/orangepi-config" "$MNT/usr/local/bin" "$MNT/usr/local/sbin" "$MNT/etc/update-motd.d" "$MNT/etc/default"
sudo cp -f work/opi-extras3/usr/sbin/orangepi-config "$MNT/usr/bin/orangepi-config"
sudo cp -f work/opi-extras3/usr/lib/orangepi-config/*.sh "$MNT/usr/lib/orangepi-config/"
sudo cp -f work/opi-extras3/usr/local/bin/* "$MNT/usr/local/bin/"
sudo cp -f work/opi-extras3/usr/local/sbin/opi-update-motd "$MNT/usr/local/sbin/"
sudo cp -f work/opi-extras3/etc/update-motd.d/* "$MNT/etc/update-motd.d/"
sudo cp -f work/opi-extras3/etc/orangepi-release "$MNT/etc/orangepi-release"
sudo cp -f work/opi-extras3/etc/issue "$MNT/etc/issue"
sudo cp -f work/opi-extras3/etc/default/orangepi-motd "$MNT/etc/default/orangepi-motd"
sudo chmod 755 "$MNT/usr/bin/orangepi-config" "$MNT"/usr/local/bin/* "$MNT/usr/local/sbin/opi-update-motd" "$MNT"/etc/update-motd.d/*
sudo chmod 644 "$MNT/etc/orangepi-release" "$MNT/etc/issue" "$MNT/etc/default/orangepi-motd"
# 4) figlet 字体扁平化符号链接（toilet 需要 /usr/share/figlet/standard.flf）
sudo chroot "$MNT" /bin/bash -c 'cd /usr/share/figlet && for f in fonts/*.flf; do b=$(basename "$f"); [ -e "$b" ] || ln -sf "fonts/$b" "$b"; done' || true
# 5) 设备名对齐
printf 'orangepizero4\n' | sudo tee "$MNT/etc/hostname" >/dev/null
if sudo grep -q '^127.0.1.1' "$MNT/etc/hosts"; then
  sudo sed -i 's/^127\.0\.1\.1.*/127.0.1.1   orangepizero4/' "$MNT/etc/hosts"
else
  printf '127.0.1.1   orangepizero4\n' | sudo tee -a "$MNT/etc/hosts" >/dev/null
fi
# 6) PAM: 官方动态 motd 逻辑（pam_exec 生成 + pam_motd 显示）
sudo grep -q 'opi-update-motd' "$MNT/etc/pam.d/system-login" || sudo sed -i '/pam_motd.so/i session    optional   pam_exec.so quiet /usr/local/sbin/opi-update-motd' "$MNT/etc/pam.d/system-login"
sudo grep -q 'motd=/run/motd.dynamic' "$MNT/etc/pam.d/system-login" || sudo sed -i '/pam_motd.so$/i session    optional   pam_motd.so motd=/run/motd.dynamic' "$MNT/etc/pam.d/system-login"
# 7) pacman DisableSandbox
sudo grep -q '^DisableSandbox' "$MNT/etc/pacman.conf" || sudo sed -i '/^\[options\]/a DisableSandbox' "$MNT/etc/pacman.conf"
sudo sync
cleanup; trap - EXIT
echo "BAKED3 $IMG"
