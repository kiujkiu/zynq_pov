---
name: project_dr1m90_base_bringup
description: 2026-09-22 DR1M90 首次上板底座核查 (WS1) — COM24(CH342 PnP 7&1409325E), aarch64 双核 buildroot 出厂系统, fpga_manager 在且 identifies "Anlogic dr1m90"; PL 加载路已通(configfs 一挂 overlays 就出); 🔴 头号风险坐实: SRST_CTRL2=0x1100 bit4(GP0主口复位)未放开, 碰 GP0 前必须读改写置 0x10; pov 载荷(aarch64)已在卡上
metadata:
  type: project
---

# DR1M90 底座首次上板核查 (2026-09-22, WS1)

近期验证板主控 = DR1M90(ARM)。用户 2026-09-22 插上串口, 首次实测。移植清单见 [[project_dr1m90_jtag_port_checklist]]。

## 认板 / 现状
- **串口: COM24**(CH342 A 路控制台, B 路 COM23), PnP 实例 **`7&1409325E`** (与两块 DR1V90 的 `7&2D66278`/`6&88CF9E7` 不同 = 第三颗 CH342, 正是插上 DR1M90 多出来的那颗)。🔴 PnP 实例跟 USB 口走不跟板走, 认板只认 `uname -m=aarch64` + BOARD_ID。
- `uname -m` = **aarch64** (DR1M90 判据), 双核(nproc=2), 内核 6.1.111-rt42(与 DR1V90 同 RT 内核)。
- hostname **buildroot** (出厂系统, 不是我们的 pov 镜像); `/proc/device-tree/model` = "Anlogic, DR1M90 FPSoc"; SD CID `ad4c…d1018800`。
- BOARD_ID 还没有(出厂无 pov/BOARD_ID)。pov 载荷(aarch64)已在卡上: `/mnt/mmcblk0p1/pov/` 有 pov_rxd/ksink/iperf3/helix.lz4hc/wifi 脚本/ccm.ko 等。
- 出厂即 `fpga0 state=operating`(ATF/PCAP 开机加载了出厂 PL); dmesg 只有 "FPGA manager framework" + "base_fpga_region probed", 无 overlay ⇒ 出厂 PL 不是走 configfs。
- `getconf` / `/proc/config.gz` 都没有(buildroot 精简)。devmem 在 `/sbin/devmem`。

## ✅ PL 加载路可用 (只差挂 configfs)
- 出厂 buildroot **没自动挂 configfs**: `/sys/kernel/config/device-tree/overlays` 一开始不存在。
- **`mount -t configfs none /sys/kernel/config` 一挂, overlays 目录立刻出现** ⇒ 内核 OF_CONFIGFS/OF_OVERLAY 是开的, fpga_manager + base_fpga_region 都在。
- ⇒ DR1V90 那套 "写 overlay → fpga_manager 编程 → operating" 的加载路在 DR1M90 上成立, **aarch64 版 load 脚本开头要先 `mount -t configfs`** (DR1V90 镜像大概率自动挂了)。

## 🔴 PS 控制寄存器基线 (PL 加载前, 只读, 安全)
| 寄存器 | 地址 | DR1M90 实测 | 说明 |
|---|---|---|---|
| PLS_PROT | 0xF8800080 | **0x00000003** | 同 DR1V90 冷启动 |
| HP_WIDTH | 0xF8800084 | 0x00000000 | |
| **SRST_CTRL2** | 0xF8801078 | **0x00001100** | 🔴 **bit4(0x10, GP0M 复位)= 0, 未放开** |
| FCLK_DIV | 0xF880103C | 0x07070707 | p2f_clk0 50MHz 已配 |

🔴 **头号风险坐实**: SRST_CTRL2 bit4 未放开 ⇒ 现在直接读 GP0(0x80000000) 会**挂单核 CPU**
(DR1V90 上是 OpenSBI 加载 PL 时放开 0x33, DR1M90 的 ATF 没做)。
⇒ 加载我们的 PL 后, **碰 GP0 前必须先 `devmem 0xF8801078 32 <读回值|0x10>`**(读改写只置 bit4);
并且要测: fpga_manager/PCAP 加载 PL 会不会顺带放开这一位(加载后再读 0xF8801078 对比)。

## 下一步 (WS1 continue)
1. 出一个 **DR1M90 器件 + bootgen -arch dr1m90** 的 GP0 测试位流(只用板载 25M, 不依赖 p2f_clk0):
   先试**只改器件串、保留现 RISC-V PS 封装** 跑 TD(~10min), 拒收(大概率, ARM_Processor_System IP 的
   deviceRegexp 只认 DR1M90)再生成 ARM PS 封装。
2. 挂 configfs → 加载 → 读 SRST_CTRL2 看 ATF 放没放 GP0M → (为 0 则置 bit4) → 读 GP0 MAGIC。

相关: [[project_dr1m90_jtag_port_checklist]] [[project_pov3d_jtag_load_bench]] [[project_pov3d_dr1v90_board_inventory]] [[feedback_dr1_pl_probe_must_be_hang_proof]]
