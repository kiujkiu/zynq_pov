# MBI5264 中文版数据手册

> **16 通道 PWM 恒流 LED 驱动 IC，用于 1:64 时分复用应用**
> Macroblock (聚积科技) Advance Information，V0.01，2020 年 2 月
> *本文档为 `MBI5264_advance.pdf` (英文 45 页) 翻译版，2026-05-29 由 Claude 翻译。*
> *官方仅发布英文版，本译本仅供工程参考。原始 PDF 在 `docs/mbi/MBI5264_advance.pdf`。*

---

## 主要特性 (Features)

- **电源电压** 3V ~ 5.5V
- **16 路恒流输出通道**
- **输出电流范围**：
  - 0.5 ~ 20 mA @ VDD = 5V
  - 0.5 ~ 10 mA @ VDD = 3.3V
- **极佳电流精度**：
  - 通道间误差：< ±1.5% (Typ.)
  - 芯片间误差：< ±1.5% (Typ.)
- **内置 16K-bit × 2 双口 SRAM**，支持 1~64 scan 时分复用
- **可选 16 / 15 / 14 / 13 bit PWM 灰度**，提升视觉刷新率
- **6-bit 电流增益**，12.5% ~ 100% 可调
- **DCLK 双边沿触发**
- **LED 失效隔离**（故障 LED 引起的串扰消除）
- **强制 LED 开路检测**
- 内置消影 (ghost elimination) 电路
- 内置 PWM 增强
- 高对比度干扰改善
- **GCLK 倍频技术**
- 支持 **double refresh** 模式
- **最大 DCLK 频率：15 MHz @ VDD = 5V**

## 产品描述 (Product Description)

MBI5264 是用于 LED 视频显示的恒流驱动芯片，内置 PWM 控制，灰度位深可选 13/14/15/16 bit。芯片内含 16-bit 移位寄存器，将串行输入数据转换成每个像素的灰度输出。16 路恒流端口为 LED 提供均匀稳定的灌电流（即使 LED 的 VF 偏差较大也能保证一致），输出电流由外接电阻 `Rext` 设定。

创新的内置 SRAM 架构支持最多 **1:64 时分复用**：用户只需把整帧数据一次性送进 LED 驱动 IC 的 SRAM，**不需要在切 scan line 时反复发送**。这极大节省了数据带宽，能在很低的数据时钟下实现高灰度。

配合 **scan-type S-PWM (Scrambled PWM)** 技术，MBI5264 把每个 scan line 的 "on" 时间打散到多个短 "on" 时段中，并依次驱动各 scan line。这等效于提升 scan 型 LED 显示器的视觉刷新率。**GCLK 倍频技术**额外再提供 2 倍刷新率。

MBI5264 按图像数据驱动 LED 到指定亮度。在 16-bit 色深下，S-PWM 技术可显著减少闪烁，提升画面真实度。

通过 **强制错误检测**，无需外加元件即可逐个检测 LED 开路。**Cross Elimination** 创新功能可消除失效 LED 引起的串扰。集成的消影电路和高对比度干扰改善则缓解 ghost 问题并提升画面对比度。

## 方框图 (Block Diagram)

```
                                  ┌─────────────────────┐
   SDI ────────────────────────▶  │                     │
   DCLK ───────────────────────▶  │   16-bit Shift Reg  │  ─── SDO
   LE ─────────────────────────▶  │   + Command Decoder │
                                  │                     │
                                  │   16K × 2 SRAM      │  支持 1:64
                                  │   ("ping-pong")     │  multiplex
                                  │                     │
                                  │   PWM Generator     │
   GCLK / ST ──────────────────▶  │   (13~16 bit)       │
                                  │                     │
                                  │   16 通道恒流 sink  │
                                  │                     │
                                  └──┬──┬──┬──...──┬────┘
                                  OUT0 1 2 ...    15
                                  (cathode sink)

   R-EXT ───── 外接 Rext，设定输出电流
   VDD ─────── 3.3V / 5V 电源
   GND ─────── 公共地
```

---

## 引脚配置 (Pin Configuration)

两种封装：
- **MBI5264GP** — SSOP24L (0.65mm pitch)
- **MBI5264GFN** — QFN24L (4×4mm, 0.5mm pitch)

### 引脚说明 (Terminal Description)

