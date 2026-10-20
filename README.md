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
40432709feabcca2a3e3d589932c20b08499fe4f45e135abe115bafcc5b7c45a  arch-tty.img
49bddee7ba3ecd82f20a0af64b83d06c45704f4d19a64f12fec62efad5bc065c  arch-fxce.img
a5f542cd98222819a4f388dbefef0039ae7900484297700a51ba67db5f09aa4b  arch-kde.img
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

## 内置的官方工具 / 欢迎页（与官方镜像一致）

**工具全部直接取自官方 Ubuntu 镜像原版**（未重写）：

| 文件 | 来源 |
|---|---|
| `/usr/bin/orangepi-config` | 官方 `/usr/sbin/orangepi-config` 原版（5825 B，177 行） |
| `/usr/lib/orangepi-config/*.sh` | 官方原版：`functions.sh` / `functions-network.sh` / `jobs.sh` / `submenu.sh` |
| `/etc/update-motd.d/10,30,35,40,41,92,97,98` | 官方原版 MOTD 脚本 |
| `/etc/pam.d/system-login` | 官方同款逻辑：`pam_exec → run-parts --lsbsysinit /etc/update-motd.d > /run/motd.dynamic`，再由 `pam_motd.so motd=/run/motd.dynamic` 显示 |
| `/etc/orangepi-release` | 官方字段（`BOARD=orangepizero4`、`BOARD_NAME="Orange Pi Zero 4"`、`VERSION=1.0.0`） |
| `/etc/issue` | `Orange Pi 1.0.0 Arch \l`（官方为 `... Resolute \l`，同格式） |
| 主机名 | **`orangepizero4`**（与官方一致；`/etc/hosts` 同步） |

官方脚本中的 `apt/apt-get/dpkg` 调用已**直接替换为 pacman**（`pacman -Sy/-Su/-S/-Rns`），菜单文字也同步改为 “Run pacman update & upgrade”；另保留一层极薄兼容 shim（`/usr/local/bin/{apt,apt-get,dpkg,dpkg-query,lsb_release,debconf-apt-progress}`，
把包管理调用映射到 pacman）；官方脚本本体保持**逐字节原样**，因此菜单结构/操作逻辑/提示文字与官方完全相同。
Debian 专属功能（如安装 .deb、armbian 内核包升级）在 Arch 上不可用属预期。

MOTD 依赖（`toilet`、`figlet` 字体、`run-parts`、`dialog`、`bc`、`inetutils`）已预装。

> 说明：官方**服务器镜像**里没有 `lcd_set`（它只存在于官方桌面镜像）；因此本镜像未提供该脚本，
> 避免自造一个“像官方但不一样”的实现。若需要，可从官方 XFCE/KDE 镜像中提取原版后加入。

登录效果（SSH / 串口一致，走官方 PAM + 原版脚本）：

```
  ___  ____  _   _____                _  _
 / _ \|  _ \(_) |__  /___ _ __ ___   | || |
| | | | |_) | |   / // _ \ '__/ _ \  | || |_
| |_| |  __/| |  / /|  __/ | | (_) | |__   _|
 \___/|_|   |_| /____\___|_|  \___/     |_|

Welcome to Orange Pi 1.0.0 Arch with Linux 6.6.98-sun60iw2

System load:  ...   Up time: ...   IP: ...
Memory usage: ...   Usage of /: ...
```

## 构建信息

- 构建记录：[`BUILD-INFO.md`](BUILD-INFO.md)
- 构建脚本：`scripts/`（image 组装、bootloader 写入、镜像最终修复）
- 主机环境：Xiaomi Pad 6 (Arch Linux ARM aarch64) + Ubuntu 22.04 arm64 chroot + qemu-x86_64 跑全志打包工具

## 已知问题

- U-Boot 启动日志中的 `Loading Environment from EXT4... No device specified` / `bmu_axp515_probe pmic_bus_read fail` / DRM 探测告警是官方 bootloader 的正常噪声，不影响启动
- 桌面（XFCE/KDE）未在 HDMI 显示器上实机验证（串口/server 启动已验证）
- 音频 `asoc_simple_parse_of` 告警为 vendor 内核设备树遗留，不影响系统
