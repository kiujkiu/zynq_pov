---
name: 安路 DR1 (米联客 MLKPAI-FS03-DR1) 替代 Zynq7020 可行性评估
description: 484 球逐脚核对确认 pin2pin + CEP2 连接器与现板一致; PL 无忧, 风险全在 PS 侧 (RISC-V 单核 / Buildroot / 无 WiFi 栈)
type: reference
---

2026-07-30 用户下载了 `D:\BaiduNetdiskDownload\03_MLKPAI_FS03_DR1V90GEG` 资料包并打算买 2 块板试。
本文是逐脚/逐文档核对后的结论。上位文档见 [[reference_port_to_other_fpga_deps]]。

## 1. pin2pin 说法 = 真的 (484/484 逐球核对过)

方法: `xc7z020_clg484.bsd` + Vivado `link_design -part xc7z020clg484-1` 导 `get_package_pins`
对 `DR1M90_DR1V90GEG484_PINLIST.pdf` (pymupdf 按坐标重排列) 全 484 球比对。

| 类别 | 结果 |
|---|---|
| PL IO | **200 球位置全同**; 差分极性全同 (96P+96N+8 单端); 32 个时钟脚全同 (Zynq SRCC/MRCC ↔ DR1 GCLKIOT/C); 甚至配对序号也对齐 (Zynq L11..L14 ↔ DR1 R11..R14) |
| Bank 号 | 只是重编号: Zynq **35→33, 34→32, 33→31, 13→11** |
| PS MIO | 54 个全同位置 (PS_MIOn ↔ PS_IOn_200/201), QSPI=1-6 / USB=28-39 / UART=48,49 连编号都照抄 |
| PS DDR | 75 球全同位置, 且升级成 DDR4-ready 命名 (A15_CASN / A16_RASN / ACT_A14 / BG0_BA2) |
| GND / 电源 | GND 64 球同位; ADC 组 (VP/VN/VREFP/VREFN/VCCADC/GNDADC) 同位 |

**唯一的物理差异 (改自家 PCB 时要动的):**
- **VCCINT 1.0V → 0.95V**, 且 Zynq 的 VCCINT / VCCBRAM / VCCPINT **三轨合并成一个 VCCINT**;
  VCCAUX / VCCPAUX 合并成 VCCAUX (1.8V 不变)。
- Zynq 的 CFGBVS(T13) → DR1 是 **RSV_NC**(不能接 3.3V 当 strap 用, 且此类脚不支持 IDDR/ODDR);
  VCCBATT / RSVDVCC1-3 / DXP / DXN → **NC**。

## 2. 米联客 FS03-DR1 板 = 现有 FS03-Zynq 板的同构版 (这是最大利好)

- **CEP2 连接器 (=现板 J12) 球位 100% 一致** — 用 `led_panel_chain.md` 里 v1.2 的 20 根信号逐一对过:
  J12.12=Y10, .15=AA9, .14=AB9, .21=AB5, .4=W12, .7=Y9(手册印成 Y19, 笔误), .23=W6 … 全中。
  ⇒ **50pin 线 + 米联派接口板 + 双屏 + 光电传感器原样插上就能用, XDC 引脚表 1:1 平移**(只有 bank 名 13→11)。
- 原理图网名/位号也照抄: `VCC_CEP1/2`, `VIN_5V0`, 磁珠 **L16/L17/L18/L19**(同样的 5V 灌入改法),
  跳帽 **ADJ_BANK11**(对应现在的 ADJ_BANK13) / ADJ_BANK33。
- 板载: DDR3L 512MB 16bit@1333 (GDP2BFLM, 兼容 MT41K256M16), QSPI 256Mb(GD25LB256E, 1.8V),
  **USB3320 ULPI + Type-A host**, YT8531 千兆, 双 TF, HDMI 输出, MIPI-RX, PS_CLK 33.33M / PL_CLK 25M,
  VCCINT 8A, Type-C 5V 供电, 85×56mm。
- ⚠ **JTAG 要专用转接板 + 安路下载器**(不是 USB 直插), 下单时一起买。

## 3. PL / RTL 侧: 基本无风险

- 现设计实测占用 (system_wrapper_utilization_placed.rpt): **LUT 2602 (4.9%) / FF 2828 / BRAM36 9 / DSP 0 / IOB 31 / MMCM 0 / PLL 0**。
  DR1V90 有 52,480 LUT6 / 104,960 DFF / 280×ERAM20K(5600Kb) / 240 DSP / 200 PL IO — 与 7020 同档, 富余极大。