| 引脚名 | 功能描述 |
|---|---|
| **GND** | 控制逻辑 + 恒流 sink 共地 |
| **SDI** | 移位寄存器串行数据输入 |
| **DCLK** | 时钟输入：上升沿移位数据；当 LE 拉高时携带命令信息（按 DCLK 上升沿数编码命令） |
| **LE** | 数据锁存信号 + 配合 DCLK 编码命令 |
| **OUT0 ~ OUT15** | 16 路恒流输出（cathode sink，灌电流到 GND） |
| **GCLK / ST** | 外部 GCLK 模式：灰度时钟。灰度显示根据 GCLK 与输入数据的比较计数。<br>内部 GCLK 模式：Scan Toggle 端。完成当前 scan 后进入 deadtime，等外部 toggle 信号变化后再等 MT 个内部 GCLK，结束 deadtime |
| **SDO** | 串行数据输出，接下一颗芯片的 SDI（级联） |
| **R-EXT** | 外接电阻设定全部输出通道电流 |
| **VDD** | 3.3V / 5V 电源 |

---

## 输入输出等效电路 (Equivalent Circuits)

- **GCLK / DCLK / SDI**：CMOS 输入 + 内部 pull-down
- **LE**：CMOS 输入 + 内部 100 KΩ pull-down
- **SDO**：CMOS 推挽输出
- **OUT0 ~ OUT15**：开漏 NMOS 恒流 sink

---

## 极限参数 (Maximum Ratings)

| 参数 | 符号 | 范围 | 单位 |
|---|---|---|---|
| 电源电压 | VDD | 0 ~ 5.5 | V |
| 输入电压 (SDI/DCLK/GCLK/LE) | VIN | -0.4 ~ VDD+0.4 | V |
| 单通道输出电流 | IOUT | +22 | mA |
| OUT 端口耐压 | VDS | -0.5 ~ VDD+0.4 | V |
| GND 端口电流 | IGND | 360 | mA |
| 功率耗散（GP，4 层 PCB，Ta=25°C）| PD | TBD | W |
| 功率耗散（GFN，4 层 PCB，Ta=25°C） | PD | TBD | W |
| 热阻（GP，4 层 PCB） | Rth(j-a) | TBD | °C/W |
| 热阻（GFN，4 层 PCB） | Rth(j-a) | TBD | °C/W |
| 最大结温 | Tj,max | **150**（建议 <125°C 长期使用） | °C |
| 工作温度 | Topr | -40 ~ +85 | °C |
| 储存温度 | Tstg | -55 ~ +150 | °C |

> 注：PCB 仿真尺寸 76.2 mm × 114.3 mm，参考 JEDEC JESD51。实际热阻可能与仿真值有差异。

---

## 电气特性 (Electrical Characteristics)

### VDD = 5.0V, Ta = 25°C

| 特性 | 符号 | 条件 | Min | Typ | Max | 单位 |
|---|---|---|---|---|---|---|
| 电源电压 | VDD | — | 4.5 | 5.0 | 5.5 | V |
| OUT 端口耐压 | VDS | OUT0~OUT15 | — | — | VDD+0.4 | V |
| 输出电流 | IOUT | 参见测试电路 | 0.5 | — | 20 | mA |
| SDO 输出高电流 | IOH | SDO | — | — | -1.0 | mA |
| SDO 输出低电流 | IOL | SDO | — | — | 1.0 | mA |
| 输入高电平 | VIH | -40~85°C | 0.7×VDD | — | VDD | V |
| 输入低电平 | VIL | -40~85°C | GND | — | 0.3×VDD | V |
| 输出漏电流 | IOH | VDS=5.4V | — | — | 0.5 | μA |
| SDO 低输出电压 | VOL | IOL=+1mA | — | — | 0.4 | V |
| SDO 高输出电压 | VOH | IOH=-1mA | 4.6 | — | — | V |
| 通道间电流误差 | dIOUT1 | IOUT=0.5mA, VDS=1V, Rext=14.4kΩ | — | ±1.5 | ±2.5 | % |
| 芯片间电流误差 | dIOUT2 | 同上 | — | ±1.5 | ±3 | % |
| 输出电流 vs 输出电压调整率 | %/dVDS | VDS 1~3V | — | ±0.1 | ±0.3 | %/V |
| 输出电流 vs 电源电压调整率 | %/dVDD | VDD 4.5~5.5V | — | ±1.0 | ±2.0 | %/V |
| LE 内部下拉电阻 | RIN(down) | — | — | 100 | — | KΩ |
| 电源电流 (DCLK=GCLK=0Hz, OFF) | IDD(off)1 | Rext=Open | — | 2.91 | 2.96 | mA |
| | IDD(off)2 | Rext=14.4kΩ | — | 2.99 | 3.04 | mA |
| | IDD(off)3 | Rext=0.72kΩ | — | 4.52 | 4.57 | mA |
| 电源电流 (GCLK=20Hz, ON) | IDD(on)2 | Rext=14.4kΩ, OUT 全开 | — | 4.04 | 4.09 | mA |
| | IDD(on)3 | Rext=0.72kΩ, OUT 全开 | — | 5.6 | 5.65 | mA |

### VDD = 4.2V, Ta = 25°C

