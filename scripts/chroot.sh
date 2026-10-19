#!/bin/bash
# Run a command inside the Ubuntu jammy arm64 build chroot (fake-root via bwrap)
WS="/home/bzbk007/Desktop/OrangePi/OrangePi Zero 4"
ROOTFS="$WS/work/ubuntu-jammy"
export http_proxy=http://127.0.0.1:7897 https_proxy=http://127.0.0.1:7897 DEBIAN_FRONTEND=noninteractive
exec bwrap --unshare-user --uid 0 --gid 0 --cap-add ALL --die-with-parent \
  --bind "$ROOTFS" / \
  --proc /proc --dev /dev --ro-bind /sys /sys \
  --bind "$WS" /opi \
  --tmpfs /tmp \
  --setenv HOME /root --setenv PATH /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
  --chdir /root \
  -- /bin/bash -c "$*"
