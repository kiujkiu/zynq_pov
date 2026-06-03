---
name: POV3D LED 驱动选型最终决定 (2026-05-12)
description: 360×20Hz × 8-bit RGB POV3D 方案锁定 — Zynq 7020 CLG484 + 90× MBI5264 + 12× ICND3019 直驱, 101 PL IO, 30 MHz DDR overclock 必需
type: project
originSessionId: 4842be5b-0551-4e89-8f4c-90c7918ef105
---
# 最终锁定方案

**目标参数**：360 slice × 20 Hz × 8-bit RGB，屏幕刷新 7.2 kHz
（修正自 memory 里 720×30Hz 16-bit = 21.6 kHz 原始目标; 物理上 90 颗 MBI5264 上限是 7.8 kHz, 选 360×20 留 8.5% 富余）

**硬件清单**：
- Zynq 7020 CLG484（PL IO 200，占用 ~101 = 50%）
- 90× MBI5264 QFN24（16ch × 60-scan，60 扫整除 180 行）
- 12× ICND3019 QFN24 行管（180 rows / 16 = 12 颗）
- 3× NB3N551 时钟 fanout 缓冲
- 28,800 × RGB SMD LED 0.94mm pitch
- 6 层主控 PCB + 8 层面板 PCB

**BOM ≈ $1,108/板**

# 关键计算

## 单颗 MBI5264 极限
- 60-scan + 8-bit 数据 = 16 × 60 × 8 = **7,680 bit/frame/chip**
- DCLK 30 MHz DDR = 60 Mbps 等效 → 128 µs/frame
- 单颗刷新上限 = **7.81 kHz**（vs 目标 7.2 kHz，富余 8.5%）

## IO 预算
- 90 SDI（每颗一对一）
- 3 时钟 (DCLK / LE / GCLK，经 fanout)
- 8 控制 (VSYNC / ROW反馈 / 3019 SDI+RCLK / nRESET / Sync / Debug UART × 2)
- = **101 PL IO**

# 关键风险 + 应急路径

⚠ **DCLK 必须超频 30 MHz DDR**（features 页 spec 15 MHz typ, switching 表 max 30 MHz）

| 实测 DCLK | 单颗刷新 | 应急 POV 配置 |
|---|---|---|
| 30 MHz DDR (理想) | 7.81 kHz | **360×20Hz** ✓ |
| 25 MHz DDR | 6.51 kHz | 360×18 Hz / 320×20 Hz |
| 20 MHz DDR | 5.21 kHz | 260×20 / 360×14 Hz |
| 15 MHz DDR (spec) | 3.91 kHz | 180×20 Hz / 360×10 Hz |

**Phase 1 验证必做**：用示波器打 30 MHz DDR 时 setup/hold/eye diagram, 跨 ≥5 颗样片测稳定性

# 为什么不选其他配置

- **503×30Hz 16-bit (终极目标)**: 屏幕需 15.1 kHz, 单颗只到 3.66 kHz, 差 4×, 90 颗物理做不到
- **503×30Hz 8-bit**: 屏幕 15.1 kHz, 单颗 7.3 kHz, 差 2×, 需 180 颗 (PCB 大改)
- **503×14Hz 8-bit (Scheme B)**: 屏幕 7.0 kHz, 跑得到但体刷新 14Hz 略闪
- **360×20Hz 8-bit (当前选)**: 屏幕 7.2 kHz, 90 颗刚好, 体刷新 20Hz 已是电影 24fps 的 83%

# 物理布局

```
┌──────────────────────────────────────────┐
│ Stripe 0 (rows 0..59):  30× MBI5264 + 4× 3019 │
├──────────────────────────────────────────┤
│ Stripe 1 (rows 60..119): 30× MBI5264 + 4× 3019│
├──────────────────────────────────────────┤
│ Stripe 2 (rows 120..179): 30× MBI5264 + 4× 3019│
└──────────────────────────────────────────┘
       每段 = 10 颗 R + 10 G + 10 B = 30 颗 MBI5264
```

# 升级路径（PCB 预留）

**Phase 2 升级（不动主面板 PCB）**：
- 加 9 颗 MachXO2-640HC CPLD（预留焊盘）→ 主 FPGA IO 砍到 30
- 加 8 对 LVDS 走线 → 支持 Aurora over LVDS 2.5 Gbps × 8 = 20 Gb/s
- 同 90 颗 MBI5264, 屏幕刷新仍上限 7.81 kHz（瓶颈在 driver）

**Phase 3 升级（换 driver）**：
- MBI5264 → Macroblock DaVinci 系列或 MBS7264（2026~2027 量产）
- 同 PCB 同位置，单颗带宽 3~5× 提升
- 可冲 503×30Hz 终极目标

# 验证流水线

**Phase 1 (2~4 周)**: 买 5 颗 MBI5264 + 1 块 16×16 试验板, 实测 30 MHz DDR 稳定性

**Phase 2 (4~6 周)**: 60×60 子板 (10 chip + 4 3019), 10 路 SDI 直驱 Zynq

**Phase 3 (8~12 周)**: 整板 160×180 + 90 chip + 8 层 PCB

# 文档路径
- MBI5264 datasheet: `D:\workspace\zynq_pov\docs\mbi\MBI5264_advance.pdf` (45p V0.01)
- ICND3019 datasheet: `D:\workspace\zynq_pov\docs\ICND3019_datasheet_CN_V2.0_20220106.pdf`
- 9 CPLD 升级方案备份在对话上下文（2026-05-12）
