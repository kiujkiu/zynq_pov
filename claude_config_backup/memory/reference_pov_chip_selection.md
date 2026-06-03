---
name: LED 驱动 IC 选型对比 (POV 高 fps vs 静态屏, FM6124 / MBI5x / ICN2x / DDR / S-PWM)
description: POV 7K+ fps + 静态屏 380fps 16-bit, BCM vs PWM vs S-PWM 时间预算清算, DDR + 高 DCLK 选型
type: reference
originSessionId: 42b483be-17d4-4bd8-9194-41c6b8158af7
---
**结论先讲**: POV 高 fps (7K+) 用 **FM6124 + 外部 BCM**, **不要用 MBI5264**.

## 带宽硬约束

任何 LED 驱动 IC 都受 DCLK 上限约束:

| IC | 极性 | DCLK 上限 @5V | OE | GCLK | 内置 SRAM | 适合 |
|---|---|---|---|---|---|---|
| **FM6124** | NMOS sink | 30 MHz | **有** | 无 | 1 帧 dual buffer | POV / 通用 HUB75 |
| **MBI5264** | NMOS sink | 30 MHz | **无** | **有** (33 MHz) | 16K×2 SRAM | 大屏 60Hz 显示 |
| **ICN2053** | NMOS sink | 65 MHz | 有 | 有 (option) | 1 帧 | 高速 HUB75 |
| **ICN2065** | NMOS sink | 100 MHz | 有 | 有 | 1 帧 | 旗舰高速 |

**128×64 panel × 8-bit RGB × 7K fps = 1.38 Gbps 数据需求**

| chain 数 × DCLK | 总带宽 | 满足 1.38 Gbps? |
|---|---|---|
| 6 × 30 MHz (标准 HUB75E + FM6124/MBI5264) | 180 Mbps | ✗ |
| 6 × 65 MHz (标准 + ICN2053) | 390 Mbps | ✗ |
| 6 × 100 MHz (标准 + ICN2065) | 600 Mbps | ✗ |
| **48 × 30 MHz (拆 daisy + FM6124)** | **1.44 Gbps** | **✓** |
| 24 × 65 MHz (拆半 daisy + ICN2053) | 1.56 Gbps | ✓ |

→ **唯一可行: 增加并行 chain 数, 不是换更快 IC**

## MBI5264 在 POV 反而劣势的根本原因

| 因素 | 解释 |
|---|---|
| **每像素数据量大** | 16-bit / pixel (填 SRAM 字段), 是 FM6124 1-bit BCM plane 的 16× |
| **内置 PWM 周期慢** | 16-bit PWM = 65,536 GCLK × 32 scan / 33MHz = **64 ms 显示周期 = 15 Hz max** |
| **无 OE pin** | 显示开关无法外部控制, 不能做 BCM |
| **SRAM 收益不存在** | POV 每 slice 都是新图, SRAM "一次写多次显示" 优势用不上, 反而成累赘 |

MBI5264 各模式最大显示刷新率 (1:32 scan):
- 16-bit: 15 Hz
- 15-bit: 31 Hz
- 14-bit: 63 Hz
- 13-bit: 125 Hz (最快, 仍比 7K 慢 56×)

## POV 高 fps 正确思路

**1-bit per plane (FM6124 BCM) 而不是 16-bit per pixel (MBI5264 PWM)**:

```
传统大屏 (60Hz 显示):
   1 帧 16-bit per pixel → IC 内部 PWM 跑 60K Hz → 眼睛看到 60Hz × 16-bit 色
   ↑ MBI5264 思路, IC 替你做 PWM, 软件简单

POV 高 fps (7K Hz 显示):
   7K 帧 × 1-bit per plane × 8 plane (BCM) → 软件控 OE 时长 1:2:4:..:128
   ↑ FM6124 思路, 软件做 BCM, 灵活性高
```