- 唯一原语依赖 14 处 `ODDR SAME_EDGE` → 安路 IOL 有 **oDDRx1** 模式, 语义完全对应
  (D0/D1 同沿采样, 分别在 SCLK 上升/下降沿出 pad), DCLK 那个"D1 给上一拍值把沿推迟半拍"的手法照样成立。
  仍须**重做时序收敛 + 重测眼图**(clk→pad 延迟/抖动不同厂不同)。
- PL IO LVCMOS33 手册标 **300 Mbps** 上限, 现需求 50 Mbps/lane, 余量足。Bank11 VCCIO 可跳 3.3V ✓。
- AXI 口: DR1 PS = 2×GP master + 2×GP slave + **2×HP slave(64bit)** + p2f_clk0-3 + f2p_irq。
  现设计只用 M_AXI_GP0 + S_AXI_HP0, 够用 (注意 Zynq 有 4 个 HP, DR1 只有 2 个, 以后 4×IP 并行要留意)。

## 4. PS 侧才是真风险 (工作量都在这)

**买板必须先定 SKU: DR1M90 (ARM) 还是 DR1V90 (RISC-V)。资料包/米联客这块板卖的是 DR1V90G。**

| | DR1M90GEG484 | DR1V90GEG484 (资料包这颗) |
|---|---|---|
| CPU | **双核 Cortex-A35 64bit @800M(板手册标 1G)** | **单核 RISC-V 600 MHz** — 出厂 dtb 实测 `clock-frequency=0x23C34600`, `riscv,isa=rv64imafdc` (**无 B 无 V**, datasheet 吹的 P 扩展没在 isa 串里), `mmu-type=sv39` |
| Cache | L1 32K×2 + **L2 512K** | L1 32K + ITCM/DTCM 256K×2, **无 L2** |
| PS-PL | 多一个 ACP 64bit | 多一个 32bit AHB |
| 官方对标 | 手册直接拿 CA9×2 当"竞品"比: 访存 2363 vs 1007 MB/s | — |

现软件栈 = Debian + 自编 **Linux 6.6** + systemd×3 + `pov_rxd`(TCP+zlib, A9 上解压一帧 64ms)
+ `povmem.ko` + `/dev/mem` + **mt7921u USB WiFi**。搬到 DR1 要面对:

1. **出厂系统是 Buildroot/busybox (root/root), 不是 Debian** → systemd 服务要改成 init 脚本或自己装。
2. 出厂内核 = **6.1.111-rt42 riscv64**(PREEMPT_RT, Nuclei gcc 10.2)。
   实测把 `uImage.lz4` 解开搜过: **没有 cfg80211/ieee80211/mt76 任何字样 → 无线栈完全没编进去**。
   要用 WiFi dongle 必须自己重编内核(buildroot 有 `make_kernel.sh`, mt7921u 在 6.1 主线里, 可行但要配 firmware)。
   USB 控制器是 **dwc2**(不是 Xilinx 那套), host 模式可用但性能一般。
3. 以太网是 **eqos/stmmac + YT8531**, 比 Zynq 的 GEM+gmii_to_rgmii 反而简单。
4. **单核 RISC-V 跑 zlib 解压 + TCP + 写 DDR, 大概率比 A9 双核更慢**, 且没有第二核可甩活。
   ⇒ 若走 DR1V90, [[feedback_povrxd_stop_and_wait_limit]] 的三步流水/双核方案直接失效, 推流架构要重设计。
5. 参考 dts (`anlogic-dr1.dts`) 里 memory 是 `0x3fe00000`(≈1GB) + CMA 256MB — 与本板 512MB 不一致,
   DDR 地址/保留段布局要自己重规划(povmem 那块 WC 区一并重算)。

## 5. 工具链

⚠ **2026-08-05 修正**: 版本写错了, 随板教程实际指定 **TD_5.9.1_DR1_2025.1_151.508 + FD_2025.1**;
且 **license 已过期是硬卡点**(NL 版照样查) — 安装实测全过程见 [[reference_anlogic_td_toolchain_setup]]。

