---
name: Zynq 7000 UG933 PCB 设计硬规则 + 鹿小班 6 层参考板
description: XC7Z020 CLG484 decoupling 数量 + DDR3 length match + impedance + ZQ + 6/8 层 stackup, 后续 PCB 布线必查
type: reference
originSessionId: 37aa49b2-ddd9-4c38-a89f-2bf1258edd1c
---
UG933 完整 PDF 在 `/mnt/d/BaiduNetdiskDownload/鹿小班zynq/02_芯片手册/Artix-7/ug933-Zynq-7000-PCB.pdf` (80 页), 副本 `/mnt/d/claude_workspace/pov3d/ug933.pdf`。

## XC7Z020 CLG484 Decoupling Cap 要求 (Table 3-1, PL 侧)

| Rail | 330µF | 100µF | 47µF | 4.7µF | 0.47µF |
|---|---|---|---|---|---|
| VCCINT | 1 | 0 | 0 | 2 | 4 |
| VCCBRAM (含 680µF=1) | 0 | 1 | 0 | 1 | 1 |
| VCCAUX | — | — | 1 | 1 | 2 |
| VCCO **per Bank** (×4 banks) | — | — | 1 | 2 | 4 |
| Bank 0 (config) | — | — | 1 | — | — |

**合计** (XC7Z020 CLG484, 4 个 PL bank: 13/33/34/35):
- 330µF: 1 (VCCINT)
- 680µF: 1 (VCCBRAM)
- 100µF: 1 (VCCBRAM)
- 47µF: 1 (VCCAUX) + 4 (VCCO×4) + 1 (Bank0) = **6 颗**
- 4.7µF: 2 (VCCINT) + 1 (VCCBRAM) + 1 (VCCAUX) + 8 (VCCO×4) = **12 颗**
- 0.47µF (≈ 100nF): 4 (VCCINT) + 1 (VCCBRAM) + 2 (VCCAUX) + 16 (VCCO×4) = **23 颗**

**当前 zynq_main 只有 10 颗 cap (5×100nF + 5×10uF)**, 不够。PCB layout 时要补足。

PS 侧 cap (Table 3-2) 我没全提取, 待用. 查 UG933 page 14-15。

## DDR3/3L 布线硬规则 (Ch 5)

### 最大 trace 长度
- Data Group (DQ/DM/DQS): **5 inch / 127mm**
- Address/Command/Control: **5 inch / 127mm**

### Delay 匹配 (走线 length match)
- **DQ / DM ↔ DQS_P/N** (within byte lane): **±10 ps**
- **Address / Control ↔ CK_P/N**: **±10 ps**
- 推算: 10 ps ≈ FR4 ε_r=4.3 时 1.4mm 长度差 (使用 KiCad length-match 工具按 1.4mm 控)

### 阻抗
- **Single-ended**: 40Ω ±10%
- **Differential** (DQS_P/N, CK_P/N): 80Ω ±10%

### ZQ 校准电阻
- **Rzq = 240Ω** 到 GND (DDR3 颗粒 ZQ pin)

