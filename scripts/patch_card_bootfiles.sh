#!/bin/bash
# 只替换 TF 卡分区1 里的 /boot/uImage 与 /boot/uInitrd（官方兼容头）
set -e
DEV="${1:-/dev/sdg}"
[ -b "${DEV}1" ] || { echo "错误: ${DEV}1 不存在"; exit 1; }
M=$(mktemp -d); trap 'sudo umount "$M"' EXIT
sudo mount "${DEV}1" "$M"
echo "替换前:"; sudo ls -l "$M/boot/uImage" "$M/boot/uInitrd"
sudo cp work/bootfix/uImage work/bootfix/uInitrd "$M/boot/"
sudo sync
echo "替换后:"; sudo ls -l "$M/boot/uImage" "$M/boot/uInitrd"
echo -n "uImage 头: "; sudo dd if="$M/boot/uImage" bs=1 skip=29 count=2 2>/dev/null | od -An -tx1
echo -n "uInitrd头: "; sudo dd if="$M/boot/uInitrd" bs=1 skip=29 count=2 2>/dev/null | od -An -tx1
