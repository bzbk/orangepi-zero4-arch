#!/bin/bash
# Run a command inside the Arch Linux ARM rootfs (fake-root via bwrap)
WS="/home/bzbk007/Desktop/OrangePi/OrangePi Zero 4"
ROOTFS="${ROOTFS_DIR:-$WS/work/archroot}"
mkdir -p "$WS/work/pkgcache"
exec bwrap --unshare-user --uid 0 --gid 0 --cap-add ALL --die-with-parent \
  --bind "$ROOTFS" / \
  --proc /proc --dev /dev --ro-bind /sys /sys \
  --bind "$WS" /opi \
  --bind "$WS/work/pkgcache" /var/cache/pacman/pkg \
  --tmpfs /tmp \
  --setenv HOME /root --setenv PATH /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
  --setenv LC_ALL C --setenv LANG C \
  --chdir /root \
  -- /bin/bash -c "$*"
