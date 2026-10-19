# 构建记录（BUILD-INFO）

## 1. 构建主机

| 项 | 值 |
|---|---|
| 主机 | Xiaomi Pad 6 (pipa, SM8250)，**Arch Linux ARM aarch64** |
| 内核 | 6.15.11-5-pipa-alarm |
| CPU / 内存 | 8 核 / 7.4 GiB（内核 `CTHREADS=-j6`） |
| 编译方式 | 无 root：`bubblewrap` 提供 user+mount namespace 伪 root；Ubuntu 22.04 **arm64** base rootfs 作为构建 chroot；userns 使 `chown 0` 有效 |
| 关键工具 | gcc 11.4 (Ubuntu jammy，native aarch64)、`aarch64-linux-gnu-gcc`、`arm-linux-gnueabi-gcc`、`qemu-x86_64-static`、`dtc`、`mkimage`、ccache |
| 网络 | 本地 Clash 代理用于 GitHub；腾讯云/南大/阿里云镜像用于 ArchLinuxARM；阿里云用于 Ubuntu ports / base |

## 2. 源码与版本

| 组件 | 来源 | 版本 / 提交 |
|---|---|---|
| 构建脚本 | `https://github.com/orangepi-xunlong/orangepi-build` | `a05b3b4d5fc0dd4eb859f64c8a60f9b2c9e33cb1` — "Support OrangePi Zero4" |
| 内核 | `https://github.com/orangepi-xunlong/linux-orangepi` 分支 `orange-pi-6.6-sun60iw2` | Linux **6.6.98**，`LOCALVERSION=-sun60iw2` |
| U-Boot | `https://gitee.com/orangepi-xunlong/u-boot-orangepi` 分支 `v2018.05-sun60iw2` | `baff742` "Support OrangePi 4 Pro"（32-bit ARM vendor U-Boot） |
| 内核配置 | `external/config/kernel/linux-sun60iw2-current-a733.config` | — |
| 设备树 | 内核树 `arch/arm64/boot/dts/allwinner/sun60i-a733-orangepi-zero4.dts` | `sun60i-a733-orangepi-zero4.dtb` |
| Arch rootfs | `ArchLinuxARM-aarch64-latest.tar.gz`（aliyun 镜像，2026-08-05） | 随后 `pacman -Syu` 至最新 |
| 固件 | `https://github.com/orangepi-xunlong/firmware` 分支 `master` | 含 `aic8800d80/*` |

## 3. U-Boot / 内核构建命令（Ubuntu jammy arm64 chroot 内）

```bash
cd /opi/src/opi-build
./build.sh zero4 BUILD_OPT=u-boot
./build.sh zero4 BUILD_OPT=kernel CTHREADS=-j6      # 约 32 分钟
```

`userpatches/config-zero4.conf`（见 `build-scripts/`）：`BOARD=orangepizero4`、`BRANCH=current`、`KERNEL_CONFIGURE=no`、`BUILD_KSRC=no`、`IGNORE_UPDATES=yes`、`KERNELDIR=/opi/src/kernel-src`、`BOOTDIR=/opi/src/uboot-src`。

## 4. 为在 aarch64 构建主机上跑通而做的适配

1. `sun60iw2.conf`：`uboot_custom_postprocess()` 去掉 `dpkg --print-architecture == amd64` 限制；
2. Allwinner 打包工具是 x86-64 ELF：每个工具改名 `*.x86` + shell wrapper `qemu-x86_64-static -L /opt/amd64`（amd64 base rootfs 提供 glibc/ld.so）；
3. U-Boot 源码树自带 x86 `scripts/dtc/dtc` → 换成系统 `dtc` 的 wrapper；
4. 老 U-Boot + GCC 11：`arm-linux-gnueabi-gcc` wrapper 追加 `-Wno-error -fcommon -Wno-attributes -Wno-address-of-packed-member -Wno-array-bounds -Wno-stringop-overflow -Wno-maybe-uninitialized`；
5. `scripts/general.sh` hostdeps 移除在 userns 下无法配置的 `dbus`、`imagemagick`、`nfs-kernel-server`、`systemd-container`；
6. GPU 模块 `CROSS_COMPILE=/aarch64-linux-gnu-`：在 chroot 根建 `/aarch64-linux-gnu-*` 符号链接；
7. apt `APT::Sandbox::User "root"`；pacman 需要 `--disable-sandbox`（userns 内 `setgroups` 不可用）；
8. chroot 内用 `/usr/local/bin/sudo` 直通脚本替代 sudo。

## 5. 镜像组装（`build-scripts/build_image.sh`）

