---
name: ICND1069 协议 reference (从编程指导 V1.2 抽取)
description: LE 长度编码指令 / 寄存器配置流程 / 显示时序 / 关键寄存器默认值. 完整 PDF 在 docs/ICND1069_编程指导_CN_2024_V1.2_深圳映己鸿鹄科技有限公司专用.pdf.
type: reference
originSessionId: 25cdb314-8481-406a-9724-5d3798a00293
---
**LE 长度编码指令** (LE 高电平期间 DCLK 上升沿个数):

| LE | 指令 | 用途 |
|---|---|---|
| 1 | DATA_LATCH | 锁存 16-bit 灰度数据 (MSB first D[15:0]) 到 SRAM |
| 3 | VSYNC | 帧同步 |
| 5 | WR_CFG | 写寄存器, 16 bit data = 高 8 bit 地址 + 低 8 bit 值 |
| 7 | RD_CFG | 读寄存器 |
| 11 | EN_OP | 使能所有 PWM 输出 |
| 12 | DIS_OP | 关闭所有 PWM 输出 (等 8 帧才能再 EN_OP) |
| 14 | PRE_ACT | 写使能 (WR_CFG 之前必发) |

**写寄存器 4 步流程**:
1. PRE_ACT (LE=14)
2. WR_CFG `[0x00]=0xAA, [0x01]=0xAA` — 开 password
3. WR_CFG 实际寄存器 (一个或多个)
4. WR_CFG `[0x00]=0x55, [0x01]=0x55` — 关 password

**显示时序**:
1. VSYNC (LE=3)
2. 等 16 DCLK
3. ROW = 12 DCLK 高 = 第 1 组第 1 行起点
4. 每行 16 ch × cascade chain length 个 DATA_LATCH, 顺序: chain 末尾起 OUT15→OUT0
5. ROW = 4 DCLK 高 = 后续行换行
6. 循环至全部 row 显示完, 下帧 VSYNC

**DCLK 限制**: 默认 12.5 MHz, 常规 4-16 MHz max
**GCLK 内置 PLL**: 7-96 MHz (R = LOOP_DIV / (PRE_DIV × POST_DIV))

**关键寄存器** (上电默认):

| 寄存器 | 地址 | R 默认 | G 默认 | B 默认 | 说明 |
|---|---|---|---|---|---|
| Reg02 | 0x02 | - | - | - | bit[5:0] = 扫描数-1 (32 扫=0x1F) |
| Reg03 | 0x03 | - | - | - | bit[6:0] = (刷新率/帧率)-1 |
| Reg04 | 0x04 | 0x02 | 0x02 | 0x02 | PLL_PRE_DIV |
| Reg05 | 0x05 | 0x04 | 0x04 | 0x04 | PLL_LOOP_DIV |
| Reg06 | 0x06 | 0x01 | 0x01 | 0x01 | PLL_POST_DIV |
| Reg07 | 0x07 | 0x20 | 0x20 | 0x20 | 每行 GCLK/4 (默认 128 GCLK/row) |
| Reg0D | 0x0D | 0x02 | 0x02 | 0x02 | 消隐时间 |
| Reg0E | 0x0E | 0x06 | 0x06 | 0x06 | 第一行偏暗补偿时间 |
| Reg1C | 0x1C | 0xC0 | 0xC0 | 0xC0 | 电流 GAIN. IGAIN = (bit[7]+1)*bit[6:0]/128 |
| Reg1D | 0x1D | 0xA6 | 0xA6 | 0xA6 | bit[7:6]=慢速开启, bit[3:2]=拐点电压 |
| Reg26 | 0x26 | 0xAA | 0xAA | 0xAA | (写使能 password 部分) |

**每帧总 grayscale 等级**: G = (reg0x03[6:0]+1) × reg0x07[7:0] × 4
- 默认: 1 × 32 × 4 = 128 级 (太低, 调高 reg03 + reg07)
- 16384 级需: e.g. reg03=0x7F (sub-frame 128), reg07=0x20 → 128×32×4 = 16384

**显示分子帧** (高刷新原理):
- 1 frame = N sub-frame (reg0x03+1)
- 每 sub-frame 所有 row 显示一段时间 (GCLK PWM 累加)
- 视觉积分 = 各 sub-frame 时间相加 = 完整 16-bit grayscale

**ROW 信号**:
- 高电平 12 DCLK = first group first line marker (每 (分组数*扫描行数) 个 ROW 出一次)
- 高电平 4 DCLK = 其他行换行
- 必须跟显示模组上行控制信号同步

**为方便控制卡, NDA 后厂商可索取 IcnGamma.dll source code** (gamma 表生成).

**实际配置每帧 DCLK 个数 N**:
N = A (第一行补偿 reg0x0E*2/R) + B (显示时间 reg0x07*4/R+1) + C (消影起始 reg0x0F*4/R) + D (消影 reg0x0D*2/R) + E (换行时间 min 2)
推荐 N > 33 (帧率自适应).

**完整 PDF**: `docs/ICND1069_编程指导_CN_2024_V1.2_深圳映己鸿鹄科技有限公司专用.pdf` (24 页)
