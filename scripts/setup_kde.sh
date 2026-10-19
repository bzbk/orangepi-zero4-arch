#!/bin/bash
export LC_ALL=C
set -x
pacman --disable-sandbox -S --needed --noconfirm \
  xorg-server xorg-xinit xf86-input-libinput xf86-video-fbdev mesa \
  plasma sddm plasma-nm polkit xdg-utils xdg-desktop-portal xdg-desktop-portal-kde \
  noto-fonts noto-fonts-cjk xdg-user-dirs \
  pipewire pipewire-pulse wireplumber 2>&1 | tail -6
systemctl enable sddm 2>&1 | tail -1
systemctl set-default graphical.target 2>&1 | tail -1
systemctl mask getty@tty1 2>&1 | tail -1
echo KDE_DONE