| 特性 | 符号 | 条件 | Min | Typ | Max | 单位 |
|---|---|---|---|---|---|---|
| 电源电压 | VDD | — | 3.8 | 4.2 | 4.6 | V |
| 输入高电平 | VIH | -40~85°C | 0.75×VDD | — | VDD | V |
| 输入低电平 | VIL | -40~85°C | GND | — | 0.25×VDD | V |
| 输出电流 | IOUT | — | 0.5 | — | 20 | mA |
| 通道间电流误差 | dIOUT | Rext=14.4kΩ | — | ±1.5 | ±2.5 | % |
| 芯片间电流误差 | dIOUT2 | Rext=14.4kΩ | — | ±1.5 | ±3 | % |
| 电源电流 OFF | IDD(off)1 | Rext=Open | — | 10.2 | 11.5 | mA |
| | IDD(off)2 | Rext=14.4kΩ | — | 12.2 | 13.5 | mA |
| | IDD(off)3 | Rext=0.72kΩ | — | 14.2 | 15.5 | mA |
| 电源电流 ON (GCLK=20MHz) | IDD(on)2 | Rext=14.4kΩ | — | 12.2 | 13.5 | mA |
| | IDD(on)3 | Rext=0.72kΩ | — | 14.2 | 15.5 | mA |

### VDD = 3.3V, Ta = 25°C

| 特性 | 符号 | 条件 | Min | Typ | Max | 单位 |
|---|---|---|---|---|---|---|
| 电源电压 | VDD | — | 3.0 | 3.3 | 3.6 | V |
| 输出电流 | IOUT | — | 0.5 | — | **10** | mA |
| 输入高电平 | VIH | -40~85°C | 0.75×VDD | — | VDD | V |
| 输入低电平 | VIL | -40~85°C | GND | — | 0.25×VDD | V |
| 通道间电流误差 | dIOUT | Rext=14.4kΩ | — | ±1.5 | ±2.5 | % |
| 芯片间电流误差 | dIOUT2 | Rext=14.4kΩ | — | ±1.5 | ±3 | % |
| 电源电流 OFF | IDD(off)1 | Rext=Open | — | 9.7 | 11 | mA |
| | IDD(off)2 | Rext=14.4kΩ | — | 11.7 | 13 | mA |
| | IDD(off)3 | Rext=0.72kΩ | — | 13.7 | 15 | mA |
| 电源电流 ON (GCLK=20MHz) | IDD(on)2 | Rext=14.4kΩ | — | 11.7 | 13 | mA |
| | IDD(on)3 | Rext=0.72kΩ | — | 13.7 | 15 | mA |

---

## 开关特性 (Switching Characteristics)

> 测试条件 (3 档电压通用)：VIH=VDD, VIL=GND, Rext=0.72kΩ, VDS=1V, RL=300Ω, CL=10pF, CSDO=10pF, VLED=4.0V

### VDD = 5.0V, Ta = 25°C

| 特性 | 符号 | Min | Typ | Max | 单位 |
|---|---|---|---|---|---|
| **Setup Time** | | | | | |
| SDI - DCLK↑ | tSU0 | 5 | — | — | ns |
| LE↑ - DCLK↑ | tSU1 | 8 | — | — | ns |
| LE↓ (vsync/swrst) - GCLK | tSU2 | 1200 | — | — | ns |
| LE↓ - DCLK↑ | tSU3 | 50 | — | — | ns |
| **Hold Time** | | | | | |
| DCLK↑ - SDI | tH0 | 6 | — | — | ns |
| DCLK↑ - LE | tH1 | 8 | — | — | ns |
| GCLK - LE↓ (vsync/swrst) | tH2 | 300 | — | — | ns |
| **传播延迟** | | | | | |
| DCLK - SDO | tPD0 | — | 22 | 25 | ns |
| GCLK - OUT2n | tPD1 | — | 35 | — | ns |
| LE - SDO | tPD2 | — | 30 | 40 | ns |
| **其他** | | | | | |
| LE 脉冲宽度 | tw(LE) | 15 | — | — | ns |
| 命令到命令间隔 | tcc | 50 | — | — | ns |
| **DCLK 最大频率** | FDCLK | — | — | **30** | MHz |
| GCLK 最大频率 (默认) | FGCLK | — | — | 33 | MHz |
| GCLK 最大频率 (GCLK 倍频开) | FGCLK | — | — | 16.6 | MHz |
| 最小 GCLK/DCLK 脉宽 | tW(CLK) | 12 | — | — | ns |
| GCLK 与 DCLK 频率比 | R(GCLK/DCLK) | 20 | — | — | % |
| 强制错误检测时间 | tERR-C | 700 | — | — | ns |
| 输出上升时间 | tOR | — | 15 | 25 | ns |
| 输出下降时间 | tOF | — | 15 | 25 | ns |
| Deadtime 正电平 | tdth | 300 | — | — | ns |
| Deadtime 负电平 | tdtl | 1200 | — | — | ns |

