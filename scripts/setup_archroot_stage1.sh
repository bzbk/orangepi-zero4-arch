#!/bin/bash
set -x
export LC_ALL=C
pacman-key --init 2>&1 | tail -2
pacman-key --populate archlinuxarm 2>&1 | tail -3
pacman -Syu --noconfirm 2>&1 | tail -15