~~TD **5.9.1_DR1_2024.10**(≈Vivado) + FD **2024.10**(≈Vitis)~~ + 安路 JTAG 驱动; 要装 license;
有在线逻辑分析仪(≈ILA), 可配 ModelSim 仿真。
流程同构: TD 建工程 → Export Hardware Platform File(**.hpf** ≈ .xsa) → FD 建 platform + **soc_fsbl** →
虚拟机里 `uisrc-lab-anlogic` 那套 `make_rootfs/uboot/kernel/create_image.sh` → 烧 TF 卡 → SW1/SW2 拨 OFF-OFF 从 SD 启动。
**没有 HLS 对等物** — 现设计已是纯 RTL, 不受影响; 但以后想再用 HLS 就断路了。

## 6. 结论 / 下单建议

> ### 🔴 2026-08-05 定案与重新评估
> **SKU 已定: 走 RISC-V 版 (DR1V90G)。** 下面第 88 行"优先问有没有 ARM 版"这条建议不再适用。
>
> **而且当初对 RISC-V 的担忧被实测大幅削弱了**: 本文第 4 节第 4 条写
> "单核跑不动 ⇒ 三步流水/双核方案直接失效, 推流架构要重设计" —— 那是 7-30 写的。
> 8-05 上板实测 ([[feedback_lz4_onboard_reality_check]]) 发现 **双核并行加速只有 1.06×**
> (lz4 计算少、吃内存带宽, 两核互抢)。⇒ **丢掉第二个核只值 6-18%, 不是 2×。**
>
> 同日在现役 Zynq 上用同一二进制同一帧复测 ([[reference_bench_codec_kit]]):
> 单核 lz4_dec **空载 215.2 / 带载 111-131 MB/s**，与那条记忆的 41.2ms/8.85MB=214.8 MB/s 互印。
>
> ⇒ **RISC-V 的真实风险已从"没有第二个核"转移到"无 L2 + DDR3L 只有 16-bit"**,
> 因为 lz4 解码被证明是**内存带宽瓶颈型**负载。这正是 bench 要在板上量的东西。
> 另注: 目标不是"越快越好" —— 翻页天花板 = 转速 = 16.1 fps ⇒ 一圈 62 ms,
> CPU 只要把 `dec×2 + cpy` 压进 62 ms 就不再是瓶颈。
>
> 出厂 Linux/制卡/boot mode 见 [[reference_dr1_factory_linux_boot]]。
>
> ### 板子首次点亮实测 (2026-08-05 傍晚, 串口 COM5)
> ```
> Linux anlogic 6.1.111-rt42 #1 PREEMPT  riscv64      nproc = 1
> isa = rv64imafdc   mmu = sv39   mvendorid 0x536 / marchid 0xc900 / mimpid 0x20300
> MemTotal 479,420 kB (468 MB)    /mnt/mmcblk0p1 = TF 卡 FAT 分区自动挂载
> ```
> 🔴 **主频 `clock-frequency = 0x2FAF0800` = 800 MHz, 不是本文第 4 节写的 600 MHz。**
> 那个 600 MHz 读的是资料包里的**参考 dts**(`anlogic-dr1.dts`)，**实板 dtb 是 800 MHz** ⇒ 白捡 33%。
> ⚠ 教训: 参考 dts ≠ 实板 dtb，性能参数必须从**板子自己的** `/proc/device-tree` 读。
>
> 板上工具: `wget` / `tftp` / `base64` / `md5sum` 有；**`scp`/`ssh`/`nc` 没有**(Buildroot busybox)。


- **能替代, 且是同类项目里最省事的一种换平台**: 板级插座和线束零改动, RTL 只有 14 处 ODDR + 约束要改。
- **优先问米联客 FS03 有没有 DR1M90(ARM A35) 版 + 对应 aarch64 BSP**; 有就买 ARM 版, 软件栈几乎可平移。
  只有 RISC-V 版可选时, 要接受"推流/解压架构重设计"这笔账。
- 买 2 块的验证顺序 (从最能证伪的开始):
  1. 出厂系统起来 + 千兆/USB host 通 → 2. TD 点亮 CEP2 上的 LED 屏静态图形(证明 IO+bank 电压+线束)
  → 3. oDDRx1 换掉 ODDR, 抓 DCLK 眼图 + 50 Mbps 时序收敛 → 4. 重编内核带无线栈 + 跑 pov_rxd 测单帧解压耗时
  → 5. 才谈整链帧率。第 3、4 步是两个真实的"可能卡住"点。
