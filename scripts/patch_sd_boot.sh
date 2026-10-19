#!/bin/bash
# 把带 dtb item 的新 bootloader 写入 TF 卡（/dev/sdg），不重烧整个镜像
set -e
DEV="${1:-/dev/sdg}"
NEWPKG="work/uboot-deb-dtb/usr/lib/linux-u-boot-current-orangepizero4_1.0.0_arm64/boot_package.fex"
BOOT0="work/uboot-deb-dtb/usr/lib/linux-u-boot-current-orangepizero4_1.0.0_arm64/boot0_sdcard.fex"
[ -b "$DEV" ] || { echo "错误: $DEV 不存在（先把读卡器接上）"; exit 1; }
echo "目标: $DEV"; lsblk -o NAME,SIZE,TRAN,RM "$DEV"
echo "boot0      : $(sha256sum "$BOOT0" | cut -c1-16) ($(stat -c%s "$BOOT0") B) -> 8KiB"
sudo dd if="$BOOT0" of="$DEV" bs=1k seek=8     conv=notrunc,fsync status=none
echo "boot_package: $(sha256sum "$NEWPKG" | cut -c1-16) ($(stat -c%s "$NEWPKG") B) -> 16400KiB"
sudo dd if="$NEWPKG" of="$DEV" bs=1k seek=16400 conv=notrunc,fsync status=none
sync
echo "写出后校验:"
echo -n "  boot0 区域: "; sudo dd if="$DEV" bs=1k skip=8 count=240 2>/dev/null | sha256sum
echo -n "  pkg   区域: "; sudo dd if="$DEV" bs=1k skip=16400 count=1552 2>/dev/null | head -c $(stat -c%s "$NEWPKG") | sha256sum
echo "完成，把卡插回板子重新上电。"
