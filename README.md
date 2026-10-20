# Orange Pi Zero 4 · Arch Linux ARM 镜像

从 [orangepi-xunlong/orangepi-build @ a05b3b4](https://github.com/orangepi-xunlong/orangepi-build/commit/a05b3b4d5fc0dd4eb859f64c8a60f9b2c9e33cb1)（"Support OrangePi Zero4"）构建的 **Allwinner A733 / Orange Pi Zero 4** 的 Arch Linux ARM (aarch64) 镜像。

- **已在实机验证启动**（Orange Pi Zero 4，4GB LPDDR5，TF 卡）：boot0 → U-Boot → `boot.scr` → 6.6.98 内核 → Arch systemd → `arch-* login:`
- 官方 **U-Boot bootloader**：直接取自 OrangePi 官方 Zero4 镜像（`u-boot-orangepi` 分支 `v2018.05-sun60iw2`）
- vendor **内核**：`linux-orangepi` 分支 `orange-pi-6.6-sun60iw2` → **6.6.98-sun60iw2**
- 设备树：`sun60i-a733-orangepi-zero4.dtb`（SHA256 `8d4dab3a…`，与官方镜像完全一致）
- 用户态：Arch Linux ARM aarch64（2026-08 rootfs + `pacman -Syu`）

## 镜像（Release 资产）

| 变体 | 原始大小 | 压缩后 | 桌面 | Release 资产名 |
|---|---|---|---|---|
| `arch-tty` | 2.66 GiB | 722 MiB | 无（CLI，SSH/串口调试） | `arch-tty.img.zst.part00~02`（3 卷） |
| `arch-fxce` | 4.04 GiB | 1.20 GiB | XFCE 4 + LightDM（X11） | `arch-fxce.img.zst.part00~04`（5 卷） |
| `arch-kde` | 6.56 GiB | 2.04 GiB | KDE Plasma 6 + SDDM（默认 Plasma X11） | `arch-kde.img.zst.part00~08`（9 卷） |

镜像 SHA256（**解压后**）：

```
2becf4f2cb93f1f3a241e15d6df09e3ef50b1fa71d96cc2bea82b86144dada42  arch-tty.img
4e52278617b463468341e9f82c9682bbc419d86a470618b3d10cd33d578fa0b7  arch-fxce.img
537609b7e3c6b04ebbf4b15f3a3379b1531bd2b380830f6e1b640fd2bdbe5f3c  arch-kde.img
```

压缩分卷与 SHA256 见 `SHA256SUMS.parts`（已按 256 MiB 分卷）。

## 烧录

```bash
# 1) 合并分卷（每个变体的 part 文件按名称顺序拼接）
cat arch-tty.img.zst.part*  > arch-tty.img.zst
cat arch-fxce.img.zst.part* > arch-fxce.img.zst
cat arch-kde.img.zst.part*  > arch-kde.img.zst

# 2) 校验并解压
sha256sum arch-kde.img.zst   # 应为 66368608520abcbf30bc26353a3a31fe7695681254fe98308bfce690ec7a062f
zstd -d arch-fxce.img.zst -o arch-fxce.img

# 3) 校验镜像（解压后，sha256 应等于上表）
sha256sum arch-fxce.img

# 4) 写入 TF 卡（Linux）
sudo dd if=arch-fxce.img of=/dev/sdX bs=4M status=progress conv=fsync
# 或使用 balenaEtcher（DD 模式）
```

> 注意：必须写**解压后的 .img**；TF 卡容量 ≥ 8/16/32GB（按变体）。

## 默认账号 / 网络

| 项目 | 值 |
|---|---|
| 用户 | `orangepi` / 密码 `orangepi`（wheel 组），`root` / `orangepi` |
| 主机名 | **`orangepizero4`**（与官方镜像一致；可用 `sudo orangepi-config` 修改） |
| WiFi（自动连接） | SSID `OrangePi`，密码 `OrangePi@123`（`/etc/NetworkManager/system-connections/OrangePi.nmconnection`） |
| 远程 | `sshd` 默认启用；`avahi-daemon` + `nss-mdns`，可 `ssh orangepi@arch-kde.local` |
| 串口 | UART0 `ttyS0` 115200 8N1（3.3V USB-TTL，TX/RX 交叉 + GND） |
| rootfs | 首次启动自动扩容（systemd-growfs） |

## 本次修复的启动问题（重要）

镜像最初无法启动，排查后修复了 5 个问题（详见 [`DEBUGGING.md`](DEBUGGING.md)）：

1. **bootloader 用错**：orangepi-build 对 Zero4 复用 Zero3W boot0 + 通用 T736 sys_config，与 Zero4 硬件不匹配 → 改用**官方 Zero4 镜像的 boot0（258,048B）/ boot_package**
2. **uImage 架构字段错误**：32 位 U-Boot 只接受 `arch=ARM`；之前用 `mkimage -A arm64` 被拒（`Unsupported Architecture 0x16`）→ 改为 `-A arm -a 0x41000000 -e 0x41000000`
3. **initramfs 损坏**（无 `TRAILER!!!`、解包 junk）→ 重新用 `mkinitcpio -k 6.6.98-sun60iw2 -z cat` + gzip 生成
4. **三色灯守护进程抢占 CH340 串口**、往 U-Boot 控制台写命令 → 调试期限制串口访问
5. 写卡脚本误在 `/dev/sdg` 不存在时生成普通文件 → 加块设备校验



### 欢迎页（与官方 Ubuntu 镜像严格对齐）

- 使用官方 `update-motd.d` 脚本原样移植：`10-orangepi-header`（官方同款彩色 ASCII 横幅）、
  `30-orangepi-sysinfo`、`35-orangepi-tips`、`40-orangepi-updates`、`41-orangepi-config`、
  `92-unattended-upgrades`、`97-overlayroot`、`98-orangepi-autoreboot-warn`
- `/etc/orangepi-release`：`BOARD=orangepizero4`、`BOARD_NAME="Orange Pi Zero 4"`、`VERSION=1.0.0`
- `/etc/issue`：`Orange Pi 1.0.0 Arch \l`（与官方 `Orange Pi 1.0.0 Resolute \l` 同格式）
- 依赖 `bc`、`inetutils` 已预装
- 登录效果（SSH / 串口）：

```
  ___  ____  _   _____                _  _
 / _ \|  _ \(_) |__  /___ _ __ ___   | || |
| | | | |_) | |   / // _ \ '__/ _ \  | || |_
| |_| |  __/| |  / /|  __/ | | (_) | |__   _|
 \___/|_|   |_| /____\___|_|  \___/     |_|

Welcome to Orange Pi 1.0.0 Arch with Linux 6.6.98-sun60iw2

System load:   ...   Up time: ...   Local users: ...
Memory usage:  ...   IP: ...
Usage of /:    ...

[ General system configuration (beta): orangepi-config ]
```

## 内置 Orange Pi 工具 / 欢迎页

镜像内置了移植自官方 Ubuntu 镜像的实用工具（Arch 版）：

| 工具 | 说明 |
|---|---|
| `orangepi-config` | 菜单式配置：系统信息、主机名、WiFi、SSH、改密码、扩展根分区、`pacman -Syu`、重启/关机 |
| `lcd_set` | 显示状态（DRM 连接器/模式/背光）、`rotate 0/90/180/270`、`brightness 0-255`、`off/on` |
| motd 欢迎页 | SSH / 串口登录自动显示 Orange Pi 横幅、板卡信息、IP/WiFi、温度、Tip |
| `/etc/issue` | `Orange Pi Zero 4 · Arch Linux ARM \r (\l)` |

> vendor 内核 6.6.98 未开启 Landlock，而 pacman 7.x 的下载沙箱依赖 Landlock；镜像已在 `/etc/pacman.conf` 加入
> `DisableSandbox`，否则 `pacman -Syu` 会报 `restricting filesystem access failed because Landlock is not supported`。

> 首次启动后可用 `sudo orangepi-config` 修改 hostname / WiFi / SSH，或用 `nmcli` 管理网络。

## 构建信息

- 构建记录：[`BUILD-INFO.md`](BUILD-INFO.md)
- 构建脚本：`scripts/`（image 组装、bootloader 写入、镜像最终修复）
- 主机环境：Xiaomi Pad 6 (Arch Linux ARM aarch64) + Ubuntu 22.04 arm64 chroot + qemu-x86_64 跑全志打包工具

## 已知问题

- U-Boot 启动日志中的 `Loading Environment from EXT4... No device specified` / `bmu_axp515_probe pmic_bus_read fail` / DRM 探测告警是官方 bootloader 的正常噪声，不影响启动
- 桌面（XFCE/KDE）未在 HDMI 显示器上实机验证（串口/server 启动已验证）
- 音频 `asoc_simple_parse_of` 告警为 vendor 内核设备树遗留，不影响系统