1. 从 deb 取 `/lib/modules/6.6.98-sun60iw2`、dtb；内核 `Image` 取自构建产物（vendor deb 未打包 Image，已另存 `output/packages/Image-6.6.98-sun60iw2`）；
2. `/boot`：`Image`、`uImage`、`uInitrd`、`boot.scr`（由 `boot-sun60iw2.cmd` + mkimage）、`orangepiEnv.txt`、`dtb/allwinner/sun60i-a733-orangepi-zero4.dtb`；
3. `orangepiEnv.txt` 与上游出镜像逻辑一致：`bootenv/sun60iw2.txt` + `rootdev=UUID=<fs uuid>` + `rootfstype=ext4` + `overlay_prefix=sun60i-a733` + `fdtfile=allwinner/sun60i-a733-orangepi-zero4.dtb`；
4. `depmod -a` + `mkinitcpio -k 6.6.98-sun60iw2`（HOOKS=`base udev modconf block filesystems fsck`；chroot 内 mkinitcpio 输出未压缩 cpio，脚本显式 `gzip -9` 后再 `mkimage -T ramdisk -C gzip` 生成 `uInitrd`）；
5. ext4 UUID **先生成**，写入 `/etc/fstab` 与 `orangepiEnv.txt`；
6. `truncate` 镜像 → `sfdisk` MBR（分区 1 起于 32 MiB）→ 伪 root chroot 内 `mke2fs -d <rootfs>`（保证镜像内属主 root）→ `dd` 分区到 32 MiB → `dd boot0_sdcard.fex` 到 8 KiB、`boot_package.fex` 到 16400 KiB → MBR 分区 active；
7. 用 `debugfs` 直接修正 fake-root 下无法 `chown` 的属组/属主：
   - `/usr/lib/dbus-daemon-launch-helper` → `root:dbus(81)`、mode `04110`（含 S_IFREG 位）；
   - KDE 镜像 `/var/lib/sddm` → `sddm:sddm(963:963)`、0750；
   - XFCE 镜像 `/var/lib/lightdm`、`/var/lib/lightdm-data` → `lightdm:lightdm(965:965)`。
8. `sha256sum`。

### 5.1 设备树一致性核查

- **构建链**：`sun60i-a733-orangepi-zero4.dts` → `.dtb` → `linux-dtb` deb → rootfs → 镜像内，SHA256 全部相同：
  `8d4dab3ad26b63a1f9af29f99f21b2115ed8431125ec17dbd9e664048802bfec`（DTC 确定性输出）。
- **启动链**：board conf `BOOT_FDT_FILE` → `/boot/orangepiEnv.txt:fdtfile` → `boot.scr` 的 `load ... dtb/${fdtfile}`；U-Boot distro boot `boot_prefixes="/ /boot/"`、`boot_scripts="boot.scr"`；`boot.scr` payload 与 `boot-sun60iw2.cmd` 逐字节一致。
- **内容归属**：与 `sun60i-a733-orangepi-4-pro.dts` 差 688 行，与 `sun60i-a733-orangepi-zero3w.dts` 仅差 73 行（PWM 引脚 `PB4→PD0`、IR RX `PL4→PL6`、风扇 PWM 通道、`pwm0_5/0_6` 互换），确为 Zero4 专用。
- **上游瑕疵（无功能影响）**：vendor 三个 board DTS 的 `compatible` 均写 `"xunlong,orangepi-4-pro"`、`model="sun60iw2"`；内核树内无代码依赖该字符串，仅 `/proc/device-tree/compatible` 显示为 4 Pro。
- **U-Boot 层**：SoC 级 DT（`u-boot-current.dts`，compatible `allwinner,t736`）+ Zero4 的 DRAM blobs（复用 `boot0_sdcard_orangepizero3w.fex`，与仓库文件 SHA256 一致 `829ea8e3…`）+ 通用 `sys_config.fex`——`sun60iw2.conf` 对 `BOARD == orangepizero4` 的上游显式逻辑。

## 5.2 三种镜像变体

| 变体 | rootfs 构建 | 桌面/服务 |
|---|---|---|
| `arch-tty` | 基础 rootfs | 无桌面；`sshd`、`NetworkManager`、`avahi` |
| `arch-fxce` | 基础 rootfs 复制 + `pacman -S xorg-server xorg-xinit xf86-input-libinput xf86-video-fbdev mesa xfce4 xfce4-goodies xfce4-terminal lightdm lightdm-gtk-greeter network-manager-applet polkit xdg-utils noto-fonts noto-fonts-cjk xdg-user-dirs pipewire pipewire-pulse wireplumber` | `systemctl enable lightdm`、`set-default graphical.target`、mask `getty@tty1`；`/etc/lightdm/lightdm.conf.d/50-opi.conf`（greeter=lightdm-gtk-greeter, user-session=xfce） |
| `arch-kde` | 基础 rootfs 复制 + 上述 Xorg/mesa 基础包 + `plasma sddm plasma-nm plasma-x11-session polkit xdg-utils xdg-desktop-portal xdg-desktop-portal-kde noto-fonts noto-fonts-cjk xdg-user-dirs pipewire pipewire-pulse wireplumber` | `systemctl enable sddm`、`set-default graphical.target`、mask `getty@tty1`；`/etc/sddm.conf.d/10-opi.conf`（`DefaultSession=plasmax11.desktop`） |