### VDD = 4.2V

主要差异：
- **DCLK 最大频率：15 MHz**
- GCLK 最大频率：20 MHz (倍频开) / 40 MHz (倍频关)
- LE↑ - DCLK↑ setup tSU1 = 8 ns
- 其余同 5V 表

### VDD = 3.3V

主要差异：
- **DCLK 最大频率：12.5 MHz**
- GCLK 最大频率：20 MHz (倍频开) / 40 MHz (倍频关)
- SDI - DCLK↑ setup tSU0 = 7 ns
- LE↑ - DCLK↑ setup tSU1 = 10 ns
- DCLK↑ - SDI hold tH0 = 8 ns
- DCLK↑ - LE hold tH1 = 10 ns

> 注：
> 1. 各通道输出波形一致性良好
> 2. "configuration read" 时序中，下一个 DCLK 上升沿应在 LE 下降沿后 tPD2 之后
> 3. 强制错误检测要预留 ≥ 最大检测时间
> 4. 启用 GCLK 倍频时，GCLK 周期必须为 50% 占空比

---

## 时序波形 (Timing Waveform)

### 控制时序基本结构

1. **数据 shift + LE 锁存**：SDI/LE 数据在 DCLK 上升沿采样；LE 脉冲表征命令
2. **vsync / data latch**：vsync 由 LE 高 2 个 DCLK 周期编码
3. **Read Configuration**：LE 下降沿后等 tSU3，再发 DCLK 读出 SDO
4. **Deadtime**：scan 结束后内部 GCLK 进入 deadtime（tdth + dummy GCLK + tdtl）

### 命令格式约定

- **不需 confirm 前缀的命令**：直接 LE 高 N 个 DCLK 上升沿即可（如 `vsync` = LE 高 2T）
- **需要 confirm 前缀的命令**：先发 `confirm_cmd` (LE 高 14T)，紧接着发实际命令（之间不能再有 LE 脉冲）
- 例：写 1 号配置寄存器 = `confirm_cmd (LE 高 14T)` → SDI shift 16-bit 数据 → `LE 高 4T` (Write 1st Cfg)

---

## 控制命令表 (Control Commands)

> 命令 = LE 高时 DCLK 上升沿数。LE 下降沿后触发对应动作。
> 带 (*) 的命令必须先发 `confirm_cmd` (LE 高 14T)。

### 基础命令

| 命令名 | LE | DCLK 上升沿数 | LE 下降后动作 |
|---|---|---|---|
| Stop Compulsory Error Detection | 高 | **1** | 停止强制错误检测 |
| Individual Latch | 高 | **1** | 把串行数据移入 buffer |
| Vertical Sync | 高 | **2** | 显示帧刷新 |
| Compulsory Error Detection (open) | 高 | **7** | 启动强制开路检测 |
| Software Reset | 高 | **10** | 复位所有数字部分（不含 cfg 寄存器） |
| Enable All Outputs (*) | 高 | **11** | 16 通道全开 |
| Disable All Outputs (*) | 高 | **12** | 16 通道全关 |
| Confirm Command | 高 | **14** | 必须在 "write config / enable all / disable all / test mode" 之前发 |

### 写配置寄存器 (Write Configuration)，均需先发 confirm_cmd

| 命令 | LE | DCLK 数 | 说明 |
|---|---|---|---|
| Write 1st Cfg | 高 | 4 | 数据送 1 号寄存器 |
| Write 2nd Cfg | 高 | 8 | → 2 号 |
| Write 3rd Cfg | 高 | 16 | → 3 号 |
| Write 4th Cfg | 高 | 18 | → 4 号 |
| Write 5th Cfg | 高 | 13 | → 5 号 |
| Write 6th Cfg | 高 | 15 | → 6 号 |
| Write 7th Cfg | 高 | 6 | → 7 号 |
| Write 8th Cfg | 高 | 23 | → 8 号 |
| Write 9th Cfg | 高 | 24 | → 9 号 |
| Write 10th Cfg | 高 | 25 | → 10 号 |
| Write 11th Cfg | 高 | 26 | → 11 号 |
| Write 12th Cfg | 高 | 27 | → 12 号 |
| Write 13th Cfg | 高 | 28 | → 13 号 |
| Write 14th Cfg | 高 | 29 | → 14 号 |
| Write 15th Cfg | 高 | 30 | → 15 号 |
| Write 16th Cfg | 高 | 31 | → 16 号 |

### 读配置寄存器 (Read Configuration)

