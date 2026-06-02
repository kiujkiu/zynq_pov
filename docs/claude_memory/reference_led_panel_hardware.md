---
name: LED panel 物理硬件 + 驱动芯片 reference
description: 160×180 RGB POV LED panel: 24× ICND3019 行驱动 + 108× ICND1069 列驱动 + 8× 74HC245. 电源 rail VCC=3.8V / VCC_R=2.8V (datasheet 确认).
type: reference
originSessionId: 25cdb314-8481-406a-9724-5d3798a00293
---
**Panel 硬件清单 (2026-05-09 user 提供)**:
- 分辨率: **160 × 180 像素 RGB**
- 行驱动 IC: **ICND3019 × 24** cascade (16 ch × 24 = 384 行信号; panel 用 180 行, 余 204 备用/不连)
  - 16 通道 NMOS, 1.5A/ch, 130mΩ Rds(on)
  - 接口: SDI/DCLK/RCLK/SDO + 16 OUT
  - 1 DCLK 推 1 行扫描, 上升沿换行
  - RCLK 8-23 个 = 寄存器配置 (默认 13 个 = 普通模式 + 2.5V 消隐)
  - DCLK 高电平 = 消影时间 (≥ 500 ns)
- 列驱动 IC: **ICND1069 × 108** = 4 chain × 27 cascade
  - 16 路 PWM 恒流输出, 1~18mA × 16 @ VDD=3.8V
  - 内置 96 MHz GCLK PLL (不需外部 GCLK)
  - REXT 外接电阻调电流: Iout = 12/Rext × Gain
  - 8-bit 电流增益 50%~200% (Gain 寄存器)
  - DCLK 25 MHz max, twCLK ≥ 40 ns
  - LE **长度编码指令** (不同 LE 脉宽 = 不同指令: 数据写 / 锁存 / 寄存器配置 / 等)
  - ROW 信号 0→1 触发换行, twROW ≥ 160 ns
  - 16-bit PWM 灰度数据/通道
  - LED 开路检测, 防上鬼影
- 缓冲: **74HC245 × 8** (双向 8-bit 缓冲, 64 信号 level shift FPGA 3.3V → panel 5V)
- FPC 连接器跟 FPGA 控制板对接 (具体 pinout 待 panel 厂商提供 / 实测 reverse engineer)

**电源 rail (datasheet 实证, 2026-05-13)**:
| Rail | 电压 | 接谁 | 来源 |
|---|---|---|---|
| **VCC** | **3.8 V** | ICND1069 (G/B 列) VDD + LED G/B 阳极 + ICND3019 VDD | ICND1069 datasheet 列出 VDD=3.8V → 1~18mA × 16 工作点; ICND3019 也提供 3.8V 实测 |
| **VCC_R** | **2.8 V** | ICND1069 (R 列) VDD + LED R 阳极 | ICND1069 datasheet 列出 VDD=2.8V → 1~15mA × 16 工作点; R Vf~2V, 省压降 |
| VCC_3.3V | 3.3 V | SPI flash + 74HC245 信号侧 | LDO (APL5320) 从 VCC 降 |

- ICND1069 VDD 工作范围 2.6~5V, 绝对最大 6V, fMAX=25MHz
- ICND3019 VDD 工作范围 3.0~5.5V (典型 5.0V), 绝对最大 6V, NMOS Ron=130mΩ@5V/140mΩ@3.8V, max 1.5A/ch
- 电流路径: `VCC/VCC_R → ICND1069 OUTx → LED 阳极 → LED 阴极 → ICND3019 OUTy → GND` (共阴扫描)
- 注意 `docs/C2-P0.9375-ICND2065-RT5960-IC-SCH.pdf` 是 **另一款** P0.9375 小间距模组原理图 (ICND2065+RT5960), 不是当前硬件; 但 VCC/VCC_R 双 rail 架构相同, 可作 reference

**关键观察**:
- 1728 列信号 ÷ 480 (160 × 3 RGB) = **3.6 倍冗余**, panel 不是 standard row-scan
- 推测: panel 内部 4 quadrant (各 80×90 RGB), 每 quadrant 1 cascade chain (27 IC × 16 = 432 ch ≈ 80×3 RGB × 18 row group)
- 或者 panel 内置 frame buffer + sub-frame PWM, FPGA 只送 frame data, panel 自己 PWM 灰阶

**POV 时序硬约束**:
- 720 angle slice × 30 Hz = **21600 slice/sec → 1 slice = 46 μs**
- 单 chain 6912 bit (27 chip × 16 ch × 16 bit) @ 25 MHz = 276 μs/chain ❌ 超 6×
- 4 chain 并行: 仍 276 μs/帧 (并行不缩短单 chain)
- → 16-bit PWM 不可行, 必须降到 8-bit (138 μs) / 6-bit (104 μs) / 4-bit (69 μs) 或更激进

**Datasheet 路径**:
- `docs/ICND1039_datasheet_CN_2023_V1.0.pdf` (老款行驱动, Rds=140mΩ, 板未用)
- `docs/ICND1069_datasheet_CN_2023_V1.1.pdf` (列驱动, 关键)
- `docs/ICND3019_datasheet_CN_V2.0_20220106.pdf` (行驱动, 板上版本, Rds=130mΩ)

**Bring-up plan (2026-05-09)**:
1. (A) ARM bit-bang baseline driver `led_panel.h/.c`: 测试图案 + 慢速验证物理通信
2. (B) PL Verilog driver IP `hls_proj/led_panel_drv/`: 高速 POV 时序
3. user 拿 panel 后: 万用表测 FPC pinout + 示波器抓配套控制器信号 reverse engineer 协议
4. baseline pattern 跑通 → PL HW IP 移植 → BD 集成 → 真验证

**待 user 后续填**:
- FPC 连接器 pinout (FPGA bank 33 / bank 35 PL 引脚 → panel signal mapping)
- panel scan ratio 实测 (1/180? 1/16? 1/8? other?)
- REXT 电流值实际值 (3 kΩ → 4mA / 1 kΩ → 12mA / etc.)
