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

### 三条「仿真过≠芯片认」的推断（上板要验）
- CHKSUM = CRC-16/CCITT（poly 0x1021 / init FFFF / 高位先入 / 不反射不取反）——
  从手册 P13 的 LFSR 图（x^0/x^5/x^12/x^15 标注）反推
- 图像数据每颗芯片末尾各一个 CHKSUM，多通道每 lane 各算各的
- 「第一组差分对」= D0
⇒ 上板第一件事: 发读寄存器指令，拿 ACK 回包对一次 CRC。**ACK 解调器还没写**（脉宽编码）。

---

## 原先定 TTL 3 通道的理由（已被上面取代，保留作退路依据）

- BANK 33 的 VCCO 是 3.3V，7 系列 HR bank **出不了 LVDS_25**，板上也没有 LVDS 驱动器
  ⇒ mini-LVDS 在这块板上走不通（量产形态才需要，见 [[reference_icnd2260_spec]] 关 2）。
- 手册 §11 的寄存器默认表**本身就是 TTL-3 通道**（`0xb4[5:4]=10`、`0x06[9]=0`、`0x1a[9]=0`）。
- 带宽 3×25MHz×双沿 = 150 Mbps ⇒ 单颗 1,628 fps，台面够用。

🔴 **100Ω 跨接电阻（R7~R10）的处理**：TTL 3 通道下 N 侧被芯片忽略，但电阻把 P/N 连着。
RTL 把 **N 侧驱动成与 P 侧同电平**（等电位、零电流）。**驱动成反相就是 33 mA/根。**

## 四个待确认项（会改设计）

1. **芯片 VDDD 从 3.8V 还是 2.8V 取？** LED 板（40×48）图纸不在这个工程里。决定上电顺序；
   BANK 33 改 2.5V 后还决定 I_SYNC 打不打得进去、ACK_O 能不能直接接。
   同时要确认 **`LVDS_EN` 的接法**：走 LVDS 要拉**高**，走 TTL 要拉**低**（这根是两种模式的
   物理开关，接反了数据全丢），以及 **LED 板上有没有自己的 100Ω 端接**（转接板已经有一组，
   两组并联 Vod 减半）。
2. **TTL 的 tSU/tHLD 手册没给**（只有 mini-LVDS 的 1/4 tLVCP）。TTL 那套按「边沿对齐」实现，
   打不亮先翻 `DCLK_Q90`；LVDS 那套按 1/4 周期做了 90° 移相。
3. **默认寄存器表算出来只有 ~763 fps**（G = 64×32×8 = 16384，600M/(16384×48)）。
   台面够，跑 POV 必须重算 `0x00`/`0x01`。这正是发给厂家那份需求书问的事。
4. **ACK 回读没做**（脉宽编码解调）。「芯片到底活没活」最硬的判据，值得早做。

## 做到哪一步

✅ **两套**协议层自校验仿真通过（TB 内含按手册写的独立解码器 + LVDS 侧独立重算 CRC，
   全尺寸 48 扫/64 空屏帧都过）
✅ `xc7z020clg484-1` 综合+布线：TTL 307 LUT / WNS +0.411 / WHS +0.154；
   **LVDS 465 LUT / 2 BRAM / 16 IOB / WNS +0.212 / WHS +0.120**
✅ DRC 只剩 `ZPS7-1 PS7 block required`（纯 PL 设计固有）
❌ **没上过板。以上全是纸面 + 工具验证。**

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
