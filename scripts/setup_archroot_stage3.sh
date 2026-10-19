#!/bin/bash
export LC_ALL=C
set -x
# 1. restore setuid/setgid bits lost during non-root extraction
chmod 4755 /usr/bin/chfn /usr/bin/chage /usr/bin/mount /usr/bin/newgrp /usr/bin/chsh /usr/bin/passwd /usr/bin/ksu /usr/bin/gpasswd /usr/bin/umount /usr/bin/su
chmod 2755 /usr/bin/write /usr/bin/wall
chmod 6755 /usr/bin/unix_chkpwd
chmod 4110 /usr/lib/dbus-daemon-launch-helper 2>/dev/null || true
chmod 4711 /usr/lib/ssh/ssh-keysign 2>/dev/null || true
chmod 2755 /var/log/journal /var/lib/libuuid /var/lib/tpm2-tss/system/keystore 2>/dev/null || true
# also fix setuid bits of packages installed later (sudo etc.)
for f in /usr/bin/sudo /usr/bin/sudoedit /usr/bin/passwd /usr/bin/mount /usr/bin/umount /usr/bin/su; do [ -f "$f" ] && chmod 4755 "$f"; done
chmod 4755 /usr/lib/sudo/sudoers.so 2>/dev/null || true
# 2. hostname / timezone / locale
echo orangepizero4 > /etc/hostname
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
echo "Asia/Shanghai" > /etc/timezone
sed -i 's/^#en_US.UTF-8/en_US.UTF-8/; s/^#zh_CN.UTF-8/zh_CN.UTF-8/' /etc/locale.gen
locale-gen
# 3. passwords and user
echo 'root:orangepi' | chpasswd
id orangepi >/dev/null 2>&1 || useradd -m -G wheel -s /bin/bash orangepi
echo 'orangepi:orangepi' | chpasswd
echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/10-wheel
chmod 440 /etc/sudoers.d/10-wheel
# 4. enable services
systemctl enable NetworkManager 2>&1 | tail -1
systemctl enable sshd 2>&1 | tail -1
systemctl enable systemd-timesyncd 2>&1 | tail -1
systemctl enable serial-getty@ttyS0 2>&1 | tail -1
systemctl set-default multi-user.target 2>&1 | tail -1
# 5. firmware (aic8800 wifi/bt etc.)
mkdir -p /lib/firmware
cp -a /opi/work/orangepi-firmware/. /lib/firmware/
# 6. boot dir skeleton
mkdir -p /boot/dtb/allwinner
# 7. clean pacman cache to keep image small
pacman --disable-sandbox -Scc --noconfirm 2>&1 | tail -2
echo STAGE3_DONE
