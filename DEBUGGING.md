# 启动问题排查（进行中）

现象：镜像烧录到 Orange Pi Zero 4 后无法启动（红灯常亮、绿灯不闪、HDMI 无输出）。

## 硬件/参考信息（官方手册 v1.0）

- SoC：A733，双核 Cortex-A76 + 六核 Cortex-A55，4GB LPDDR5（本机）
- 手册第 4 章：官方构建方案 = Ubuntu 22.04 x64 运行 orangepi-build（**next 分支**）；
  u-boot 源码 `u-boot-orangepi` 分支 **v2018.05-sun60iw2**（32 位 arm-linux-gnueabi 工具链）；
  内核 `linux-orangepi` 分支 **orange-pi-6.6-sun60iw2**（6.6.98）
- 官方 bootloader 写入方式：boot0 @8KiB、boot_package @16400KiB（与本镜像一致）
- TF 卡启动优先级高于 eMMC/UFS；红灯=上电（硬件控制）、绿灯闪烁=内核已启动
- 调试串口：UART0，115200 8N1（3.3V USB-TTL，TX/RX 交叉 + GND）

## 串口诊断已确认的启动链

```
boot0: Try SD card 0 → 122240 MB → DRAM Type=9 (LPDDR5) → 4096MB → DRAM test OK
BL31: v2.5(debug) [No DTB found]（非致命）
U-Boot 2018.07-orangepi (本工程编译) → Model sun60iw2 → DRAM 4 GiB → PMU AXP8191
```

说明 **TF 卡、boot0、DRAM 初始化、ATF、U-Boot 前期** 均正常，问题在 U-Boot 后半段初始化。

## 已定位并修复的问题

| # | 现象（串口/反汇编证据） | 根因 | 修复 |
|---|---|---|---|
| 1 | U-Boot 停在 board_init 之后（`CPU=1014 MHz...` 后无输出） | `boot_package.cfg` 缺 `item=dtb, sunxi.fex`（对照同族 sun55iw3 的 cfg 确认），boot0/ATF 均报找不到 DTB | 在 `boot_package.cfg` 增加 `item=dtb, sunxi.fex` 重新打包 |
| 2 | `initcall: board_env_late_init` → `data abort pc=memalign+0xbe`（r5=0x1000） | `run_command("sunxi_show_logo")` 的 U-Boot 开机 logo/DRM 在 Zero4 上分配 framebuffer 触发 data abort | 跳过 `sunxi_show_logo`（内核显示不受影响） |
| 3 | `RI console_init_r` → `RCON_IN` 后无输出（卡死） | `CONFIG_SYS_CONSOLE_IS_IN_ENV=y` 时 console_init_r 依赖环境变量做控制台 mux；本机 env 加载失败（`Loading Environment from EXT4... No device specified`），导致挂死 | 关闭 `CONFIG_SYS_CONSOLE_IS_IN_ENV`，走简化控制台初始化 |
| 4 | `RI initr_sunxi_plat` 后卡死（无 RO） | 该函数内 `check_recovery_key()` → `lradc_key_check()` 读取 ADC 检测恢复键，在 Zero4 上死等（PMIC/I2C 也有读失败日志） | 关闭 `CONFIG_SUNXI_PHY_KEY` / `CONFIG_SUNXI_LRADC_KEY`；并加 `PLAT1..5` 串口标记继续观察 |

## 诊断工具（已内置在当前测试 bootloader）

- 裸 UART 调试（直接写 0x02500000，绕过 console 子系统）：`RI<addr>` / `RO<addr>` 每个 initcall 进入/返回；
  `RCON2_IN/RCON2_DEVOK`、`PLAT1..5`、`envlate:` 阶段标记
- 地址映射：`u-boot.map` / `System.map`（构建目录 `src/uboot-src/v2018.05-sun60iw2/`）
- 快速替换 SD 卡 bootloader（不用重烧整镜像）：`bootloader-testpack.tar.gz` 内 `patch-boot.sh`，
  或本工程 `work/patch_sd_boot.sh /dev/sdX`

## 当前状态

- 卡上测试 bootloader：`boot_package` = `327de054…`（关闭 LRADC/PHY 键 + PLAT 标记 + console 修复 + dtb 项）
- 等待下一次上电验证：是否走完 `initr_sunxi_plat` → mmc → env → `boot.scr` → 内核
