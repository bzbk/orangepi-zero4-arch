#!/bin/bash
set -e
cd "/home/bzbk007/Desktop/OrangePi/OrangePi Zero 4"
rm -rf work/upload3; mkdir -p work/upload3
sha256sum output/arch-tty.img output/arch-fxce.img output/arch-kde.img | tee work/SHA256SUMS.images
for n in tty fxce kde; do
  echo "== compressing $n"
  zstd -12 -T0 -c output/arch-$n.img | split -b 256M -d -a 2 - work/upload3/arch-$n.img.zst.part
  rm -f work/upload3/arch-$n.img.zst
done
cd work/upload3 && sha256sum arch-*.part* > SHA256SUMS.parts && ls -l > ../upload3.sizes
echo RECOMPRESS_DONE