**等价性证明**: 都得到 8-bit per channel 输出, 但:
- MBI5264: 60 Hz × 16-bit = 一段 "慢且精细" 的显示, 适合静态画面
- FM6124+BCM: 7K Hz × 8-bit = 一段 "快但分阶段" 的显示, 适合 POV 旋转

## 引脚兼容性 (PCB 拔旧贴新可行性)

**FM6124 ↔ MBI5264 不直接兼容**:
- FM6124 第 1 脚 (典型) = OE
- MBI5264 第 24 脚 = GCLK/ST
- 物理位置 + 功能完全不同 → 必须飞线 + 协议重写
- 不要尝试 hot-swap

**FM6124 ↔ ICN2053 大致兼容**:
- 都有 OE pin, 协议相似
- 部分引脚布局可能小差异, 看具体型号

## 推荐选型 (按场景)

| 场景 | 推荐 |
|---|---|
| 标准 60 Hz LED 屏 (广告/舞台) | MBI5264 (16-bit 真灰度, IC 内 PWM 省事) |
| HUB75E 大屏 120-240 Hz 显示 | ICN2053 (高 DCLK 提刷新率) |
| POV 旋转, fps ≥ 1000 | **FM6124 + 拆 daisy + BCM** |
| POV 高速 (7K+ fps) | **FM6124 + 48-IO + 软件 BCM** |
| 单色 / 1-bit POV | 任何 IC (省钱) |

## 关键算式速查

### 48-IO + FM6124 + 8-bit BCM (128×64 1:32 scan)
```
per plane upload = 32 row × 16 DCLK / DCLK_freq
@ 30MHz: 17 µs/plane, 8 plane = 136 µs/frame → 7,350 fps × 8-bit ✓
duty cycle: BCM 总 display = 1+2+...+128 = 255×T units = 33.7µs / 136µs = 25%
亮度补偿: Rext 改小 4×, IOUT 从 8-10 mA → 32-40 mA (FM6124 spec 上限 35mA)
```

### Bit 深度 vs fps trade-off (固定 48-IO + 30MHz)
| 色深 | 每帧 µs | fps |
|---|---|---|
| 4-bit (16 级) | 68 | 14,700 |
| 5-bit (32 级) | 85 | 11,765 |
| 6-bit (64 级) | 102 | 9,800 |
| 7-bit (128 级) | 119 | 8,400 |
| **8-bit (256 级)** | **136** | **7,350** |
| 9-bit (512 级) | 153 | 6,540 |
| 10-bit (1024 级) | 170 | 5,880 |

## 静态屏 vs POV-3D 时间预算清算 (2026-06-02 补)

PWM 内置芯片有两个时间成本: **shift** (16-bit gray 推进 SR) 跟 **GCLK** (内部 PWM 周期), 它们可以并行 (shift 下一行同时上一行跑 GCLK). 瓶颈 = max(总 shift, 总 GCLK).

### 128×64 panel @ 1/32 scan 各方案对比

| 方案 | DCLK / GCLK | Shift 1 row | GCLK 1 frame | Frame time | fps | 色深 |
|---|---|---|---|---|---|---|
| FM6124 6-bit BCM (current, 75M aclk DCLK_DIV=4) | 18.75M | 6×6.83µs=41µs | — | 2.17ms | **460** | 6-bit |
| FM6124 8-bit BCM | 18.75M | 8×6.83µs=55µs | — | 3.49ms | **287** | 8-bit |
| MBI5152 PWM SDR | 25M / 25M | 2048b/25M=82µs | 65536/25M=2.62ms | 2.62ms | **381** | 16-bit |
| MBI5153 PWM DDR | 25M eff 50M / 25M | 41µs | 2.62ms | 2.62ms (GCLK 卡脖) | **381** | 16-bit |
| MBI5252/53 S-PWM DDR | 25M eff 50M / 25M | 41µs | 16 sub-fields × 164µs | 2.62ms | **381 物理 / 6000 视觉** | 16-bit |
| ICN2065 PWM DDR @ 50M GCLK | 25M eff 50M / 50M | 41µs | 65536/50M=1.31ms | 1.31ms | **762** | 16-bit |

