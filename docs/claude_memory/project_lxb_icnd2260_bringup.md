---
name: 鹿小班 × ICND2260 首次点亮工程 (2026-08-19)
description: 转接板 zynq-lxb_2260_V0.1 网表 + 选 TTL 3 通道的理由 + 代码在 zynq_pov/icnd2260/, 仿真与布线都过但没上过板
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

## 定了 TTL 3 通道，理由

- BANK 33 的 VCCO 是 3.3V，7 系列 HR bank **出不了 LVDS_25**，板上也没有 LVDS 驱动器
  ⇒ mini-LVDS 在这块板上走不通（量产形态才需要，见 [[reference_icnd2260_spec]] 关 2）。
- 手册 §11 的寄存器默认表**本身就是 TTL-3 通道**（`0xb4[5:4]=10`、`0x06[9]=0`、`0x1a[9]=0`）。
- 带宽 3×25MHz×双沿 = 150 Mbps ⇒ 单颗 1,628 fps，台面够用。

🔴 **100Ω 跨接电阻（R7~R10）的处理**：TTL 3 通道下 N 侧被芯片忽略，但电阻把 P/N 连着。
RTL 把 **N 侧驱动成与 P 侧同电平**（等电位、零电流）。**驱动成反相就是 33 mA/根。**

## 四个待确认项（会改设计）

1. **芯片 VDDD 从 3.8V 还是 2.8V 取？** LED 板（40×48）图纸不在这个工程里。决定上电顺序，
   也决定 **LVDS_EN 是否被拉低** —— 拉高的话 TTL 数据全丢。
2. **TTL 的 tSU/tHLD 手册没给**（只有 mini-LVDS 的 1/4 tLVCP）。现按「边沿对齐」实现，
   打不亮先翻 `DCLK_Q90`。
3. **默认寄存器表算出来只有 ~763 fps**（G = 64×32×8 = 16384，600M/(16384×48)）。
   台面够，跑 POV 必须重算 `0x00`/`0x01`。这正是发给厂家那份需求书问的事。
4. **ACK 回读没做**（脉宽编码解调）。「芯片到底活没活」最硬的判据，值得早做。

## 做到哪一步

✅ 协议层自校验仿真通过（TB 里有按手册写的解码器，逐字段对拍，全尺寸 48 扫/64 空屏帧也过）
✅ `xc7z020clg484-1` 综合+布线：307 LUT / 252 FF / 2 BRAM / 16 IOB，WNS +0.411 / WHS +0.154
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