公共基础 rootfs 预置：

```
/etc/NetworkManager/system-connections/OrangePi.nmconnection   # SSID=OrangePi, WPA2=OrangePi@123,
                                                               # autoconnect=true, priority=100, mode 600
/etc/modules-load.d/aic8800.conf                               # aic8800_bsp / btlpm / fdrv
/etc/hostname = arch-tty | arch-fxce | arch-kde
/etc/nsswitch.conf: hosts: files mdns_minimal [NOTFOUND=return] dns myhostname
账号：orangepi/orangepi（wheel）、root/orangepi
服务：sshd、NetworkManager、avahi-daemon(socket)、systemd-timesyncd、serial-getty@ttyS0
首次启动：firstboot-fixup.service 修复 /home/orangepi、/home/alarm 属主
```

变体镜像构建命令：

```bash
VARIANT=arch-tty                                     ./work/build_image.sh
VARIANT=arch-fxce ROOTFS_DIR=$PWD/work/archroot-xfce ./work/build_image.sh
VARIANT=arch-kde  ROOTFS_DIR=$PWD/work/archroot-kde  ./work/build_image.sh
```

## 6. 产物校验

```
6534fbd8e6e849e79e13e8aba52be3d09f6ee3122a97c135f49cf7cffdee0423  arch-tty.img    (2 851 078 144 B)
b4e3250927b440cd2281abbb1eafe5e2978770ba53c136198aa722f69f2f4f45  arch-fxce.img   (4 342 153 216 B)
43f2aa09220f12ba0e86a0e62635852183a121c5dc9d2a744289e6c85584cde9  arch-kde.img    (7 044 333 568 B)

101ced2a6493ea01bfbe85a86b14de5cb2d41d5927a535e22936cda170a0fdef  linux-image-current-sun60iw2_1.0.0_arm64.deb
84aff2f7b2096ec1b1932ea37b6604dc3f76fdbedf4c656712c87bacc03853ae  linux-dtb-current-sun60iw2_1.0.0_arm64.deb
2ef6b652742e598cc9520530e5d47207a050fafe59f0c85912a9b33a149ce2cf  linux-headers-current-sun60iw2_1.0.0_arm64.deb
71d6150a073e7618b50b06575da5c1890c8b606795d486cbf15a2d85816494f3  linux-u-boot-current-orangepizero4_1.0.0_arm64.deb
829ea8e3b65d71a02f2d0e094bc073de3a10869f948f62db49dbf023d07fabe3  boot0_sdcard.fex
59614659b94bb2c4e8d560c89c3a4ed1b816f028f24399b5e5c1fac423e2328b  boot_package.fex
```

镜像级校验（已执行）：

- MBR 有效、分区 1 起点 LBA 65536（32 MiB）、类型 0x83、active 标志；8 KiB 处 `eGON.BT0`；16400 KiB 处 `sunxi-package`；32 MiB+1080B 处 ext4 魔数 `0x53EF`
- `dumpimage -l`：uImage=AArch64 Kernel、uInitrd=AArch64 RAMDisk(gzip)、boot.scr=AArch64 Script
- 镜像内 `dbus-daemon-launch-helper` = root:dbus 04110（KDE 另有 `/var/lib/sddm`=963:963 0750；XFCE 有 `/var/lib/lightdm*`=965:965）
- 镜像内 `/etc/fstab` 与 `orangepiEnv.txt` 的 root UUID 一致；WiFi profile 为 mode 600；hostname 分别为 arch-tty/arch-fxce/arch-kde
- `sha256sum -c` 三个镜像全部通过

## 7. 工作区目录

```
src/opi-build/                  orangepi-build @ a05b3b4（含本地适配）
src/uboot-src/v2018.05-sun60iw2/  u-boot 源码与编译产物
work/ubuntu-jammy/              Ubuntu 22.04 arm64 构建 chroot（伪 root）
output/                         三个镜像、校验文件、packages、build-scripts、logs
```

（内核源码树在桌面镜像构建前已清理释放空间；内核 deb 与 `Image` 均保存在 `output/packages/`。）

## 8. 未做/待验证

- 未在真实 Zero 4 上启动验证（U-Boot 串口日志、WiFi 射频、桌面显示/输入）。
- 未安装 PowerVR GPU 用户态、NPU 运行时、CedarC 媒体库；桌面 GL 为 Mesa 软件渲染。
