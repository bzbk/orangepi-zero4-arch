# 启动问题排查（进行中）

现象：镜像烧录到 Orange Pi Zero 4 后无法启动。

## 已核对（镜像侧）

- 设备树链：`sun60i-a733-orangepi-zero4.dts` → `.dtb`（SHA256 `8d4dab3a…`）→ deb → rootfs → 镜像内，各处一致；
  `orangepiEnv.txt` 的 `fdtfile=allwinner/sun60i-a733-orangepi-zero4.dtb` 与 `boot.scr` 的加载路径一致。
- bootloader 写入偏移与 orangepi-build 上游一致：`boot0_sdcard.fex @ 8 KiB`、`boot_package.fex @ 16400 KiB`，
  分区 1 起于 32 MiB，MBR active，8 KiB 处为 `eGON.BT0`、16400 KiB 处为 `sunxi-package`、32 MiB 处 ext4 魔数正确。
- 当前镜像使用的 bootloader 来自 `orangepi-build` 的 `uboot_custom_postprocess` 对 `BOARD=orangepizero4` 的显式逻辑：
  `boot0_sdcard_orangepizero3w.fex` + `boot_package.fex`（U-Boot 分支 `v2018.05-a733` HEAD `baff742` 内容）。

## 待确认

1. **串口日志**：UART0 / ttyS0，115200 8N1。是否有任何输出？停在哪一步（boot0 / U-Boot / 内核）？
2. 路由器/DHCP 里是否出现 `arch-tty` / `arch-fxce` / `arch-kde` 或新 IP？能 `ping arch-kde.local` 吗？（确认是否只是显示输出问题）
3. 烧录：确认写的是解压后的 `.img`，且 `sha256sum` 与发布说明一致；用 dd/balenaEtcher DD 模式。
4. 板卡：RAM 容量版本（1/2/4 GB）、电源（5V/3A+）、SD 卡型号；板上是否有 eMMC / SPI Flash 且可能优先启动。
5. HDMI 是否有任何信号（背光/黑屏/无信号）。

## 快速测试 bootloader 组合（无需重烧整镜像）

下载 Release 里的 `bootloader-testpack.tar.gz`，解压后：

```bash
sudo ./patch-boot.sh /dev/sdX boot0_sdcard_zero3w.fex  boot_package-a733-baff742.fex      # 默认
sudo ./patch-boot.sh /dev/sdX boot0_sdcard_a733.fex     boot_package-a733-baff742.fex      # 换 A733 通用 boot0（DRAM 参数不同）
sudo ./patch-boot.sh /dev/sdX boot0_sdcard_generic.fex  boot_package-a733-baff742.fex      # 换 generic boot0
sudo ./patch-boot.sh /dev/sdX boot0_sdcard_zero3w_1800M.fex boot_package-a733-baff742.fex  # 1800MHz DRAM 版本
sudo ./patch-boot.sh /dev/sdX boot0_sdcard_zero3w.fex  boot_package-sun60iw2-b791be84.fex  # 新版 U-Boot（GitHub HEAD）
```

每次只改一个变量，接串口观察。

## 版本对照

| 分支 | HEAD | 说明 |
|---|---|---|
| `v2018.05-a733` | `baff742` (2025-10-22) | 当前镜像使用的内容（`Support OrangePi 4 Pro`） |
| `v2018.05-sun60iw2` | `b791be84` (2026-03-04) | 比 a733 多 6 个提交：nvme/ufs/logo 修复 |