| 命令 | LE | DCLK 数 | 说明 |
|---|---|---|---|
| Read 1st Cfg | 高 | 5 | 从 1 号读出到 SDO |
| Read 2nd Cfg | 高 | 9 | 从 2 号 |
| Read 3rd Cfg | 高 | 17 | 从 3 号 |
| Read 4th Cfg | 高 | 19 | |
| Read 5th Cfg | 高 | 21 | |
| Read 6th Cfg | 高 | 22 | |
| Read 7th Cfg | 高 | 33 | |
| Read 8th Cfg | 高 | 34 | |
| Read 9th Cfg | 高 | 35 | |
| Read 10th Cfg | 高 | 36 | |
| Read 11th Cfg | 高 | 37 | |
| Read 12th Cfg | 高 | 38 | |
| Read 13th Cfg | 高 | 39 | |
| Read 14th Cfg | 高 | 40 | |
| Read 15th Cfg | 高 | 41 | |
| Read 16th Cfg | 高 | 42 | |

### GCLK 修饰命令 + IC ID + 其他

| 命令 | LE | DCLK 数 | 说明 |
|---|---|---|---|
| IC Number Defined | 高 | 20 | 设定首颗 IC 编号 |
| Write GCLK modify 1st (*) | 高 | 43 | → GCLK 修饰 1 号寄存器 |
| Write GCLK modify 2nd (*) | 高 | 44 | → 2 号 |
| Write GCLK modify 3rd (*) | 高 | 45 | → 3 号 |
| Write GCLK modify 4th (*) | 高 | 46 | → 4 号 |
| Write GCLK modify 5th (*) | 高 | 47 | → 5 号 |
| Read IC Info for GCLK modify | 高 | 48 | 仅数字测试模式。返回格式：<br>`bit[8:4]`=IC number, `bit[3]`=GCLK modify +/-, `bit[2:0]`=GCLK modify 值 |
| Wakeup | 高 | 62 | 强制从 sleep 唤醒 |
| HW Reset | 高 | 63 | 强制硬件复位 |

---

## 配置寄存器定义 (Configuration Registers)

> 共 16 个 16-bit 寄存器，部分位 reserved。下面按编号列出。

### 1 号配置寄存器 (默认值 `0x8CBF`)

| Bit | 属性 | 定义 | 默认 | 功能 |
|---|---|---|---|---|
| 15 | Reserved | — | 0~1 | 保留 |
| 14 | R/W | 低灰度去除条纹 | 0 | 0: Disable, 1: Enable |
| 13 | R/W | 串扰消除 (Cross Effect Removal) | 0 | 0: 不关 LED 开路通道, 1: Enable |
| 12~8 | R/W | Scan line 数定义 1 | 00011 (4 行) | 若 CFG2[0]=0：CFG1[12:8] = 0~31 (映射 1~32 lines)<br>若 CFG2[0]=1：{CFG7[2], CFG1[12:8]} = 0~63 (映射 1~64 lines) |
| 7 | R/W | S-PWM 模式 (灰度位深) | 0 | {CFG2[14], CFG1[7]}:<br>`0x00`: 16-bit, 65536 GCLK 切 64 段 × 1024 GCLK<br>`0x01`: 15-bit, 32768 GCLK 切 32 段 × 1024 GCLK<br>`0x10`: 14-bit, 16384 GCLK 切 32 段 × 512 GCLK<br>`0x11`: 13-bit, 8192 GCLK 切 16 段 × 512 GCLK<br>注：14/15/13 bit 模式仍发 16-bit 数据，低位补 0 |
| 6 | Reserved | — | 0 | 保留 |
| 5~0 | R/W | 电流增益控制 | 111111 (100%) | 000000: 12.5% ~ 111111: 100% |

### 2 号配置寄存器 (默认值 `0x8201`)

| Bit | 属性 | 定义 | 默认 | 功能 |
|---|---|---|---|---|
| 15 | Reserved | — | 0~1 | 保留 |
| 14 | R/W | S-PWM 模式 | 0 | 同 CFG1[7] |
| 13~11 | R/W | 低灰度高级色彩补偿 2 | 000 | 000: 通道开启不偏移<br>001~111: 通道开启时序偏移 1T~7T GCLK<br>注：backward 模式不支持 |
| 10 | R/W | Double Refresh | 1 | 0: ×1, 1: ×2 |
| 9 | Reserved | — | 0~1 | 保留 |
| 8~5 | Reserved | — | 0000 | 保留 |
| 4~1 | Reserved | — | 0000 | 保留 |
| 0 | Reserved | — | 0~1 | 保留 |

### 3 号配置寄存器 (默认值 `0xFFFF`)

| Bit | 属性 | 定义 | 默认 | 功能 |
|---|---|---|---|---|
| 15 | Reserved | — | 1 | 保留 |
| 14~10 | R/W | 暗块补偿 1 (Dark Block Comp.) | 11111 | 0,0001~1,1111: 低~高<br>00000 = 关闭 |
| 9~5 | R/W | 暗块补偿 2 | 11111 | 同上 |
| 4~0 | R/W | 暗块补偿 3 | 11111 | 同上 |

