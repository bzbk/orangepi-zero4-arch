# 启动问题排查记录（已解决 ✅）

Orange Pi Zero 4（A733，4GB LPDDR5）实机，TF 卡启动 Arch Linux ARM 镜像。最初表现为红灯常亮、绿灯不闪、HDMI/串口均无输出或启动中断。

## 最终状态

```
BOOT0（官方 Zero4 boot0）→ DRAM Type=9 (LPDDR5) 4096MB → ATF/BL31 → U-Boot 2018.07（官方）
→ boot.scr → uImage（ARM/0x41000000）→ 6.6.98-sun60iw2 内核 → initramfs → rootfs
→ Arch Linux ARM 6.6.98-sun60iw2 (ttyS0)
arch-fxce login:
```
串口登录验证：`orangepi/orangepi` 登录成功；`systemctl is-system-running = degraded`（仅 `user@965.service`（lightdm greeter 用户会话）失败，headless 无显示器导致，SSH/systemd 正常）。

## 根因与修复（按发现顺序）

### 1. U-Boot 配置/DTB 不匹配（反复卡死）
orangepi-build 的 `sun60iw2.conf` 对 `orangepizero4` 复用 **Zero3W 的 boot0** + pack-uboot 里**通用 T736 演示板 sys_config/DT**，与 Zero4 硬件不匹配。表现：
- `boot_package.cfg` 缺 `item=dtb, sunxi.fex` → boot0/ATF 报 `dtb not found for scp` / `No DTB found`，U-Boot 卡在 `board_init`
- 加上 dtb 项后 U-Boot 继续，但又在 vendor 初始化里连环卡死：
  - `sunxi_show_logo`（DRM framebuffer 分配）→ data abort
  - `console_init_r`（依赖 env 的 console mux，而 env 加载失败）→ 卡死
  - `initr_sunxi_plat` → `lradc_key_check()` 读 ADC 死等
  - `stdio_add_devices` → video/DRM probe 卡死

**修复**：不再用 vendor 通用配置硬凑，直接采用 **官方 Zero4 镜像的 boot0 + boot_package**（board 专用 sys_config/DT），一次通过。

### 2. uImage 架构字段错误（最隐蔽）
32 位 U-Boot 的 `bootm` 只接受 legacy uImage `arch=ARM(0x02)`；镜像里是 `mkimage -A arm64`（`arch=0x16`）：
```
Image Type: AArch64 Linux Kernel Image
Verifying Checksum ... OK
Unsupported Architecture 0x16
ERROR: can't get kernel image!
```
官方镜像是 `mkimage -A arm -a 0x41000000 -e 0x41000000`。
**修复**：uImage/uInitrd 全部按官方参数重新打包（`arch=ARM`，kernel load/entry=0x41000000）。

### 3. initramfs 损坏
`Initramfs unpacking failed: junk within compressed archive` → `Kernel panic - VFS: Unable to mount root fs`。
检查发现 initramfs 里只有 9 个 cpio 条目、无 `TRAILER!!!`。
**修复**：`mkinitcpio -k 6.6.98-sun60iw2 -z cat -g /boot/initramfs.cpio` + `gzip -9`（40MB cpio，含 TRAILER），再 `mkimage -A arm -C gzip` 打包 uInitrd。

### 4. 三色灯守护进程抢占串口
`tricolord` 的端口探测顺序为 `ttyACM* → ttyUSB*`，灯板（RP2040）未插时会打开 CH340（板子调试串口）并写入 `COLOR/STYLE/BRIS/STATE` 命令，污染 U-Boot 控制台（还会触发"按键"打断 autoboot）。
**修复**：调试期间用 udev 规则限制 CH340 仅 root 可访问。

### 5. 写卡误写普通文件
读卡器已被拔掉时 `dd of=/dev/sdg` 会在 `/dev` 下创建普通文件，导致"校验通过但卡没更新"。
**修复**：写入前严格校验 `[ -b /dev/sdX ]`。

## 关键校验值

| 项目 | 值 |
|---|---|
| boot0（官方，258,048B） | `5ec7f17be1f2f653…`（头部 length=0x3F000） |
| boot_package（官方，1,392,640B） | `036a9897559acf22…` |
| dtb（与官方一致） | `8d4dab3ad26b63a1…` |
| uImage | `arch=0x02`、`load/entry=0x41000000` |
| uInitrd | `arch=0x02`、`type=ramdisk`、`gzip` |
| initramfs | gzip cpio，含 `TRAILER!!!`、无尾部垃圾 |
