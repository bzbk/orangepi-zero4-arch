#!/bin/bash
set -e
cd "/home/bzbk007/Desktop/OrangePi/OrangePi Zero 4"
rm -rf work/upload6; mkdir -p work/upload6
sha256sum output/arch-tty.img output/arch-fxce.img output/arch-kde.img | tee work/SHA256SUMS.images
for n in tty fxce kde; do
  echo "== compressing $n"
  zstd -12 -T0 -c output/arch-$n.img | split -b 256M -d -a 2 - work/upload6/arch-$n.img.zst.part
done
cd work/upload6 && sha256sum arch-*.part* > SHA256SUMS.parts && ls -l > ../upload6.sizes
echo RECOMPRESS6_DONE