### 4 号配置寄存器 (默认值 `0xFFFF`)

| Bit | 属性 | 定义 | 默认 | 功能 |
|---|---|---|---|---|
| 15 | Reserved | — | 0 / 1 | 保留 |
| 14~10 | R/W | 第一行暗 scan line 亮度补偿 | 11111 | 0,0001~1,1111: 低~高，00000 = 关 |
| 9~5 | R/W | 低灰度高级色彩补偿 1 | 11111 | 同上 |
| 4~0 | R/W | 低灰度高级色彩补偿 3 | 11111 | 同上 |

### 5 号配置寄存器 (默认值 `0x721A`)

| Bit | 属性 | 定义 | 默认 | 功能 |
|---|---|---|---|---|
| 15~8 | Reserved | — | 01110010 | 保留 |
| 7~5 | R/W | Cross effect removal 等级 | 000 | 000~111: 低~高 |
| 4~0 | R/W | 低消影等级 (Lower De-ghosting) | 11010 | 0,0001~1,1111: 低~高，00000 = 关 |

### 6 号配置寄存器 (默认值 `0x4000`)

| Bit | 属性 | 定义 | 默认 | 功能 |
|---|---|---|---|---|
| 15~0 | Reserved | — | `0x4000` | 全部保留 |

### 7 号配置寄存器 (默认值 `0x8004`)

| Bit | 属性 | 定义 | 默认 | 功能 |
|---|---|---|---|---|
| 15~7 | Reserved | — | 100000000 | 保留 |
| 6 | R/W | 数字电路手动复位 | 0 | 0/1 |
| 5~3 | Reserved | — | 0 | 保留 |
| 2 | R/W | Scan line 数 (高位) | 1 | 与 CFG1[12:8] 组合 → 1~64 lines |
| 1~0 | Reserved | — | 00 | 保留 |

### 8 号配置寄存器 (默认值 `0x0000`)

| Bit | 属性 | 定义 | 默认 | 功能 |
|---|---|---|---|---|
| 15~13 | Reserved | — | 000 | 保留 |
| 12 | R/W | 渐变补偿 (Gradient Comp.) | 0 | 0: Disable, 1: Enable |
| 11~5 | Reserved | — | 0 | 保留 |
| 4~0 | R/W | GCLK Change 控制 | 00000 | 00000: 不变 / 00001~11111: 1T~31T GCLK 变化量 |

### 9 号配置寄存器 (默认值 `0x0121`)

| Bit | 属性 | 定义 | 默认 | 功能 |
|---|---|---|---|---|
| 15~0 | R/W | Reserved | `0x0121` | 保留 |

### 10 号配置寄存器 (默认值 `0x0000`)

| Bit | 属性 | 定义 | 默认 | 功能 |
|---|---|---|---|---|
| 15~0 | Reserved | — | 0 | 保留 |

### 11 号配置寄存器 (默认值 `0x04D7`)

| Bit | 属性 | 定义 | 默认 | 功能 |
|---|---|---|---|---|
| 15~10 | Reserved | — | 000001 | 保留 |
| 9~0 | R/W | Deadtime GCLK 周期 | 215 | Deadtime 宽度 = IC 内部 GCLK 周期 × K<br>0/1/2: K=3, 3: K=4, 4: K=5, …, 1023: K=1024<br>**Deadtime 必须 > 1.5 μs** |

### 12 号配置寄存器 (默认值 `0x0085`)

| Bit | 属性 | 定义 | 默认 | 功能 |
|---|---|---|---|---|
| 15~10 | R/W | 低灰度色彩补偿 | 000000 | 000000: disable / 000001~111111: 1×~63× delta extend |
| 9~0 | R/W | Dummy GCLK 周期 | 133 | Dummy 宽度 = IC 内部 GCLK 周期 × N<br>0/1/2: N=3, 3: N=4, …, 1023: N=1024 |

### 13 号配置寄存器 (默认值 `0xB21B`) — **PLL 配置**

| Bit | 属性 | 定义 | 默认 | 功能 |
|---|---|---|---|---|
| 15~14 | Reserved | — | 10 | 保留 |
| 13~7 | R/W | PLL variable M | 1100100 (100) | 2~127 |
| 6~2 | R/W | PLL variable N | 00110 (6) | 2~31 |
| 1~0 | R/W | PLL variable DIV | 11 (/1) | 00:/8, 01:/4, 10:/2, 11:/1 |

### 14 号配置寄存器 (默认值 `0x0049`)

| Bit | 属性 | 定义 | 默认 | 功能 |
|---|---|---|---|---|
| 15~0 | R/W | Reserved | `0x0049` | 保留 |

