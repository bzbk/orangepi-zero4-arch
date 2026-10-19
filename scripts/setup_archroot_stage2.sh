#!/bin/bash
export LC_ALL=C
set -x
pacman --disable-sandbox -Syu --noconfirm 2>&1 | tail -8
pacman --disable-sandbox -S --needed --noconfirm openssh sudo vim nano htop networkmanager wpa_supplicant iw dialog dosfstools mtools usbutils pciutils iputils curl wget less which 2>&1 | tail -10
pacman --disable-sandbox -S --needed --noconfirm mkinitcpio 2>&1 | tail -3
echo STAGE2_DONE
