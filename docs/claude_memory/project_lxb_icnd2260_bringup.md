---
name: 鹿小班 × ICND2260 首次点亮工程 (2026-08-19)
description: 转接板 zynq-lxb_2260_V0.1 网表 + 08-19 定走 mini-LVDS(BANK33 可调到 2.5V) + 代码在 zynq_pov/icnd2260/ 分支 feature/icnd2260-lvds, 仿真与布线都过但没上过板
type: project
---

2026-08-19 起的工作：让**鹿小班**（XC7Z020-CLG484）通过转接板驱动**单颗 ICND2260**（40×48）。
代码在 **`zynq_pov/icnd2260/`**，`README.md` 是入口，`docs/00_board_and_protocol.md` 是详细记录。
上游账本见 [[reference_icnd2260_spec]]（芯片规格 / 级联 / 带宽）。

## 板子：两块 2260 转接板，只有鹿小班这块画完了

| 目录（`D:\工程项目\硬件\pov\`） | 状态 |
|---|---|
| **`zynq-lxb_2260_led4048V0.1`** | ✅ 鹿小班 GPIO1 ↔ 屏 J1，信号全通（SCH 08-13） |
| `zynq-mlp_2260V0.1` | ⚠ 半成品：J1 侧画了 2260 信号，**P1 侧还是老屏那套**，两边只有 DCLK 通 |

🔴 **两块的 `SCH/LKS_FOC.pdf` 都是 7 月的旧版（跟 pV1.2 那份字节数一样），里面还是
1-bit 老屏的 DCLK/LAT/GCLK/R1..B3。只看 PDF 会以为 2260 板还没画。**
⇒ 核板子前先比 `.SchDoc` 与 `.pdf` 的时间戳。写了 `icnd2260/tools/schdoc_netlist.py`
直接解 Altium OLE（`FileHeader` 流 + 并查集），不依赖 PDF 导出，也不用装 Altium。

## 转接板网表（信号名直接用 FPGA 的 site 名标注，不用查排针脚号）

R_P/N=L3P/N(V22/W22)、G_P/N=L9P/N(Y20/Y21)、B_P/N=L7P/N(AA22/AB22)、
CLK_P/N=L8P/N(AA21/AB21)、DCLK=L23N(AA13)、SYNC=L12N(AA18)、ACK=L24N(AB15)、
EN_3V8=L19P(V14)、EN_2V8=L19N(V15)。两路 BL8032 出 3.9V/3.0V。

**两个要记住的设计意图**：
1. **两路电源的 EN 都归 FPGA 管且带 100k 下拉** ⇒ 复位态电源是关的，固件必须主动开；
   顺带这是**唯一的芯片复位手段**（RSTN 没引到连接器）。
2. **板子同时铺了 TTL 和 mini-LVDS 两条路**：差分对的 P 侧正好是芯片的 `SDI_R1/G1/B1`
   （球 D1/E1/F1），N 侧是 `SDI_R2/G2/B2`，另有独立单端 DCLK。
   ⇒ 一块板两种模式都能试。

## 🔴 2026-08-19 改口径：走 **mini-LVDS**，不是 TTL

用户确认「需要用 lvds 接口」。代码在分支 **`feature/icnd2260-lvds`**（从
`feature/icnd2260-dualface` 切出），TTL 那套保留作调试退路。

**能走 LVDS 的关键发现：鹿小班 BANK 33 的 VCCO 是可调的。**
逐脚核原理图 P1 的电源引脚矩阵：VCCO_35/34/13/0 都固定 `VCC3V3`，
**只有 VCCO_33 挂在 `VCCIO_ADJ`** 上（GPIO1 那 34 根 IO 正好全在 BANK 33）。
`VCCIO_ADJ` 由 U6（TPS563210 类，Vref 0.768V）产生，反馈 R13(上)/R14(下)：
```
现状 R13=33K  / R14=10K → 0.768×(1+3.3) = 3.302V  (网名 PG_3V3 ✓ 自洽)
改成 R13=22.6K(1%)      → 0.768×(1+2.26)= 2.503V  ⇒ LVDS_25 可用
```
⇒ **只换一颗电阻**。已用 Vivado 实跑 OBUFDS+LVDS_25 落在这四对 ball 上，
place/route 零错误，坐实可行。同 bank 单端信号跟着变 LVCMOS25。

⚠ 连带要确认（LED 板图纸不在手上）：2260 的 `VDDD` 是 2.8V 还是 3.8V ——
3.8V 的话 2.5V 驱不动 I_SYNC（VIH 2.66V），且 ACK_O 3.8V 灌进 2.5V bank 会吃钳位电流。

### LVDS 与 TTL 的四个实质差别（每条都能单独把屏搞黑）
1. **VCCO 必须 2.5V**（上面）
2. **转发时钟要 90° 移相**：mLVDS 的 tSTU/tHLD = 1/4 tLVCP ⇒ 芯片在**位中间**采样；
   TTL 是边沿对齐，**要求正好相反**
3. **第一通道是 B 不是 R**：§3 传输模式表「寄存器配置」列 —— TTL 走 SDI_R1，
   mLVDS 一律走 D0IP/N，而 D0 = SDI_B1（球 F1/F2）。第一通道独家发 VHEAD ⇒ 必须是 lane0。
   ⇒ 帧缓存字序 TTL 是 {B,G,R}、LVDS 是 {R,G,B}。**搞反不报错，只是红蓝对调。**
4. **寄存器表要改**：0x06[9]=1、0x1a[9]=1（§11 那份默认值是 TTL-3 通道）

### ACK 回传解调已实现 —— 首光判据从「屏亮不亮」升级成「LED2 亮不亮」
`icnd2260_ack_rx.v`（手册 P12 脉宽编码：空闲高 / start 低 >1µs / 每位先高 w1 后低 w2，
`w1>w2` 判 1）。序列器每 16 帧插一条读寄存器指令产生回包，顶层把 `crc_ok` 锁到 **LED2**。
⇒ **LED2 亮 = 链路通 + 芯片收到指令 + CRC 推断正确，三件事同时成立**。
比"屏亮不亮"硬得多（屏不亮还可能是电流/灰度/LED 板的事）。
🔴 回包里**数据高位先送，唯独 CHKSUM 从 LSB 开始回传**（手册原话），`REV_CRC` 参数可切。

### 分支矩阵（板子到了按这个二分，见 `docs/03_branches.md`）
主线 `feature/icnd2260-lvds`，四个变体每个只改一处：
`-ttl`（RTL 相同，只出 TTL 版 bit —— **3.3V，不用先换 R13 就能上板**）/
`-phase270`（CLK_PHASE 90→270，查采样相位）/ `-nocrc`（VID_CRC=0，查 CRC 推断）/
`-slow`（CLK_DIV 24→48 + XDC BITCLK_NS 必须同时改，分开速率与协议问题）。

### 三条「仿真过≠芯片认」的推断（上板要验）
- CHKSUM = CRC-16/CCITT（poly 0x1021 / init FFFF / 高位先入 / 不反射不取反）——
  从手册 P13 的 LFSR 图（x^0/x^5/x^12/x^15 标注）反推
- 图像数据每颗芯片末尾各一个 CHKSUM，多通道每 lane 各算各的
- 「第一组差分对」= D0
⇒ 上板第一件事: 看 LED2。亮了这三条就一起坐实; 不亮就按分支矩阵二分。

---

## 原先定 TTL 3 通道的理由（已被上面取代，保留作退路依据）

- BANK 33 的 VCCO 是 3.3V，7 系列 HR bank **出不了 LVDS_25**，板上也没有 LVDS 驱动器
  ⇒ mini-LVDS 在这块板上走不通（量产形态才需要，见 [[reference_icnd2260_spec]] 关 2）。
- 手册 §11 的寄存器默认表**本身就是 TTL-3 通道**（`0xb4[5:4]=10`、`0x06[9]=0`、`0x1a[9]=0`）。
- 带宽 3×25MHz×双沿 = 150 Mbps ⇒ 单颗 1,628 fps，台面够用。

🔴 **100Ω 跨接电阻（R7~R10）的处理**：TTL 3 通道下 N 侧被芯片忽略，但电阻把 P/N 连着。
RTL 把 **N 侧驱动成与 P 侧同电平**（等电位、零电流）。**驱动成反相就是 33 mA/根。**

## 四个待确认项（会改设计）

1. ~~I_SYNC / ACK_O 的电平兼容~~ —— **2026-08-19 用户确认 LED 板上有 245 电平转换，
   这条不成立了**。仍要确认 **`LVDS_EN` 的接法**：走 LVDS 要拉**高**，走 TTL 要拉**低**（这根是两种模式的
   物理开关，接反了数据全丢），以及 **LED 板上有没有自己的 100Ω 端接**（转接板已经有一组，
   两组并联 Vod 减半）。
2. **TTL 的 tSU/tHLD 手册没给**（只有 mini-LVDS 的 1/4 tLVCP）。TTL 那套按「边沿对齐」实现，
   打不亮先翻 `DCLK_Q90`；LVDS 那套按 1/4 周期做了 90° 移相。
3. **默认寄存器表算出来只有 ~763 fps**（G = 64×32×8 = 16384，600M/(16384×48)）。
   台面够，跑 POV 必须重算 `0x00`/`0x01`。这正是发给厂家那份需求书问的事。
4. **ACK 回读没做**（脉宽编码解调）。「芯片到底活没活」最硬的判据，值得早做。

## 🎯 2026-08-19 首次上板 (FPGA 侧全通, 屏侧未通)

**电阻改动**: 用户按方案 B 在 R13(33K) 上并了 **68K**(手上只有 68K/75K)。选 68K 不选 75K
是因为偏低那侧更安全 —— 标准 LVDS_25 的 Voc 上限 1.375V 本来就超 2260 的 VIC 窗(1.3V)。

**JTAG 身份确认踩过一次**: 这台机器上挂了两个适配器, 而 **FS03 也是 Zynq 板**
(记忆 `reference_anlogic_dr1_fs03_eval`: 「米联客 FS03-DR1 板 = 现有 FS03-Zynq 板的同构版」)
⇒ 差点烧错板子。判据: 第二个适配器 `No devices detected` + `pov.local` 解析不到
+ FS03 本来就是挂转子上走 WiFi 远程的、不该占 JTAG。后经用户确认「fs03那个拔了」。
⇒ **以后烧板前先枚举所有 JTAG target, 别默认 index 0 就是要烧的那块。**

**VIO 实测 (两个速率, 各自与手推模型对上)**:

| CLK_DIV | 位时钟 | 理论 fps | **实测 fps** | 偏差 |
|---|---|---|---|---|
| 24 | 41.67 MHz | 2,649.5 | **2,648** | 0.06% |
| 48 | 20.83 MHz | 1,324.6 | **1,324** | 0.05% |

⇒ 每帧 15,728 拍这个手推值是对的(差值正好是当初估「可忽略」的指令间握手开销)。
   **MMCM/序列器/发送器/帧结构整条链一次性验证通过, 且两个速率下都成立。**

`status = 0xf88c`: mmcm_locked / running / out_en / en_3v8 / en_2v8 全 1,
ph=8(P_WAIT) sub=3(DISPLAY) —— 上电流程走完、帧循环在正常显示阶段。

**屏侧一点动静没有**: `ack_frame_cnt = 0` 且 `ack_err_cnt = 0`。
🔴 这个组合是有判别力的: 协议/CRC 错会表现为 **frame_cnt 涨但 crc_ok 不亮**,
线上有噪声会表现为 **err_cnt 涨**。两个都是 0 ⇒ **指向物理层, 不是协议层**。
且 20M 也不通 ⇒ 与速率无关。

## 🔴 未解决: 转接板与 LED 板的连接器脚位对不上

盘上只找到**我们自己**的 KiCad 面板 `hardware/pcb/icnd2260_panel_v1`, 它配的是
**我们自己**的 `icnd2260_adapter_v1`, 而用户在用的是硬件那边画的 Altium 转接板
`zynq-lxb_2260_V0.1`。三者两两不兼容:

| | Altium 转接板 J1 | KiCad 面板 P1 |
|---|---|---|
| 1-5 | VCC_3V8 输出 | GND / CK_P / CK_N / GND / GND |
| 7-14 | GND | B_N / G_P / G_N / R_P … |
| 16-20 | VCC_2V8 输出 | GND / I_SYNC / ACK_O |
| 29-31, 34-36 | B_N / G_P / R± | **VDD_3V0 / VDD_3V8 (面板供电输入)** |

直接对插 ⇒ **3.8V 灌进面板 GND 和 2260 的 mLVDS 时钟输入, 面板反而没电**。
两块转接板的 FPGA 引脚也完全不同(Altium: CLK=L8/B=L7/G=L9/R=L3;
KiCad: CLK=L7/B=L8/G=L10/R=L11) ⇒ **现有 bit 只对 Altium 那块有效**。
⚠ 截至 08-19 用户未确认到货的是哪块面板。**没核对脚位之前别插电。**

## 做到哪一步

✅ **两套**协议层自校验仿真通过（TB 内含按手册写的独立解码器 + LVDS 侧独立重算 CRC，
   全尺寸 48 扫/64 空屏帧都过）
✅ `xc7z020clg484-1` 综合+布线：TTL 307 LUT / WNS +0.411 / WHS +0.154；
   **LVDS 465 LUT / 2 BRAM / 16 IOB / WNS +0.212 / WHS +0.120**
✅ ACK 解调自校验 TB 四个用例全过（正常帧 / 变长 / CRC 改坏能抓 / 毛刺不误触发）
✅ DRC 只剩 `ZPS7-1 PS7 block required`（纯 PL 设计固有）
✅ `tools/build_bit.tcl -tclargs lvds|ttl` 可直接出 bit
✅ **已上板**: FPGA 侧全部验证通过 (见上「首次上板」节), 屏侧未通。

上板前先做 README 里那三件事（确认 LVDS_EN 接法 / 测试图先用 `--mode single` 限流 /
boot mode 拨 JTAG，见 [[feedback_lxb_boot_mode_sw3]]）。

## 顺手踩到的三个坑（都写进代码注释了）

- **一个 ODDR 扇出到两个 port** ⇒ place 报 `[Shape Builder 18-152]`，OLOGIC 里的单元
  只能直连 IOB。每个物理脚各一个 ODDR。
- **驱动 BRAM 地址的寄存器不能用异步复位** ⇒ `[REQP-1839] RAMB36 async control check`。
  全改同步复位。
- **`set_output_delay -min` 是「外部器件要求的保持时间取负」**。边沿对齐的接口天生 hold≈0，
  随手编个 `tH=5ns` 必然违例（实测 WHS −5.4ns），那是约束自相矛盾不是设计有问题。
  改成用 `-max (T/2−1) / -min +1` 把数据沿卡在 DCLK 沿 ±1ns 内，两边各剩 ~0.4ns。

引脚表的求证过程还牵出旧记忆的错误，见 [[reference_lxb_gpio1_pinout]] 的 08-19 更正节。