- 🔴 别忘了 [[reference_port_to_other_fpga_deps]] 第 5 条: 当前瓶颈是逐帧 ACK 推流和转速/刷新率不匹配,
  **换 FPGA 一个都解决不了**。这次换平台的正当理由只能是供货/成本/国产化。

---

## 7. 「PL 做解压」实测账 (2026-07-30 拿 frames_robot 真实帧量的)

🔴 **前提纠正: 数据根本不稀疏** —— 6.6% 字节非零, 但 **32B 块有 75.8% 非空**(8B 块 34.9%)。
所以 zlib 那 33× **不是靠稀疏, 是靠 LZ77 找重复 + Huffman 熵编码**, 任何"简单"编码都够不着:

| 编码 | 比率 | 30fps 线速 | vs 实测 28 Mbps 链路 |
|---|---|---|---|
| 分层位图 8B/32B 块 | 2.7× / 1.3× | 387 / 809 Mbps | ❌ 14×/29× |
| 现行 RLE (protocol.h 里那个零游程) | 4.4× | 243 Mbps | ❌ 8.7× |
| RLE 改进版 (varint 零游程+字面段) | 5.7× | 186 Mbps | ❌ 6.6× |
| delta + RLE 改进版 | 13.3× | 80 Mbps | ❌ 2.9× |
| **zlib-6 (现行)** | **33.7×** | 31.5 Mbps | 1.12× |
| zlib Z_FIXED | 27.7× | 38.3 Mbps | 1.37× |
| **delta + zlib-6** | **38.9×** | 27.3 Mbps | ✅ 0.98× (唯一天然过线) |

⇒ **「PL 解压」= 在 PL 里做 DEFLATE inflate, 不是做 RLE。**

### 吞吐可以靠切流解决 (关键发现: 切开几乎零代价)

硬件 inflate 典型 1 B/clk = 75 MB/s @75MHz, 而 30fps 要 **132.7 MB/s** → 单引擎不够。
编码器是自家的, 可切成 N 路独立 zlib 流:

| 切分 | 比率 | 每引擎需求 |
|---|---|---|
| 1 路 | 33.7× | 132.7 MB/s ❌ |
| 2 / **4** / 8 路 | 33.6× / **33.4×** / 33.1× | 66 / **33.2** / 16.6 MB/s ✅ |
| 360 路(每片独立) | 17.4× | 掉一半, 不划算 |

两条硬约束: **窗口必须 32KB**(windowBits=12 → 比率腰斩到 19.6×); 动态 Huffman 比 Z_FIXED 好 18%。

**推荐配置: `Z_FIXED + 4 路切分 + 32KB 窗口`** — 4 个定长 Huffman inflate 引擎, 每个只要
33 MB/s = @75MHz **0.44 B/clk**(余量 2×), 窗口 4×32KB=128KB ERAM(占 DR1 700KB 的 18%)。
定长 Huffman 省掉硬件建 Huffman 表这个最麻烦的部分; **产物仍是标准 zlib 流** →
PC 侧只改一个 strategy 参数, CPU zlib 还能解同一份数据 ⇒ **可逐字节 A/B 对照验证**。

估工: 定长版 ~500-800 行 RTL, **2-4 周**(大头在验证); 要动态 Huffman 再加 2-4 周且风险明显上升。

### 但 30fps 的前置条件不止这一个

- **链路**: Z_FIXED 要 38 Mbps, 现测 28 Mbps。唯一天然过线的 delta+zlib 要求 PL 读得到前一帧
  ⇒ 必须 DDR→DDR 解压+XOR, 再加 133 MB/s 读。
- **机械**: 30fps 需 ≥15 rps, 现 11.1 rps, 且 refresh/oe window 还没对齐 (见 [[project_pov3d_refresh_vs_rpm]])。
- **DDR 仲裁**: +133 MB/s 写 +133 MB/s 读, 而有 [[feedback_pov_4x_ip_breaks_hdmi]] 的前科。

### 决策公式

