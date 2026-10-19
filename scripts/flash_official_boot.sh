#!/bin/bash
# 把官方 Zero4 bootloader 写入 TF 卡（/dev/sdg），带严格校验
set -e
B0="work/official-boot/boot0_sdcard.fex"
PKG="work/official-boot/boot_package.fex"
DEV="${1:-/dev/sdg}"
[ -b "$DEV" ] || { echo "错误: $DEV 不是块设备（读卡器没插好）"; exit 1; }
[ -f "$B0" ] && [ -f "$PKG" ] || { echo "缺少官方 bootloader 文件"; exit 1; }
B0SZ=$(stat -c%s "$B0"); PKGSZ=$(stat -c%s "$PKG")
echo "boot0      : $B0  ($B0SZ B)  头 length=0x$(python3 -c "import struct;d=open('$B0','rb').read();print('%x'%struct.unpack('<I',d[16:20])[0])")"
echo "boot_package: $PKG ($PKGSZ B)"
[ "$B0SZ" = "258048" ] || { echo "错误: boot0 应为 258048 字节"; exit 1; }
lsblk -o NAME,SIZE,TRAN,RM,MODEL "$DEV"
read -p "确认写入 $DEV ? (yes/no) " ans; [ "$ans" = "yes" ] || exit 1
dd if="$B0"  of="$DEV" bs=1k seek=8     conv=notrunc,fsync status=none
dd if="$PKG" of="$DEV" bs=1k seek=16400 conv=notrunc,fsync status=none
sync
echo "--- 回读校验:"
echo -n "boot0: "; dd if="$DEV" bs=1k skip=8     count=252  2>/dev/null | sha256sum | cut -c1-16
echo -n "expect: "; sha256sum "$B0" | cut -c1-16
echo -n "pkg  : "; dd if="$DEV" bs=1k skip=16400 count=1360 2>/dev/null | sha256sum | cut -c1-16
echo -n "expect: "; sha256sum "$PKG" | cut -c1-16
echo "--- rootfs 分区检查:"
mkdir -p /tmp/opisdchk
if mount -o ro "${DEV}p1" /tmp/opisdchk 2>/dev/null; then
  echo -n "hostname: "; cat /tmp/opisdchk/etc/hostname
  echo -n "dtb sha256: "; sha256sum /tmp/opisdchk/boot/dtb/allwinner/sun60i-a733-orangepi-zero4.dtb | cut -c1-16
  umount /tmp/opisdchk
else
  echo "无法挂载 ${DEV}p1"
fi
echo "DONE"
