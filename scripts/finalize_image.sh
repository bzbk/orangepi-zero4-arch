#!/bin/bash
# 对一个 output/*.img 做最终修复：
# 1) 用官方 boot0/boot_package 覆盖 bootloader 区
# 2) 重新生成有效 initramfs（gzip cpio + TRAILER）
# 3) 用官方参数重建 uImage/uInitrd（arm/0x41000000）
# 4) orangepiEnv verbosity=1
set -e
IMG="$1"; NAME=$(basename "$IMG" .img); MNT=/mnt/fin
[ -f "$IMG" ] || { echo "no image $IMG"; exit 1; }
echo "==== $NAME"
sudo umount "$MNT" 2>/dev/null || true
sudo mkdir -p "$MNT"
sudo mount -o rw,loop,offset=$((65536*512)) "$IMG" "$MNT"
cleanup() { sudo umount "$MNT/proc" "$MNT/dev" "$MNT/sys" "$MNT/run" "$MNT" 2>/dev/null || true; }
trap cleanup EXIT
sudo mount -t proc proc "$MNT/proc"; sudo mount --bind /dev "$MNT/dev"; sudo mount --bind /sys "$MNT/sys"; sudo mount --bind /run "$MNT/run"
echo "-- regenerate initramfs"
sudo chroot "$MNT" /bin/bash -c 'rm -f /boot/initramfs.cpio; mkinitcpio -k 6.6.98-sun60iw2 -z cat -g /boot/initramfs.cpio >/tmp/mki.log 2>&1; gzip -9 -c /boot/initramfs.cpio > /boot/initramfs-linux.img; rm -f /boot/initramfs.cpio; gzip -t /boot/initramfs-linux.img'
sudo cp "$MNT/boot/initramfs-linux.img" work/bootfix/initramfs-linux.img
sudo cp "$MNT/boot/Image" work/bootfix/Image
sudo chown bzbk007:bzbk007 work/bootfix/initramfs-linux.img work/bootfix/Image
echo "-- build uInitrd/uImage"
./work/chroot.sh "cd /opi/work/bootfix && mkimage -A arm -O linux -T ramdisk -C gzip -n initrd -d initramfs-linux.img uInitrd >/dev/null && mkimage -A arm -O linux -T kernel -C none -a 0x41000000 -e 0x41000000 -n Linux-6.6.98-sun60iw2 -d Image uImage >/dev/null"
sudo cp work/bootfix/uInitrd work/bootfix/uImage "$MNT/boot/"
sudo sed -i 's/^verbosity=.*/verbosity=1/' "$MNT/boot/orangepiEnv.txt"
sudo sync
echo "-- patch bootloader region"
sudo dd if=work/official-boot/boot0_sdcard.fex of="$IMG" bs=1k seek=8 conv=notrunc status=none
sudo dd if=work/official-boot/boot_package.fex of="$IMG" bs=1k seek=16400 conv=notrunc status=none
sudo sync
cleanup; trap - EXIT
echo "-- verify"
echo -n "  boot0: "; sudo dd if="$IMG" bs=1k skip=8 count=252 2>/dev/null | sha256sum | cut -c1-16
echo -n "  pkg  : "; sudo dd if="$IMG" bs=1k skip=16400 count=1360 2>/dev/null | sha256sum | cut -c1-16
sudo mount -o ro,loop,offset=$((65536*512)) "$IMG" "$MNT" 2>/dev/null || sudo mount -o ro,loop,offset=$((65536*512)) "$IMG" "$MNT"
sudo python3 - "$MNT" <<"PY"
import sys,subprocess,zlib,os
m=sys.argv[1]
for f in ('uImage','uInitrd'):
    d=open(os.path.join(m,'boot',f),'rb').read(64)
    print(f"  {f}: size={int.from_bytes(d[12:16],'big')} load=0x{int.from_bytes(d[16:20],'big'):x} arch=0x{d[29]:02x} type=0x{d[30]:02x} comp=0x{d[31]:02x}")
d=open(os.path.join(m,'boot','initramfs-linux.img'),'rb').read()
o=zlib.decompressobj(16+zlib.MAX_WBITS); x=o.decompress(d)+o.flush()
print(f"  initramfs: cpio={len(x)} trailing={len(o.unused_data)} TRAILER={x.count(b'TRAILER!!!')}")
print("  env:", open(os.path.join(m,'boot','orangepiEnv.txt')).read().split('\n')[0])
PY
sudo umount "$MNT"
echo "==== $NAME DONE"