### 15 / 16 号配置寄存器 (默认值 `0x0000`)

| Bit | 属性 | 定义 | 默认 | 功能 |
|---|---|---|---|---|
| 15~0 | Reserved | — | 0 | 保留 |

---

## Scan line 数 (Number of Scan Lines)

MBI5264 支持 1~64 scan lines。
通过 `CFG1[12:8]` 和 `CFG7[2]` 设定。
默认值 `00011` = 4 scan lines。

## 灰度模式与 Scan-type S-PWM

MBI5264 通过 `CFG1[7]` 和 `CFG2[14]` 选择 16/15/14/13-bit 灰度。
默认 0 = 16-bit。
**注**：14-bit 灰度模式时，用户仍要发 16-bit 数据，LSB 补 2 个 0。例：`{14'h1234, 2'h0}`。

S-PWM 智能技术把总 PWM 周期切成 MSB + LSB 灰度周期，MSB 可拆成多个刷新周期，等效高 bit 分辨率。

## GCLK 倍频 (GCLK Multiplier)

通过 `CFG1[6]` 控制。默认 0 = 关闭。

**关闭** (`CFG1[6]=0`)：
- 每 scan line 1024 GCLK
- 1024 × 64 × 64 = **4,194,304 GCLK** (一次 16-bit PWM 计数)
- 64 scrambles 显示序列

**开启** (`CFG1[6]=1`)：
- 每 scan line 512 GCLK
- 512 × 64 × 64 = **2,097,152 GCLK**
- 等效 2 倍刷新率

---

## 工作原理 (Operation Principal)

### Scan 型应用结构

```
                    SDI ──▶ MBI5264 ──── SDO ──▶ 下一颗 MBI5264 ──▶ ...
                    DCLK ──▶  cascade   ──▶ DCLK
                    GCLK ──▶            ──▶ GCLK
                    LE   ──▶            ──▶ LE

OUT0 ─┐      OUT0 ─┐
 OUT1 ─┤      OUT1 ─┤   ...
 ...  ─┤      ...  ─┤
OUT15 ─┘     OUT15 ─┘

    Switch (行选 / scan multiplexer)
       │
       ▼
   VLED (anode) ──┬── scan line 0
                  ├── scan line 1
                  ...
                  └── scan line 63

LED:  anode → VLED (via row switch)
      cathode → MBI5264 OUTn (恒流 sink)
```

64 scan line 时分复用：16 channel 输出会在不同时刻分别为不同 scan line 输出 PWM 结果，所以必须有一个外部 **Switch (行选开关)** 多路选通各 scan line。切换顺序+方法+命令用法见 application note。

---

## 输出电流设定 (Setting Output Current)

输出电流 IOUT 由外接电阻 Rext 设定。
公式：

$$
V_{R\text{-EXT}} = 0.3\text{V} \\
I_{OUT} = \frac{V_{R\text{-EXT}}}{R_{ext}} \times 24 \times G
$$

其中：
- `Rext` = R-EXT 引脚外接电阻
- `G` = 数字电流增益，由 1 号配置寄存器 bit 5~0 设定，默认 G=1
- 当 `Rext=360Ω, G=1` 时，IOUT ≈ 20 mA

## 电流增益调整 (Current Gain Adjustment)

CFG1 bit 5~0 (`DA5~DA0`) 设定电流增益 G，6-bit 64 级。

公式：
$$
G = 0.125 + \frac{D}{63} \times 0.875
$$

D 即 6-bit 数值（0~63）：

$$
D = DA5 \times 2^5 + DA4 \times 2^4 + DA3 \times 2^3 + DA2 \times 2^2 + DA1 \times 2^1 + DA0 \times 2^0
$$

**例**：
- 想要 G=0.5
- D = (0.5 - 0.125) / 0.875 × 63 = 27
- 二进制 27 = `0×32 + 1×16 + 1×8 + 0×4 + 1×2 + 1×1` = `0b011011`
- 所以 CFG1[5:0] = `6'b011011`

---

## 封装功耗 (Package Power Dissipation)

最大允许封装功耗：
$$
P_D(max) = \frac{T_j - T_a}{R_{th(j-a)}}
$$

16 通道同时开启时实际功耗：
$$
P_D(act) = (I_{DD} \times V_{DD}) + (I_{OUT} \times \text{Duty} \times V_{DS} \times 16)
$$

由 PD(act) ≤ PD(max) 可推最大允许输出电流（与 duty 相关）：
$$
I_{OUT} = \frac{[(T_j - T_a) / R_{th(j-a)}] - (I_{DD} \times V_{DD})}{V_{DS} \times \text{Duty} \times 16}, \quad T_j = 150°C
$$

**封装热阻 + 最大功耗**：