### 关键洞察

**静态显示 (HDMI/dashboard)**: MBI5152/5252 等 PWM 完胜 BCM. 16-bit 色深 (65536 灰阶 vs BCM 6-bit 64 灰阶), 帧率只降 18% 肉眼看不出.

**POV-3D**: 反过来 BCM 完胜 PWM. POV 需要 7K+ slice/sec, MBI5152 物理帧率才 380, 差 20×. S-PWM "视觉 refresh 6000 fps" 跟 POV 时间维度积分**无关**(POV 视角下 sub-field 跟物理 slice 是同一回事), 不能算高速.

**之前评估说 S-PWM 慢, 在 POV 上下文是对的**: sub-field 切分增加 shift 次数 N×, 总数据量翻 N 倍, 但物理 frame rate 跟传统 PWM 几乎一样—只是抗闪烁好.

### BCM + 高 DCLK + DDR 数据输入的芯片?

**好消息**: 主流 DDR + 高 DCLK 芯片都是 PWM 内置的, 不直接给 BCM 用. 但有几条路:

1. **MBI5153 / MBI5252 hack 当 dumb shift reg**: 写 0x0000 或 0xFFFF 当 1-bit BCM. 缺点: 每个 plane shift 仍要 16-bit 数据格式 (2048b/row), 浪费 16× 带宽
2. **ICND2153** (Chipone): DDR + binary mode 据传支持, 待 datasheet 确认
3. **ICND2055/2065 (with mode pin)**: 部分型号有 PWM/binary 切换, 选 binary 模式 = BCM-friendly + DDR
4. **FM6126 / FM6126A** (FM6124 sibling): 仍 SDR, DCLK 可能更高 (~50 MHz 传闻, datasheet 待确认)
5. **DP3265 / SUM2030**: DDR 高刷, mode 切换状态待查

**实测可行性最高的两个**:
- **ICN2053** (现 memory 已列): SDR DCLK 65 MHz, BCM-friendly, 比 FM6124 快 2× (单 chain 带宽 65 vs 30 Mbps)
- **ICN2065**: SDR DCLK 100 MHz, BCM-friendly. 单 chain 100Mbps. 比 FM6124 快 3.3×

DDR + BCM 真同时存在的芯片我**没确认见过**主流型号. 候选 ICND2153, 但需要拿到 datasheet 看 binary mode 是否带 DDR.

### POV-3D 升级路径建议 (2026-06-02 更新)

1. **短期**: 当前 MBI5264 + ICND3019 行管方案保留, 改 PMOS 行管 (见 reference_mbi_polarity.md), 6-bit BCM 跑 1000+ fps
2. **中期高速**: 上 **ICN2065** (100 MHz DCLK SDR) + 拆 daisy → 12 chain × 100M = 1.2 Gbps. 8-bit BCM @ 5000 fps 可行
3. **激进**: ICN2065 + 24 chain (双面 cascade) + 8-bit BCM = 2.4 Gbps → **10K+ fps**
4. **DDR 候选**: 等 ICND2153 datasheet 确认 binary mode + DDR, 如果支持就用; 否则 ICN2065 SDR 已经够 POV-3D 用

## 相关本地资料

- `D:\workspace\zynq_pov\docs\mbi\MBI5264_advance_CN.md` — MBI5264 中文版 datasheet (684 行, 完整)
- `D:\workspace\zynq_pov\docs\mbi\MBI5264_advance.pdf` — 英文原版 PDF (45 页)
- `D:\claude_workspace\pov3d\multivox\src\driver\vortex.c` — RPi 现行 HUB75E driver 实现
- `reference_mbi_polarity.md` — MBI 系列都是 cathode sink, 行管必须 PMOS
