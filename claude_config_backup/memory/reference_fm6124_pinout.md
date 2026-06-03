---
name: FM6124 datasheet 关键参数 + 准确引脚表 (2026-05-29)
description: 富满电子 FM6124 16-channel LED driver 完整引脚 + 电气特性, PCB 走线/Zynq 端代码参考必备
type: reference
originSessionId: 42b483be-17d4-4bd8-9194-41c6b8158af7
---
**datasheet 位置**: `D:\workspace\zynq_pov\docs\fm\FM6124.pdf` (10 页中文版, 富满电子官方)
- 备份来源: https://github.com/Galaxy-Man/FM6126-FM6124-LED-DMD/raw/master/FM6124.pdf
- 文件编号: S&CIC1501

## 引脚定义 (SSOP24)

| Pin | 名称 | 方向 | 功能 |
|---|---|---|---|
| 1 | GND | P | 地 |
| 2 | SDI | I | 串行数据输入 (移位寄存器) |
| 3 | **CLK** | I | 时钟 (手册叫 CLK = 我们说的 DCLK) |
| 4 | **LA** | I | 数据锁存 (= 标准 HUB75 的 LE/STROBE) |
| 5 | OUT0 | O | 恒流输出 |
| 6 | OUT1 | O | |
| 7 | OUT2 | O | |
| 8 | OUT3 | O | |
| 9 | OUT4 | O | |
| 10 | OUT5 | O | |
| 11 | OUT6 | O | |
| 12 | OUT7 | O | |
| 13 | OUT8 | O | |
| 14 | OUT9 | O | |
| 15 | OUT10 | O | |
| 16 | OUT11 | O | |
| 17 | OUT12 | O | |
| 18 | OUT13 | O | |
| 19 | OUT14 | O | |
| 20 | OUT15 | O | 恒流输出 |
| **21** | **OE** | **I** | **输出使能 + 下降沿 latch 数据** |
| 22 | SDO | O | 串行数据输出 (接下颗 SDI) |
| 23 | REXT | A | 外接电流调节电阻 |
| 24 | VDD | P | 3.3V / 5V 电源 |

**OUT0~15 是连续 16 个 pin (pin 5~20)**, 比 MBI5264 那种零散排布对 PCB 走线友好.

## 双缓存机制 (区别于 MBI5264 + ICND1069 的关键)

```
OE 高 → OUT 全 OFF (此时可自由 shift 新数据)
OE 下降沿 → shift register → output register (latch)
OE 低 → OUT 显示 latched 数据
```

**两阶段时序**:
1. OE 高时: SDI shift 进 shift register (随便几个 CLK 都行)
2. LE 高: 通常忽略，因为 OE 是主要的 latch 信号 (手册真值表: LE=H 时 OUT OFF)
3. OE 下降沿: 把 shift register 内容 latch 到 output buffer
4. OE 低: 显示

**BCM 用法**: PL 端用 OE 脉宽控制每 plane 显示时长 (132ns / 264ns / ... / 16.97µs)

## 真值表

| CLK | LE | SIN | SR 内容 | SOUT | OUT 状态 |
|---|---|---|---|---|---|
| ↑ | L | Dn | DN`···DN-7···DN-15 shift | DN-15 | (由 OE 控) |
| ↓ | L | Dn+1 | 无变化 | DN-14 | (由 OE 控) |
| ↑ | L | Dn+2 | DN+2···DN-5···DN-13 shift | DN-13 | (由 OE 控) |
| × | H | × | (shift 仍工作) | DN-13 | **全 OFF** |

注: LE=H 时 OUT 强制 OFF, 跟 HUB75 标准不太一样 (HUB75 标准 LE 是 latch). FM6124 这里 LE 更像 "blank 备用"; 实际项目里**主要用 OE 做 latch + blanking**, LE 可拉低不用.

## 关键参数

### 绝对最大额定值 (TA=25°C)
| 参数 | 符号 | 值 | 单位 |
|---|---|---|---|
| 电源电压 | VDD | 0~7.0 | V |
| 输出电流 | IO | 35 | mA |
| 输入电压 | VIN | -0.4 ~ VDD+0.4 | V |
| 输出耐受电压 | VOUT | **30** | V |
| **时钟频率** | **FCLK** | **30** | **MHz** |
| 接地端电流 | IGND | +600 | mA |
| 消耗功耗 | PD | 3 | W |
| 热阻抗 | RTH(j-a) | 39.15 | °C/W |
| 工作温度 | TOPR | -40 ~ +85 | °C |

### 直流特性 (典型值)
| 参数 | 条件 | 典型值 |
|---|---|---|
| 电源电压 VDD | - | 3.3~5V (max 6V) |
| ON 时输出电压 VO(ON) | - | 0.6~4 V |
| 高电平输入 VIH | - | 0.7×VDD |
| 低电平输入 VIL | - | 0.3×VDD |
| SDO 输出电流 | VDD=5V | ±1 mA |
| 恒流输出 IO | - | 0.5~35 mA |

### Multivox 项目设计参数

| 参数 | 值 |
|---|---|
| 实际 VDD | 5V (typical) |
| BCM 25% duty 时 IOUT 设定 | ~32-40 mA (Rext 调小 4×) |
| DCLK 目标 | 30 MHz (满速) |
| 8-bit BCM 一帧 DCLK 数 | 4096 (48-IO 方案) |
| 8-bit BCM 一帧时长 | 136 µs |
| fps | 7,350 |

## 跟其他 IC 引脚对比 (跟 MBI5264 / ICND1069 拔旧贴新不可行)

| Pin | FM6124 | MBI5264 | ICND1069 |
|---|---|---|---|
| 1 | GND | GND | GND |
| 2 | SDI | SDI | SDI |
| 3 | **CLK** | **DCLK** | DCLK |
| 4 | **LA** | **LE** | LE |
| 5-20 | OUT0-15 | OUT0-15 | OUT0-15 |
| 21 | **OE** ★ | **OUT?** (无 OE) | **ROW** ★ |
| 22 | SDO | SDO | SDO |
| 23 | REXT | R-EXT | R-EXT |
| 24 | VDD | **GCLK/ST** ★ | VDD |

★ = 关键差异 pin, 三家完全不同, 不能 hot-swap.

## 应用提示

- **R-EXT 计算**: VR-EXT = 0.6V (典型), IOUT ≈ VR-EXT / Rext × scaling, 具体见 datasheet 第 5-6 页公式
- **多片级联**: SDO → 下一颗 SDI, CLK/LE/OE 共享 (broadcast)
- **48-IO 方案**: 拆 daisy 时 SDI 各自接 PL IO, **SDO 不连**, CLK/LE/OE 仍 broadcast
- **VDD 3.3V vs 5V**: 都能跑, 但 IOUT 上限差不多; 实际 panel 多用 5V
