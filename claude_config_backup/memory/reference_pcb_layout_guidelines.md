---
name: PCB layout 半熟项硬规则 (power plane / decoupling / thermal via / via stitching)
description: 我半熟的 4 项, 2026-06-03 网上查的具体数字, 后续 layout 必查; FR4 ε_r=4.3, 6 层 PWR-GND-GND sandwich
type: reference
created_at: 2026-06-03 12:30 CST
updated_at: 2026-06-03 12:30 CST
originSessionId: 37aa49b2-ddd9-4c38-a89f-2bf1258edd1c
---
半熟 layout 4 大项的具体规则, 实战 POV3D Zynq 7020 dev v1 PCB 用。

## 1. 电源平面 split (L4 PWR plane)

### 黄金准则
**高速信号绝不跨平面 split** — 这是高速 PCB stackup 单条最重要规则。我们 6 层 L4 是 PWR, 上下 L2 + L5 全 GND, sandwich 是最优结构。

### Split 缩进
分割岛的边缘**缩进 ≥ 10× dielectric thickness**:
- core 0.274mm → 缩 ≥ 2.74mm (我们 stackup)
- 4 mil (0.1mm) prepreg → 缩 ≥ 40 mil (1mm)

### 必须跨 split 时 (避免就避免)
- 旁边加 **stitching cap 0.1µF** (距 split <10mm)
- 或用 **ferrite bead 10-50Ω @ VHF** 连接分割段
- KiCad GUI 里用 *Route differential pair* 时手动检查 ratsnest 不跨 split

### POV3D 板实战
- L4 PWR plane 主鏡 **+5V** (整板 +5V 入口分到 5 buck VIN)
- +5V 分割岛留给 HDMI MBR0520 输出的 +5V_HDMI (隔离 inrush)
- +3V3 / +1V8 / +1V5 / +1V0 走 trace 不上 plane (buck VOUT 距离不远)

### 不要把 PWR plane 当信号回流路径
信号必须邻 GND plane 回流, 走 PWR plane 回流会跨 dielectric → 极高 Z 回路, EMI 直接爆。

## 2. BGA decoupling cap 放置 (Zynq 7020 CLG484)

### 距离规则
- **0201 高频 cap**: 紧贴 BGA escape via, via 中心距 power ball **≤1-2 mm**
- **0402/0603 bulk cap**: 板**对面 (BOT layer)** BGA 周边 (TOP 没空间时)
- **大 bulk cap (10-47µF)**: BGA 外圈 5mm 内
- **共享 via**: 一对 GND-PWR via 最多接 2 ball, 别多

### 高频 cap 距 IC pin 公式
距离 < (λ / 40) @ cap 的 self-resonant frequency:
- 0.1µF, SRF ~100 MHz → 距 < **9.5 mm** (0.375 in)
- 0.01µF, SRF ~500 MHz → 距 < **1.9 mm**
- 1nF, SRF ~1 GHz → 距 < **0.95 mm** ← BGA escape 用这种

### Via 对 spacing → ESL 决定项
- 一对 via (一个连 PWR, 一个连 GND) **间距 ≤ 10 mil (0.25mm)**
- via-in-pad (直接打在 cap pad 上) 比走 trace 再打 via **省 1-3 nH**
- 大 BGA (484+) 必须 via-in-pad, 用 0.2mm drill + filled+plated

### Cap 选型 (POV3D UG933)
70 颗 cap 全部 X7R/X5R MLCC:
- 高频 0.47µF (= 100nF×4) → 0201 紧贴 BGA via
- 中频 4.7µF → 0402, 1-2mm 距
- bulk 47µF / 100µF → 0805, 板 BOT 5mm 距
- 超 bulk 330µF / 680µF (VCCINT/VCCBRAM) → POSCAP / OS-CON, BGA 外 10mm

## 3. Thermal via for PowerPAD/QFN EP

### 关键规则 (TI SLMA002 实验数据)
- **drill 0.33mm (13 mil) 或更小**, 让 1oz copper plating 自然封 via barrel — 防 reflow 时 solder wick 从 EP 流走
- drill 太大 (>0.4mm) plating 封不住 → 必须用 **solder mask tenting**
- via 不能 open 到 BOT 不封, 否则 reflow solder 漏光

### 推荐阵列
- 小 EP (3×3 mm): **3×3 grid = 9 via**, pitch 1.2mm
- 中 EP (5×5 mm): **5×5 grid = 25 via**, pitch 1.2mm
- 大 EP (QFN-64 EP 4.35×4.35): **4×4 grid = 16 via**, pitch 1.2mm
- via 阵列**留 0.5-1mm 边缘**不打 via, 防焊点 voids

