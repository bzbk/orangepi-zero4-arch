#!/bin/bash
set -u
export DEBIAN_FRONTEND=noninteractive
apt-get install -y --no-install-recommends file busybox-static xxd 2>&1 | tail -2
# aarch64-linux-gnu-* symlinks at / for the GPU module make (toolchain path empty)
for t in gcc g++ cpp ld ar as nm objcopy objdump ranlib strip readelf size strings addr2line gcov gcc-ar gcc-nm gcc-ranlib ld.bfd; do
  src=/usr/bin/aarch64-linux-gnu-$t
  [ -x "$src" ] && ln -sf "$src" "/aarch64-linux-gnu-$t"
done
# wrap x86_64 pack-uboot tools with qemu
TDIR=/opi/src/opi-build/external/packages/pack-uboot/tools
for f in "$TDIR"/*; do
  [ -f "$f" ] || continue
  case "$f" in *.x86) continue;; esac
  if [ "$(head -c4 "$f" | od -An -tx1 | tr -d ' \n')" = "7f454c46" ]; then
    mach=$(od -An -tu1 -j18 -N1 "$f" | tr -d ' ')
    if [ "$mach" = "62" ]; then
      mv "$f" "$f.x86"
      printf '#!/bin/sh\nexec /usr/bin/qemu-x86_64-static -L /opt/amd64 "%s.x86" "$@"\n' "$f" > "$f"
      chmod +x "$f"
      echo "wrapped $(basename "$f")"
    fi
  fi
done
echo "== test dtc:"; "$TDIR/dtc" --version
echo "== busybox:"; busybox unix2dos 2>&1 | head -1
