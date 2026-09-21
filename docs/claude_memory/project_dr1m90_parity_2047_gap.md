---
name: project_dr1m90_parity_2047_gap
description: 🎯 2026-09-20 DR1M90 达到"现役 Zynq 驱动 2047 偏心双面屏全部功能"的差距核查 — 共用不用改的/已做完的/还缺的三类清单; 🎯 头号发现: DR1V90 的两堵墙(cpy 162ms、PL 解码 37 帧卡死)根因**都是 RISC-V 专属**(无 Svpbmt ⇒ pgprot 空操作; 安路 CCM 是 RISC-V CSR), 在 aarch64 上大概率不存在 ⇒ 换 DR1M90 可能顺手消掉当前唯一真正挡路的问题
metadata:
  type: project
---

# DR1M90 对齐"现役 2047 偏心双面"的差距核查 (2026-09-20)

## 0. 对齐目标 = 现役 Zynq 在跑的那套
见 [[project_dr1_parity_plan]](六线 A-F)、[[project_pov3d_v31_dualface_geometry_solved]]。要点:
**969 RPM / 10-12 fps / 3-bit 行内 BCM / half_scan / fold_a / PL 三引擎解码直写 bank / 双面偏心**。
偏心双面的实测正确配置: `mirror_a=0` `mirror_b=0` **`PHASE_B=180`** `dual_en=1` ⇒ `POV_CTRL=0x01680005`;
面A `axis_off=0`(穿心) / 面B `axis_off=+14.2933px` / `mirror_u` 全局 ON。
⚠ 现役旋转的是 **2047**; 24 颗 2260 的目标板是另一条线, 别混。

## 1. 共用、不用改 (出处: 09-17 只读审计 workflow wf_1169c978-a59)
PINLIST / TD 器件库 `dr1_90.db`(资源逐列相同) / PL RTL / 管脚约束 / 上电强制 IO 表(DS1200 表2-6 两颗共用);
GP0 基址 0x80000000 与 POVJ 窗口; PS 控制寄存器地址与位(PLS_PROT 0xF8800080 / HP_WIDTH 0xF8800084 /
SRST_CTRL2 0xF8801078 / FCLK_CNT_DIV 0xF880103C 在 FD 2025.1 addrmap 的 dr1m90/dr1v90 页**逐项相同**);
板子身份检查(代码找子串 `anlogic|dr1`, DR1M90 的 model "Anlogic, DR1M90 FPSoc" 与驱动名 "Anlogic dr1m90 FPGA Manager" 都命中)。

## 2. 已经做完 (2026-09-17/18, 见 [[project_dr1m90_wifi_retest]])
aarch64 musl 工具链 + zlib/lz4 静态库; **iperf3 / ksink / pov_rxd 的 aarch64 构建**(pov_rxd 零警告编过, x86 sim 回归 PASS);
**带无线栈的 DR1M90 内核**(6.1.111-rt42 aarch64, gcc 15.2 一次编过) + 9 个模块 + MT7961 固件 + regulatory.db;
做卡流程(`tools/make_dr1_test_card.sh`, 从 uImage 头自动判架构) + 卡上一键恢复脚本;
WiFi 全链路打通并测出能力(159 台架顶 / CPU 余 33% / eth0 941)。