A9 单核实测 69 MB/s (64ms/帧 × 4.42MB), 30fps 要 132.7 MB/s。
**A35 双核估 180-240 MB/s ⇒ DR1M90 用软件解压就能到 30fps, 不用写这个 IP。**
所以问题化简成: **这 2-4 周 RTL 值不值 DR1M90 的差价?**
(注: 这个 IP 顺带解掉 [[feedback_povrxd_stop_and_wait_limit]] 的 stop-and-wait 瓶颈,
并给片上渲染铺路 — 买 ARM 也早晚要做, 所以选 V 的净成本 ≈ 把它提前做。)

## 8. HLS: 安路没有, 但 Vitis 产物可移植 (已核查)

资料包全文搜 `HLS/高层次综合` = **0 命中**; 工具链只有 TD + FD + ModelSim。

核查 `zynq_pov/hls_proj/proj_pov/solution1/impl/verilog/` (30 文件 = 26 .v + 4 .dat, 15,369 行):

- **零 Xilinx 原语** (RAMB/DSP48/XPM/CARRY/FDRE/SRL/MUXF 全 0 命中), AXI master/slave adapter 纯 RTL
- 是 Verilog-2001, `logic`/`always_ff` 的命中**全在注释里**
- ⇒ **Vitis HLS 可当"C→Verilog 离线代码生成器"继续用, 产物搬进 TD 综合**

搬运时要动的三处:
1. `initial begin #0 ap_CS_fsm = 2'd1;` — 寄存器初值带 `#0` 延时, TD 不吃就 sed 掉/改复位赋值
2. `$readmemh("./xxx.dat")` 相对路径按 TD 工程结构调
3. 🔴 6 处 `(* ram_style *)` TD 会忽略 → **必须看综合报告确认 RAM/ROM 仍推成 ERAM 而非散寄存器**

丢掉的是: **迭代闭环**(改 C→一键出 IP→BD 连线→打包 这条流水线断了) 和 **时序保证**
(HLS Fmax 估算基于 Xilinx 器件模型, 且本来就乐观 14× 见 [[feedback_hls_cycle_estimate_optimistic]])。

⚠ **License 是真问题**: AMD Vivado/Vitis EULA 一般限定"为 AMD/Xilinx 器件做设计"。
拿 Vitis HLS 出 RTL 跑安路, 自验证是灰区, **量产/商用前必须走采购或法务确认**。
过不去的替代: 开源 HLS(Bambu/XLS) / SpinalHDL·Amaranth 生成式 HDL / 手写
(体素投影算法本身不复杂, 15K 行里绝大部分是 HLS 展开的流水线控制)。

影响分层: **当前纯 RTL 设计 = 0**; **inflate 引擎 = 0**(位串行+控制不规则, HLS 本来就不该用);
**片上渲染路线 = 中等**(能靠离线生成继续走, 但迭代变慢)。

---

## 🔴 2026-08-27 更正: "DR1 16-bit DDR vs Zynq 32-bit" 是错的 —— **两块板一样**

本文 §板载 那行写 DR1 是 `DDR3L 512MB 16bit@1333`, 没错。
但由此推出的 "DR1 的 DDR 只有 Zynq 一半" **是错的**:

**现役 FS03 Zynq-7020 板也是单颗 16-bit** —— `PCW_UIPARAM_DDR_BUS_WIDTH = 16 Bit`,
`FREQ = 533.333313`(DDR3-1066), HIGHADDR `0x1FFFFFFF` = 512 MB 单颗 MT41K256M16。
⇒ **两块板的 DDR 峰值都是 2.13 GB/s, 完全打平。**

⚠ 到处引用的 **4.26 GB/s 对不上手上任何一块板** —— 那是"7020 芯片支持 32-bit"的能力值,
而 **16-bit 是板级选择**(ZedBoard/ZC702 都是 7z020 + 多颗并联做 32-bit)。
⇒ 想要 32-bit **要自制板, 换芯片没用**。

⚠ 另: DR1 的 DDR 控制器 DS1200 表 3-45 封顶 **1066 Mbps**, 板卡资料写的 1333 是
DDR3L **颗粒**额定值不是 SoC 能力 ⇒ "DR1 @1333 = 2.67 GB/s" 这个乐观值也不成立。

🔴 **DR1 相对 7020 在存储上真正的净劣势是容量不是位宽**:
DR1 实测 `CmaTotal: 98304 kB` = **96 MB**(dtb 原写 256 MB 静默失败退回 16 MB);
Zynq 侧 512 MB 且帧区是 write-combine 直映射, **无此约束**。
