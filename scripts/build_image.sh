#!/bin/bash
# Assemble Orange Pi Zero 4 Arch Linux image from built kernel/u-boot artifacts
set -euo pipefail
WS="/home/bzbk007/Desktop/OrangePi/OrangePi Zero 4"
cd "$WS"
# 变体参数：VARIANT=arch-tty/arch-fxce/arch-kde，ROOTFS_DIR=对应 rootfs
VARIANT="${VARIANT:-arch-tty}"
ARCHROOT="${ROOTFS_DIR:-work/archroot}"
# 允许传绝对路径（转为工作区内相对路径，便于 chroot 内使用 /opi/...）
[[ "$ARCHROOT" = /* ]] && ARCHROOT="${ARCHROOT#"$WS"/}"
mkdir -p work/out
UBOOT_FEX_DIR=$(echo work/uboot-deb/usr/lib/linux-u-boot-current-orangepizero4_*_arm64)
DEBS="src/opi-build/output/debs"

echo "=== [1/7] extract kernel debs"
IMG_DEB=$(ls "$DEBS"/linux-image-current-sun60iw2_*.deb | head -1)
DTB_DEB=$(ls "$DEBS"/linux-dtb-current-sun60iw2_*.deb | head -1)
rm -rf work/kdeb-image work/kdeb-dtb
mkdir -p work/kdeb-image work/kdeb-dtb
./work/chroot.sh "dpkg-deb -x /opi/$IMG_DEB /opi/work/kdeb-image && dpkg-deb -x /opi/$DTB_DEB /opi/work/kdeb-dtb" >/dev/null
KVER=$(ls "$ARCHROOT"/lib/modules 2>/dev/null | head -1 || true)
[ -n "$KVER" ] || KVER=$(ls work/kdeb-image/lib/modules | head -1)
echo "kernel version: $KVER"

# 补全 systemd 系统用户/组（dbus、lightdm、sddm 等），确保镜像内账号完整
./work/arch-chroot.sh 'systemd-sysusers >/dev/null 2>&1; true' >/dev/null 2>&1 || true

echo "=== [2/7] install modules and dtbs"
rm -rf "$ARCHROOT/lib/modules/$KVER"
mkdir -p "$ARCHROOT/lib/modules" "$ARCHROOT/boot/dtb/allwinner" "$ARCHROOT/boot/dtb/allwinner/overlay"
cp -a work/kdeb-image/lib/modules/"$KVER" "$ARCHROOT/lib/modules/" || {
  cp -a work/kdeb-image/lib/modules/. "$ARCHROOT/lib/modules/"; }
# kernel image
KIMG=$(find work/kdeb-image/boot -maxdepth 1 -name 'Image*' | head -1 || true)
[ -n "${KIMG:-}" ] || KIMG=$(find work/kdeb-image -name 'vmlinuz*' | head -1 || true)
[ -n "${KIMG:-}" ] || KIMG="output/packages/Image-6.6.98-sun60iw2"
if [ -f "$KIMG" ]; then
  cp "$KIMG" "$ARCHROOT/boot/Image"
elif [ -f "$ARCHROOT/boot/Image" ]; then
  echo "kernel Image 已存在于 rootfs，沿用"
else
  echo "ERROR: kernel Image not found" >&2; exit 1
fi
# dtbs
find work/kdeb-dtb -name '*.dtb' -exec cp -a {} "$ARCHROOT/boot/dtb/allwinner/" \;
find work/kdeb-dtb -name '*.dtbo' -exec cp -a {} "$ARCHROOT/boot/dtb/allwinner/overlay/" \; 2>/dev/null || true
ls "$ARCHROOT/boot/dtb/allwinner/" | grep -i zero4

echo "=== [3/7] boot files (boot.scr/uImage/orangepiEnv.txt)"
UUID=$(python3 -c 'import uuid; print(uuid.uuid4())')
echo "root UUID: $UUID"
cp src/opi-build/external/config/bootscripts/boot-sun60iw2.cmd work/boot.cmd
# orangepiEnv.txt：与 orangepi-build 正常出镜像时的写法保持一致
#   external/config/bootenv/sun60iw2.txt
#   + rootdev / rootfstype  (debootstrap.sh)
#   + overlay_prefix / fdtfile (distributions.sh + board conf BOOT_FDT_FILE)
{
  cat src/opi-build/external/config/bootenv/sun60iw2.txt
  echo "rootdev=UUID=$UUID"
  echo "rootfstype=ext4"
  echo "overlay_prefix=sun60i-a733"
  echo "fdtfile=allwinner/sun60i-a733-orangepi-zero4.dtb"
} > "$ARCHROOT/boot/orangepiEnv.txt"
./work/chroot.sh "cd /opi/work && mkimage -C none -A arm -T script -d /opi/work/boot.cmd /opi/$ARCHROOT/boot/boot.scr >/dev/null && mkimage -A arm -O linux -T kernel -C none -a 0x41000000 -e 0x41000000 -n Linux-6.6.98-sun60iw2 -d /opi/$ARCHROOT/boot/Image /opi/$ARCHROOT/boot/uImage >/dev/null" >/dev/null
echo "boot.scr/uImage created"

echo "=== [4/7] initramfs (depmod + mkinitcpio)"
./work/arch-chroot.sh "depmod -a $KVER && rm -f /boot/initramfs-linux.img && mkinitcpio -k $KVER -g /boot/initramfs-linux.img 2>&1 | tail -3"
# ensure gzip compression (mkinitcpio may emit plain cpio in this chroot)
./work/arch-chroot.sh 'if gzip -t /boot/initramfs-linux.img 2>/dev/null; then echo "initramfs already gzip"; else gzip -9 -c /boot/initramfs-linux.img > /tmp/ir.gz && mv /tmp/ir.gz /boot/initramfs-linux.img && echo "initramfs gzipped"; fi; file /boot/initramfs-linux.img'
./work/chroot.sh "mkimage -A arm -O linux -T ramdisk -C gzip -n initrd -d /opi/$ARCHROOT/boot/initramfs-linux.img /opi/$ARCHROOT/boot/uInitrd >/dev/null" >/dev/null
ls -lh "$ARCHROOT/boot/"

echo "=== [5/7] fstab"
cat > "$ARCHROOT/etc/fstab" <<EOF
UUID=$UUID / ext4 defaults,noatime 0 1
EOF
echo "root UUID: $UUID"

echo "=== [5.5/7] first boot auto-resize service"
# 首次开机把根分区/文件系统扩展到整张 TF 卡或 eMMC（见 work/firstboot/）
install -D -m 0755 work/firstboot/opi-firstboot-resize.sh "$ARCHROOT/usr/local/sbin/opi-firstboot-resize"
install -D -m 0644 work/firstboot/opi-firstboot-resize.service "$ARCHROOT/etc/systemd/system/opi-firstboot-resize.service"
mkdir -p "$ARCHROOT/etc/systemd/system/multi-user.target.wants"
ln -sfn /etc/systemd/system/opi-firstboot-resize.service \
  "$ARCHROOT/etc/systemd/system/multi-user.target.wants/opi-firstboot-resize.service"
echo "firstboot auto-resize enabled"

echo "=== [6/7] create image"
ROOT_MB=$(du -sm "$ARCHROOT" 2>/dev/null | cut -f1) || ROOT_MB=3000
PART_MB=$((ROOT_MB + 1280))
TOTAL_MB=$((PART_MB + 32))
IMG=work/out/${VARIANT}.img
rm -f "$IMG" work/part1.ext4
truncate -s ${TOTAL_MB}M "$IMG"
printf 'label: dos\nstart=32MiB, type=83\n' | sfdisk -q "$IMG"
truncate -s ${PART_MB}M work/part1.ext4
# mke2fs inside the fake-root chroot so files are owned by uid 0 in the image
./work/chroot.sh "mke2fs -q -t ext4 -L opi_root -m 2 -O ^64bit,^metadata_csum -U $UUID -d /opi/$ARCHROOT /opi/work/part1.ext4"
# 修正 dbus 帮助程序的属组/权限（fake-root 下无法 chown 到 messagebus 组，用 debugfs 直接写 inode）
DBUS_GID=$(awk -F: '$1=="dbus"{print $3}' "$ARCHROOT/etc/group")
if [ -n "$DBUS_GID" ]; then
  ./work/chroot.sh "debugfs -w -R 'sif /usr/lib/dbus-daemon-launch-helper gid $DBUS_GID' /opi/work/part1.ext4 >/dev/null 2>&1; debugfs -w -R 'sif /usr/lib/dbus-daemon-launch-helper mode 0104110' /opi/work/part1.ext4 >/dev/null 2>&1" >/dev/null || true
  echo "dbus helper -> gid $DBUS_GID mode 4110"
fi
dd if=work/part1.ext4 of="$IMG" bs=1M seek=32 conv=notrunc status=none
dd if="$UBOOT_FEX_DIR/boot0_sdcard.fex" of="$IMG" bs=1k seek=8 conv=notrunc status=none
dd if="$UBOOT_FEX_DIR/boot_package.fex" of="$IMG" bs=1k seek=16400 conv=notrunc status=none
# 标记分区 1 为 active（MBR 启动标志，便于部分工具识别）
printf '\x80' | dd of="$IMG" bs=1 seek=446 conv=notrunc status=none
sync

echo "=== [7/7] verify"
sfdisk -l "$IMG"
echo "--- sha256"
sha256sum "$IMG" | tee "$IMG.sha256"
ls -lh "$IMG"
echo IMAGE_DONE
