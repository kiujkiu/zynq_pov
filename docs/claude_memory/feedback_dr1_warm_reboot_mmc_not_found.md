---
name: feedback_dr1_warm_reboot_mmc_not_found
description: 🔴 热重启后 u-boot 可能认不到 SD 卡 ⇒ 停在 `=>`; ✅ 2026-09-01 根因查清(厂商源码)+ 修复上板(S00sdoff 关机钩子, shutdowns_logged 实测 0→1); 🔴 **判据是行数不是那句 probe failed**
metadata:
  type: feedback
---

# 热重启后 u-boot 认不到 SD 卡 (2026-08-31 撞到, **未结案**)

## 现象

板子跑了 5 小时 Linux 之后 `reboot`, u-boot 阶段刷出约 27 次:
```
Card did not respond to voltage select! : -110
mmc@f804a000 - probe failed: -1
mmc@f8049000: 0 (SD)Card did not respond to voltage select! : -110
Loading Environment from FAT... *** Warning - bad CRC, using default environment
```
⇒ 卡认不出来 ⇒ distro boot 找不到 `boot.scr` ⇒ **板子停在 `=>` 提示符起不来**。
⚠ 外部表现与"板子坏了"一致, 但这次串口能看到 u-boot 提示符 ——
再次印证 [[feedback_serial_probe_stops_uboot_autoboot]] 那条"先看是哪一级提示符"。

## 🎯 当场的解法

在 `=>` 下敲一条 **`mmc rescan`** 就认回来了:
`Device: mmc@f8049000 / Name: MSSD0 / SD High Speed (50MHz) / Capacity: 29.2 GiB`。
之后 `load mmc 0:1 ...` 一切正常(实测 11 MB 读了 496 ms, 21.5 MiB/s)。

## ⚠ 为什么说"未结案"

换了带 S95pov 的新 rootfs 之后**再 `reboot` 两次都没复现**。
所以它**要么是间歇性的, 要么与旧(出厂)rootfs 的关机路径有关** ——
启动日志里出现过 `FAT-fs (mmcblk0p1): Volume was not properly unmounted` 作为佐证。
🔴 **没有定论。"重启一次成功"证明不了什么, 这是间歇故障的典型陷阱。**

## Why 这件事是产品级的

用户原话: **"不断电的, 到用户手里也得有重启"**。
而且板子最终装在**旋转的转子上**, 拔电源意味着停机拆装。
⇒ 一次热重启起不来 = 产品缺陷, 不是开发期的小麻烦。

## ✅ 2026-09-01 根因查清 + 修复上板

🎯 **厂商全套源码在本机**: `/mnt/d/BaiduNetdiskDownload/uisrc-lab-anlogicV-V4.0.1.tar`
(`sources/u-boot` / `sources/opensbi` / `sources/linux` / `tools/riscv64-linux`)。

### 🔴 更正两条我们自己的说法

**① `mmc@f804a000 - probe failed: -1` 不是故障证据 —— 每次正常开机都有。**
`sdhci.c:783` `sdhci_get_cd()` 第一句 `if (host_caps & MMC_CAP_NONREMOVABLE) return 1;`,
而 **u-boot 自己那份 dtb**(编在 BOOT.bin 里, **不是** `boot/dtb_cma96.bin`) 里 mmc0 和 mmc1
**都写了 `non-removable`** ⇒ `anlogic_sdhci.c:301` 的"没插卡就直接返回"**永远不成立**
⇒ **空的 mmc1 每次开机都走完 8 相位扫描、打 9 行**。
27 行 = mmc0 失败(9) + **mmc1 常态失败(9)** + 环境加载再 probe(9)。
🎯 **判据是行数**: 正常开机 ≈ 9, 故障开机 = 9 的整数倍且 > 9。