## 3. 还缺的
| 项 | 说明 |
|---|---|
| **PL bitstream** | TD 器件串 → `DR1M90GEG484`; `bootgen -arch dr1m90`(**4 处**: 三个 build.sh + gauge_obs.sh:90); `-speed 2` 能否接受以试跑为准 |
| **`povmem_dr1.ko`** | 对 DR1M90 内核重编 —— 🎯 **而且很可能要大幅简化, 见 §4** |
| **`povctl`** | aarch64 重编 |
| **dtb (CMA=96MB)** | aarch64 版 |
| **`povboot.sh`** | 路径/架构适配; 挂钩补丁按 md5 钉死 DR1V90 版(BASE_MD5 21933ad7) ⇒ DR1M90 版定稿后要用 `tools/mk_hook_patch.py` 重生 |
| 🔴 **SRST_CTRL2 bit4** | GP0 主口复位。DR1V90 上是 **OpenSBI 加载 PL 时**放开(0x33), **不是 BOOT.bin**; DR1M90 靠 **ATF**, **会不会照做未查**。⇒ PL 加载后、第一次碰 GP0 前**回读 bit4**, 为 0 则读改写。**这是头号风险** |
| 文件名/pidof | 板端脚本写死 `*_riscv64`(含 `load_pov_jtag.sh` 的 pidof 忙检查) ⇒ 去后缀或加 `uname -m` 校验 |

## 4. 🎯🎯 头号发现: DR1V90 那两堵墙的根因**都是 RISC-V 专属的**
| 现象 | DR1V90 的根因(已查实) | aarch64 上还成立吗 |
|---|---|---|
| **`cpy` 162 ms**(Zynq 只要 20-26 ms, 差 6-8×) | CPU **无 Svpbmt**(dtb `riscv,isa="rv64imafdc"`, 运行时探测失败 ⇒ `_PAGE_NOCACHE=_PAGE_IO=_PAGE_MTMASK=0`) ⇒ `pgprot_writecombine()/noncached()` 展开成**原样返回 = 空操作** ⇒ 帧区被迫可缓存 ⇒ 必须显式回写 8.85 MB([[reference_dr1_cache_and_frame_memory]]) | ❌ **不成立**。ARM64 的 pgprot 是页表 MAIR 属性, **无条件有效**, 不需要运行时探测 |
| **PL 解码连推 37 帧卡死** | 09-17 坐实 H1: 内核 `ccm_dcache_op` **开着中断**被软中断改 CSR **0x5cb** —— 而安路 CCM 是 **RISC-V 的 CSR**, 这条回写路径本身就是为绕过上一行才存在的 | ❌ **大概率不存在**。ARM64 用标准 cache 维护指令, 没有那个 CSR |
🎯 **旁证: Zynq(Cortex-A9, ARM) 的 `cpy` 只要 20-26 ms, 正是因为它能把帧区映射成 write-combining。DR1M90 是 Cortex-A35, 同一机制。**
⇒ **DR1M90 不只是"把 DR1V90 重编一遍", 它很可能顺手消掉 DR1V90 现在最难的两个问题**,
  其中 PL 解码卡死是[[project_wifi_300m_target]]认定的**当前唯一真正挡路的东西**。
⚠ **这是基于机制的强假设, 不是实测。** 验证很便宜: 板上 mmap 一块 CMA, 看 `pgprot_writecombine` 是否真生效
(或直接量 `cpy` 时间, 判据是 **20-26 ms 档而不是 162 ms 档**)。
🔴 **这应该是上板第一件事** —— 它的答案决定 `povmem_dr1.ko` 要不要大改, 会影响后面所有排期。

## 5. 并行分工 (板子只有 DR1M90_01 一块在用, 共 3 块)
| 线 | 内容 | 占板子 | 依赖 |
|---|---|---|---|
| **A** | PL 重新综合到 DR1M90GEG484 + bootgen -arch dr1m90 | ❌ | TD 已装 |
| **B** | povmem/povctl aarch64 重编 + §4 假设成立时的代码简化 | ❌ | DR1M90 内核树已有(`~/dr1m90_kernel`) |
| **C** | 上板: §4 判据 → SRST_CTRL2 bit4 → PL 加载 → CMA | ✅ | 要 A 的产物 |
| **D** | WiFi 那条(AP 到货后) | ✅ | **与 C 抢板子** |
⇒ **A、B 现在就能并行开工, 都不占板子。** C 等 A 出产物; C 与 D 冲突, 但还有两块 DR1M90 没拆封。