### 热阻减小
- SOIC-8 不带 EP: θJA ≈ 100 °C/W
- SOIC-8 PowerPAD + thermal via: θJA ≈ **30-40 °C/W** (减半-减 2/3)
- QFN-64 EP + 16 thermal via: θJA ≈ **20-30 °C/W**

### POV3D 板实战清单
| IC | 封装 | EP 尺寸 | thermal via |
|---|---|---|---|
| TPS563210**DDFR** (5×) | TSOT-23-8 PowerPAD | ~1.6×2.1 mm | 3×3=**9 via** 0.3mm pitch 0.7mm |
| TPS51200 VTT | WSON-8 | ~1.6×2.4 | 2×3=6 via |
| FT2232HQ | QFN-64 | 4.35×4.35 | **4×4=16 via** pitch 1.2mm |
| RTL8211EG | QFN-48 | ~5×5 | 5×5=25 via pitch 1.0mm |

## 4. Via stitching / GND fence

### 间距规则
**vis 间距 ≤ λ_substrate / 20** (FR4 ε_r=4.3, λ_sub ≈ λ_free / 2.07)

频率对照表 (FR4):
| 频率 | λ_free | λ_sub | **λ/20 间距** | 应用 |
|---|---|---|---|---|
| 100 MHz | 3 m | 1.45 m | **75 mm** | 慢速, 不强求 |
| 250 MHz (HDMI TMDS) | 1.2 m | 0.58 m | **30 mm** | 推荐 |
| 500 MHz (DDR3 含 harmonic) | 0.6 m | 0.29 m | **15 mm** | 必须 |
| 1 GHz | 0.3 m | 0.145 m | **7.5 mm** | 密 stitching |
| 3 GHz+ | 0.1 m | 0.048 m | **2.5 mm** | RF 才需要 |

### Via 直径
**0.2-0.4mm** drill, 越小 ESL 越低。我们 0.4mm 默认 OK, GND stitching 用 0.3mm 更佳。

### 何时不用
- rise time > 20 ns 的慢速信号 (UART/I2C/SPI <50MHz) 不需要 stitching
- 内层 stripline 已被 GND 包夹, 边沿不要

### 距 trace 限制
**距高速 trace 至少 4× (trace-to-GND-plane 距离)** 防干扰耦合。
- L3 sig 离 L2 GND 0.274mm → stitching via 距 trace ≥ 1.1mm

### POV3D 板实战
- **HDMI TMDS 4 对 diff pair** 旁边密 stitching, pitch 30mm 沿 trace 走
- **DDR3 byte lane** 旁 stitching pitch 15mm
- **板边沿全圈 GND stitching** pitch 5mm (EMI shield, low-cost)
- **BGA 外圈一圈 GND via** 隔 1mm 一颗 (return path 锁定)

## 5. 综合工具链

### KiCad 计算器
- 受控阻抗 trace 宽度: **PCB Calculator → Transmission Line** (用嘉立创 stackup 实际 0.274mm core)
- thermal via 电流: **Sierra Circuits Via Current Calculator** (网页)
- length match propagation: **6.3 ps/mm @ FR4 ε_r=4.3** (DDR3 等长 ±10ps = ±1.4mm)

### 实战流程
1. KiCad GUI → DRC 设置 net class clearance (DDR3 5mil, HSPD diff 4mil)
2. 写 stitching via 脚本 (Python KiCad API or s-expr) 板边沿 / BGA 外圈一键铺
3. 手拉 diff pair 用 KiCad **Route Differential Pair** 工具
4. Length match 用 KiCad **Tuning Pattern** 工具 (serpentine 自动加)
5. DRC clean → Gerber 出板

## 6. 引用 (这次研究来源)

- TI SLMA002 PowerPAD Technical Brief (drill 0.33mm 实验)
- AllPCB 6 layer stackup guide (PWR-GND-GND sandwich)
- Sierra Circuits decoupling cap guide (via spacing ≤10 mil)
- ProtoExpress RF PCB via design (λ/20 频率表)
- Altium power plane return path (信号不跨 PWR plane)
- Wikipedia Via Fence (W-band 76μm via 0.15mm pitch 极端例)

## 7. 我还是不熟的部分 (留给用户 KiCad GUI)

- DDR3 fly-by topology + serpentine length tuning (KiCad GUI 交互)
- BGA 484 ball 手工 escape (无自动, 1-2 天工作量)
- diff pair push-and-shove (KiCad GUI)
- SI 仿真 (我们没 Cadence Allegro / HyperLynx)

这些必须 user 在 KiCad GUI 里做, 我能提供 net class 设置 + checklist + 验证脚本。
