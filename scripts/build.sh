#!/bin/bash
# wrapper: run orangepi-build inside the Ubuntu jammy arm64 chroot
WS="/home/bzbk007/Desktop/OrangePi/OrangePi Zero 4"
mkdir -p "$WS/work/tmp"
exec bwrap --unshare-user --uid 0 --gid 0 --cap-add ALL --die-with-parent \
  --bind "$WS/work/ubuntu-jammy" / \
  --proc /proc --dev /dev --ro-bind /sys /sys \
  --bind "$WS" /opi \
  --bind "$WS/work/tmp" /tmp \
  --setenv HOME /root --setenv PATH /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
  --setenv LC_ALL C --setenv LANG C \
  --chdir /opi/src/opi-build \
  -- /bin/bash -c 'cd /opi/src/opi-build && ./build.sh zero4 '"$*"' 2>&1 | tee -a /opi/work/build.log'
