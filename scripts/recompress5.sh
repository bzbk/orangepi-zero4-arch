#!/bin/bash
set -e
cd "/home/bzbk007/Desktop/OrangePi/OrangePi Zero 4"
rm -rf work/upload5; mkdir -p work/upload5
sha256sum output/arch-tty.img output/arch-fxce.img output/arch-kde.img | tee work/SHA256SUMS.images
for n in tty fxce kde; do
  echo "== compressing $n"
  zstd -12 -T0 -c output/arch-$n.img | split -b 256M -d -a 2 - work/upload5/arch-$n.img.zst.part
done
cd work/upload5 && sha256sum arch-*.part* > SHA256SUMS.parts && ls -l > ../upload5.sizes
echo RECOMPRESS5_DONE