**② "永久放弃该设备"不准确。** u-boot driver model 不拉黑设备(手敲 `mmc rescan`
能认回来就是反证)。准确说法: `bootcmd=run an_bootcmd` 而 **`an_bootcmd` 一趟无重试**,
走完就掉到 `=>`。

**没有 SPL**(defconfig 无任何 `CONFIG_SPL_*`, BOOT.bin 无 "U-Boot SPL" 串)
⇒ **boot ROM 每次复位都重新从卡读 3.74MB 的 BOOT.bin** ⇒ 失败那次**卡刚被 ROM 读过**
⇒ "卡死了/被留在 1.8V/必须拔电"全被证伪, **卡是活的**。

### ✅ 修法: `S00sdoff` 关机钩子(不用重打 initrd)

🎯 **关机钩子点在出厂 rootfs 里已经存在**: `/etc/inittab` 有 `::shutdown:/etc/init.d/rcK`,
而 `rcK` 是 `for i in $(ls -r /etc/init.d/S??*)` ⇒ **往 `/etc/init.d/` 丢个文件就行**。
钩子做: `povshd.sh stop` → sync → umount → **unbind sdhci 驱动**
(走 `sdhci_remove_host()` 的 `SDHCI_RESET_ALL` + 关 POWER, 最接近"给卡断电")。

🔴 **名字必须是 `S00sdoff` 不是 S99** —— `ls -r` 倒序下**字典序最小的在关机时最后跑**
(`S95pov stop` 先杀 pov_rxd, 我们最后抽卡)。取反是唯一的致命错误,
所以 `stage_sdoff` 自己算 `ls -r|tail -1` 当判据(从目录算, 不写死)。

**上板实测**(`povboot.sh sdoff` 装, 然后热重启一次):
`SDOFF_STATUS ... shutdowns_logged=0 → 1` ✅ 钩子真在关机时跑了;
痕迹 `sdoff up=62174.20 bound=1`; `POVBOOT: PASS (every stage in 'povsh sdoff pl sw wifi' returned 0)`。
⚠ **只验了一次** —— 间歇故障要 `tools/reboot_campaign.sh` 做 N 次 A/B + Fisher 检验。

### 🔴 三条差点写错的地方

- **`fuser -m` 只能打印, 永远不许加 `-k`**: 卡没挂载时 `-m $CARD` 解析到**根文件系统**,
  `fuser -mk /` 在关机路上就是 SIGKILL 给 pid 1
- **必须 `povshd.sh stop` 不能只 `killall povsh`**: supervisor 约 2 s 就拉回来, 正好落在 umount 中间
- **unbind 轮询要看内核状态不是子进程 pid**: 后台作业退出后是僵尸, `kill -0` 对僵尸返回成功
  ⇒ 循环永远跑满超时。而这个 busybox **没有 `timeout` applet**。

## How to apply

1. **热重启起不来时先别慌**: 串口看到 `=>` 就敲 `mmc rescan`, 再 `boot`。
2. 🔴 **绝不要在 u-boot 里 `saveenv`** —— `bootcmd=run an_bootcmd` 而 `an_bootcmd` 被
   `boot_type` 闸住, 而 `boot_type` **不在默认环境里**(运行时由板级代码按启动模式设)。
   存一份污染过的环境可以让 `an_bootcmd` **静默什么都不干** —— 那是第二块砖, 且更难查。
3. **验证修复必须有统计意义**: 连续 N 次热重启全过才算, N 要按观测到的复现率定。
4. 顺带: u-boot 有 **`fatrm`**(所以 `AUTOBOOT` 闸门的逃生门是 `fatrm mmc 0:1 pov/AUTOBOOT`,
   **不用拔卡**), 但**没有 `md5sum`** ⇒ u-boot 侧校验用 `crc32 <addr> <len>`。

相关: [[feedback_s95pov_never_shipped_in_any_rootfs]] [[feedback_dr1_reboot_loses_everything]]
[[reference_dr1_factory_linux_boot]]
