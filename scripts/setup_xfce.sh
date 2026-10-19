#!/bin/bash
export LC_ALL=C
set -x
pacman --disable-sandbox -S --needed --noconfirm \
  xorg-server xorg-xinit xf86-input-libinput xf86-video-fbdev mesa \
  xfce4 xfce4-goodies xfce4-terminal lightdm lightdm-gtk-greeter network-manager-applet \
  polkit xdg-utils \
  noto-fonts noto-fonts-cjk xdg-user-dirs \
  pipewire pipewire-pulse wireplumber 2>&1 | tail -6
mkdir -p /etc/lightdm/lightdm.conf.d
cat > /etc/lightdm/lightdm.conf.d/50-opi.conf <<'CFG'
[Seat:*]
greeter-session=lightdm-gtk-greeter
user-session=xfce
CFG
systemctl enable lightdm 2>&1 | tail -1
systemctl set-default graphical.target 2>&1 | tail -1
systemctl mask getty@tty1 2>&1 | tail -1
echo XFCE_DONE