| 型号 | Rth(j-a) (°C/W) | PD (W) |
|---|---|---|
| MBI5264GP | 90 | 1.38 |
| MBI5264GFN | 37 | 3.37 |

> 环境温度 Ta 升高时 PD(max) 下降。

---

## LED 电源电压 (VLED)

MBI5264 设计的 VDS 工作范围 0.4V ~ 1.0V (对应 IOUT 1~20mA)，受封装功耗限制。

当 VLED=5V 且 VDS=VLED-VF 时可能 PD(act)>PD(max)，此时建议：
- 降低 VLED
- 或外加压降元件 VDROP

加 VDROP 后：`VDS = (VLED - VF) - VDROP`。可用电阻或 Zener 二极管实现。

## 开关噪声抑制

LED 驱动常用于开关模式应用，PCB 寄生电感会产生开关噪声。参考 Macroblock "Application Note for 8-bit and 16-bit LED Drivers - Overshoot"。

---

## 焊接工艺 (Pb-free & Green Package)

100% 纯锡 (Sn)，要求 245°C ~ 260°C 焊接温度。符合 JEDEC J-STD-020C。

| 封装厚度 | 体积 < 350 mm³ | 350~2000 mm³ | ≥ 2000 mm³ |
|---|---|---|---|
| < 1.6 mm | 260+0°C | 260+0°C | 260+0°C |
| 1.6 ~ 2.5 mm | 260+0°C | 250+0°C | 245+0°C |
| ≥ 2.5 mm | 250+0°C | 245+0°C | 245+0°C |

**回流焊曲线 (推荐)**：
- 升温斜率 平均 0.4°C/s (低温段), 3.3°C/s (中段), 0.7°C/s (高段)
- 217°C 上方时间 ≤ 100s
- 240°C 上方时间 ≤ 30s
- 峰值温度 245~260°C，< 10s
- 降温斜率 ≤ 6°C/s

---

## 封装外形 (Package Outline)

详见原始 PDF 第 42~43 页 (尺寸单位：mm)：
- MBI5264GP — SSOP24L-150-0.64
- MBI5264GFN — QFN24L-4×4-0.5

## 订货信息 (Product Ordering Information)

| 订货号 | 封装 | 重量 (g) |
|---|---|---|
| MBI5264GP-T | SSOP24L-150-0.64 | 0.11 |
| MBI5264GFN-T | QFN24L-4×4-0.5 | 0.0379 |

**版本历史**：

| 数据手册版本 | 器件版本码 |
|---|---|
| V0.01 | T |

---

## 免责声明 (Disclaimer)

Macroblock 保留对产品和文档进行修改、更正、改进或终止任何产品或服务的权利。用户在订货前请向销售代表确认最新产品信息。

Macroblock 产品**未设计**用于支持生命维持设备或军事应用，未经 Macroblock 总经理书面批准不得用于体内手术植入或可能造成人员死伤的应用场合。

产品相关技术受专利保护。文档中所有文字、图像、徽标和信息均为 Macroblock 知识产权，未授权复制、提取、使用或披露视为侵权。

---

## 译者注 (Translator Notes)

本文档基于英文版 `MBI5264_advance.pdf` (V0.01, 2020-02) 翻译，用于本项目工程参考。

**关键提示** (跟项目相关)：

1. **共阳 LED 矩阵**：MBI5264 是 cathode sink，LED 阴极接 OUTn，阳极通过行管 PMOS source 接 VLED。如果硬件用了 NMOS 行管会导致 LED 不亮（项目 `reference_mbi_polarity.md` 已记）

2. **跟 ICND1069 协议对比**：
   - 两者都是 LE 长度编码命令
   - MBI5264 命令空间更大 (LE=1~63)，ICND1069 主要用 LE=1,3,5,11,12,14
   - MBI5264 寄存器更多 (16 + 5 GCLK modify)，ICND1069 ~30 个
   - MBI5264 需 `confirm_cmd (LE=14)` 前缀的命令是 ICND1069 没有的安全机制
   - MBI5264 内置 SRAM 可一次性收整帧，ICND1069 必须每 scan 重发
   - MBI5264 GCLK 可选 internal/external (ST 模式)，ICND1069 只有 ROW 信号

3. **POV3D 项目用 MBI5264 的关键参数**：
   - 5V 供电时 DCLK 最大 30 MHz，跟项目 `project_pov3d_led_chip_decision.md` 里"DCLK 30MHz DDR 超频必需"对应
   - 1:64 scan + 内置 SRAM 可大幅减少帧间数据传输
   - 13-16 bit 灰度对 POV 高刷新很关键

4. **行管 PMOS 选型** (per `reference_mbi_polarity.md`)：
   - DD311 / FP9933 / AP3402 等
   - 不能用 ICND3019 (NMOS sink, 跟 MBI5264 同极性, LED 必不亮)
