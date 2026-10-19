# Orange Pi Zero 4 · Arch Linux ARM 镜像

从 [orangepi-xunlong/orangepi-build @ a05b3b4](https://github.com/orangepi-xunlong/orangepi-build/commit/a05b3b4d5fc0dd4eb859f64c8a60f9b2c9e33cb1)（"Support OrangePi Zero4"）构建的 **Allwinner A733 / Orange Pi Zero 4** 的 Arch Linux ARM (aarch64) 镜像。

- vendor **U-Boot**：`u-boot-orangepi` 分支 `v2018.05-sun60iw2`
- vendor **内核**：`linux-orangepi` 分支 `orange-pi-6.6-sun60iw2` → **6.6.98-sun60iw2**
- 设备树：`sun60i-a733-orangepi-zero4.dtb`
- 用户态：Arch Linux ARM aarch64（2026-08 rootfs + `pacman -Syu`）

## 镜像（Release 资产）

| 变体 | 原始大小 | 压缩后 | 桌面 | Release 资产名 |
|---|---|---|---|---|
| `arch-tty` | 2.66 GiB | 676.7 MiB | 无（CLI，SSH/串口调试） | `arch-tty.img.zst` |
| `arch-fxce` | 4.04 GiB | 1141.1 MiB | XFCE 4 + LightDM（X11） | `arch-fxce.img.zst` |
| `arch-kde` | 6.56 GiB | 2037.6 MiB（分卷） | KDE Plasma 6 + SDDM（默认 Plasma X11） | `arch-kde.img.zst.part00` + `part01` |

> ⚠️ **当前 Release 为测试版本，启动问题排查中**，见 [`DEBUGGING.md`](DEBUGGING.md)。
> 另附 `bootloader-testpack.tar.gz`（可快速替换 SD 卡上的 boot0/boot_package 做启动排查）和 `Image-6.6.98-sun60iw2`。

镜像 SHA256（解压后）：

```
6534fbd8e6e849e79e13e8aba52be3d09f6ee3122a97c135f49cf7cffdee0423  arch-tty.img
b4e3250927b440cd2281abbb1eafe5e2978770ba53c136198aa722f69f2f4f45  arch-fxce.img
43f2aa09220f12ba0e86a0e62635852183a121c5dc9d2a744289e6c85584cde9  arch-kde.img
```

> GitHub 单文件上限 2 GiB，因此镜像已 **zstd 压缩 + 分卷**（每卷 < 1.9 GiB）。分卷 SHA256 见 `SHA256SUMS.parts`（上传后补全）。

## 下载 / 合并 / 烧录

### 方式 A：gh CLI

```bash
gh release download v1.0.0 -R bzbk/orangepi-zero4-arch -D opi-zero4-arch
cd opi-zero4-arch
```

### 方式 B：浏览器

在 Releases 页面下载对应变体的全部分卷（`...zst.part00`、`part01`…）到同一目录。

### 合并 + 解压 + 烧录

```bash
# tty / fxce 为单文件，直接解压；KDE 先合并分卷
zstd -d arch-tty.img.zst -o arch-tty.img      # 或 arch-fxce.img.zst
# KDE：
cat arch-kde.img.zst.part00 arch-kde.img.zst.part01 > arch-kde.img.zst
zstd -d arch-kde.img.zst -o arch-kde.img

# 校验（与上面的 SHA256 对比）
sha256sum arch-kde.img

# 写卡（/dev/sdX 换成 SD 卡设备！会清空该盘）
sudo dd if=arch-kde.img of=/dev/sdX bs=4M conv=fsync status=progress
sync
```

Windows：先合并分卷（`copy /b part00+part01+... out.zst`），再用 7-Zip/zstd 解压，最后用 balenaEtcher / Rufus（DD 模式）写卡。

容量建议：tty / fxce **≥ 8 GB**，kde **≥ 16 GB**。

## 首次启动

- 串口：**UART0 / ttyS0，115200 8N1**；HDMI 也可作为 console
- 默认账号（**请立即用 `passwd` 修改**）：
  - 普通用户：`orangepi` / `orangepi`（wheel 组，可 sudo）
  - root：`root` / `orangepi`
- **默认 WiFi**：SSID **`OrangePi`**，密码 **`OrangePi@123`**（WPA2-PSK）
  - NetworkManager 预置连接（`/etc/NetworkManager/system-connections/OrangePi.nmconnection`），`autoconnect=true`、优先级 100，上电自动连接。
- 主机名：`arch-tty` / `arch-fxce` / `arch-kde`；已启用 `sshd`、`avahi`（mDNS），可 `ssh orangepi@arch-kde.local`
- 首次启动 `firstboot-fixup.service` 自动修复 `/home/orangepi`、`/home/alarm` 属主。
- 桌面变体：`getty@tty1` 已 mask（显示管理器占用），文本控制台在 tty2 或串口；GL 使用 Mesa 软件渲染（未装 PowerVR vendor 用户态）。

## 构建记录

完整构建环境、命令、arm64 主机适配、设备树一致性核查、镜像级校验见 [`BUILD-INFO.md`](BUILD-INFO.md)；实际使用的脚本在 [`scripts/`](scripts/)。

简要流程：

1. 取 `orangepi-build` 指定提交 + 内核/U-Boot 对应分支；
2. 在 Ubuntu 22.04 arm64 chroot（本机 Arch Linux ARM aarch64，`bwrap` 伪 root）中 `BUILD_OPT=u-boot` / `BUILD_OPT=kernel`；
3. 组装 Arch Linux ARM rootfs（含 WiFi/账号/固件/启动文件；桌面变体另装 XFCE/KDE）；
4. `mke2fs -d` 生成 ext4（无需 loop），写入 MBR 镜像 32 MiB 处，按偏移写入 `boot0_sdcard.fex`（8 KiB）与 `boot_package.fex`（16400 KiB）。

## 已知限制

- **未在真实 Orange Pi Zero 4 上启动验证**（构建主机无该板卡）：U-Boot 偏移、分区、dtb、启动脚本、内核/模块、文件属主均做了镜像级校验，首次启动建议接串口观察。
- 桌面环境未实机验证（显示/输入、Mesa 软件渲染、LightDM/SDDM 首次启动需上板确认）；GPU/NPU/video vendor 用户态库未安装。
- WiFi/BT 驱动与固件已就位，射频未实测。
- 内核为 Allwinner vendor BSP 6.6.98（非 mainline）。