### Termination
- Rterm (信号末端): 40Ω 到 VTT
- Rclk (CK 末端): 80Ω 到 VTT
- Rdown (RESET#): 4.7kΩ 下拉到 GND

### CK trace ≥ DQS trace per byte lane
write leveling 自动 adjust, 但只能 longer 不能 shorter

### VTT, VREF
- VTT = VDDQ/2 (DDR3 1.5V 系统 → 0.75V) 用 TPS51200 termination LDO
- VREF = VTT (PS_DDR_VREF0, PS_DDR_VREF1 同一电压源 — 直接接 VTT 即可)

### TDQS_P/N 引脚
**Zynq 不支持**, DDR3 颗粒上 TDQS_P/N 必须**悬空** (floating)。我们 ddr3.kicad_sch 已经 noconnect。

## Stackup 参考 — 现成 Zynq core 板 6 层

文件: `/mnt/d/工程项目/硬件/pov/zynq/ZYNQ7000_10_20_core_v1.0_20221204_LE/ZYNQ7000_10_20_core/ZYNQ7000_10_20_core.kicad_pcb`

```
L1 F.Cu      signal      0.035mm 铜
   core      FR4 ε=4.5    0.274mm
L2 In1.Cu    power
   prepreg   FR4          0.274mm
L3 In2.Cu    signal
   core                   0.274mm
L4 In3.Cu    signal
   prepreg                0.274mm
L5 In4.Cu    power
   core                   0.274mm
L6 B.Cu      signal       0.035mm
总 1.6mm
```
**问题**: 6 层 stackup 没有完整 GND plane, 不理想。

我们 8 层 (JLC8L) 更好 — 有 2 个 GND plane (L2 + L7), GTX/HDMI/DDR 信号有完整回流路径。

## DRC + Trace 参数 (从参考板提取)
- **trace width**: 0.254mm (10 mil) 标准, **DDR3 0.127mm (5 mil)** 走 inner layer
- **via 标准**: size 0.45mm, drill 0.2mm (我们 .kicad_pro 已设)
- **clearance**: 0.1143mm (4.5 mil)
- **zone min thickness**: 0.1143mm
- **thermal relief**: gap 0.1524mm, bridge 0.1524mm

## BGA 484 escape (XC7Z020 CLG484, 0.8mm pitch)
- 外圈 2 row → top + bottom layer 直接出 (dog-bone)
- 内层用 via-in-pad (0.2mm drill, 0.45mm pad, filled+plated)
- 每 ball 1 via + 1 short trace 拉到 escape lane
- 9 unit 摆位: 中央 22×22mm 区域留出 ~30×30mm 给 BGA + 周围 escape

## 推荐布线顺序
1. **Power planes** (L4, L5 split) — 先定 +1V0/+1V8/+1V5/+3V3/+5V 在哪
2. **BGA escape** (L1+L8 dog-bone, L3+L6 内层 fan-out 跳通)
3. **DDR3 ADDR/CMD** (fly-by, BANK 502, ±10ps 等长)
4. **DDR3 DQ groups** (32-bit 分 4 byte lane, 各自 ±10ps with DQS)
5. **HDMI TMDS 4 diff pairs** (BANK 34, 100Ω diff, intra-pair skew <5mil)
6. **RGMII** (BANK 35 via PS MIO 16-27, 50Ω SE, length match within ±50mil)
7. **USB diff** (2 对, 90Ω diff)
8. **Slow signals** (UART, SD0, QSPI, SD1/eMMC, JTAG, I2C, MDIO)
9. **PL IO header** (4× 2x40 排针, 普通 trace)
10. **铺铜** (GND on L2/L7, power split on L4/L5)
11. **DRC + manufacturer-specific (嘉立创 JLC8L)** 检查

## 嘉立创 JLC8L (8 层) 标准
- 板厚 1.6mm, ENIG (沉金) finish
- min trace/clearance: 5 mil (0.127mm) — 5/5 标准
- min via: 0.4mm pad / 0.2mm drill
- min ann ring: 0.05mm
- min copper-edge clearance: 0.3mm
- 板 size ≤ 200×200mm 标准价

## 后续画板顺序备忘
1. 用户 GUI: schematic → annotate → Update PCB
2. 自动摆位 (agent Phase 1 — running, 把 footprint 摆到 floorplan 位置)
3. GND zone 铺 L2/L7
4. Power trace 主干 (5V 输入 → 5× buck VIN, buck VOUT → consumer)
5. **DDR3 fly-by** (用户 KiCad GUI, 内置 length-match 工具)
6. **HDMI/USB 差分对** (KiCad 内置 diff pair router)
7. **BGA escape** (手动, 多次试错)
8. DRC + gerber 出板

实战层面: 一个完整布线 (含 length match) 需要熟练手工 ~1 周, 不熟练 ~2-3 周。**先做粗布线** + DRC 通过, 再迭代精细。
