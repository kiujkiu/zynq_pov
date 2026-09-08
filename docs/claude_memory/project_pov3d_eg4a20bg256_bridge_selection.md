---
name: project_pov3d_eg4a20bg256_bridge_selection
description: 定向"努力让 EG4 可以"后的实测结论: EG4 只能 700M 不能 800M(两条独立证据); A20BG256 干净対只有 86 不是 90(4 対被 JTAG/配置占), 8-bit@800M 差 1 対; bank8 确认可 2.5V; 配置时钟必须 12.5MHz 不是 30
metadata:
  type: project
---

# EG4A20BG256 桥片选型: 实测与逐脚清点 (2026-09-04)

用户定向: **EG4 便宜很多, 努力让它可以**; 封装优先 **256 脚**。
⇒ 目标 = EG4A20BG256I + 8-bit + 800M(或 700M), 一颗管一面 24 颗 2260。

## 🔴 一、EG4 跑不了 800M —— 两条独立证据, 都是自测的

### 证据 1: 加 PLL 抖动后 fabric setup 违例
【DS300 表 3-2-2】PLL 输出周期抖动 **160 ps p-p** (fOUT>100MHz), cycle-to-cycle 200 ps。
之前那个 "+0.102 ns / 2.1% 余量" 的 SDC **没有 set_clock_uncertainty**。补上后 (uplink_rx v2, EG4S20CG324):

| pclk | 抖动 | SWNS | HWNS | 判定 |
|---|---|---|---|---|
| 200 (800M) | 无 | +0.102 | +0.030 | 旧基线 |
| 200 | 0.08 半幅 | +0.065 | +0.003 | 勉强 |
| **200** | **0.16 全幅** | **-0.056** | 0.000 | 🔴 **setup 违例** (STNS -0.418) |
| 175 (700M) | 0.08 | +0.159 | +0.003 | ✅ |
| **175** | **0.16** | **+0.128** | -0.180 | ✅ (hold 见下) |

⚠ 175+0.16 的 hold -0.180 是**方法学过保守**: 周期抖动在 hold 检查里同沿发同沿收大部分抵消,
业界 hold 只加 skew。且 hold 是插缓冲能修的, 不是频率上限。

### 证据 2: IO 输入通路本身只剩 40 ps
给 13 路数据加 `set_input_delay -max 0 -min 0` 后, 报告出现 `sclk→sclk` 分组:
**Fmax 413.223 MHz / Min Period 2.420 ns / 26 端点 0 违例**
```
半周期 1.250 ns − PAD 延迟 1.370 ns + 时钟插入补偿 0.160 = slack +0.040 ns
```
⇒ **800M 只剩 40 ps** 给板级 skew + 发送端抖动 + 対间偏斜, 而且这还是 input_delay=0 的理想假设。

| 线速率 | slack | 相对 |
|---|---|---|
| 800M | 40 ps | 1× |
| **700M** | **219 ps** | **5.5×** |
| 600M | 457 ps | 11.4× |

⇒ **DS300 敢写 400 MHz, 那是器件极限不是可用工作点。EG4 的安全工作点 = 700 Mbps。**
报告在 scratchpad `eg4jitter/`, 脚本 `uplink_rx/build_jitter.sh`。

## 🔴 二、A20BG256 的干净対是 86 不是 90

名义 196 IO / 90 対 (39 真 + 51 仿真) 对, 但 **4 対被配置/JTAG 占死**:

| 被占対 | 占用者 |
|---|---|
| bank1 L8 | TCK / TDI |
| bank1 L9 | TMS / PROGRAMN |
| bank1 L11 | TDO / CSN |
| bank6 R5 | MSEL2 / MSEL1 |

⇒ **干净 86 対 (真 35 + 仿真 51) + 干净单端 11**(16 根名义里 CCLK/DIN/INITN/DONE 占 4、晶振 E1 占 1)。

| | 需要 | 干净可用 | |
|---|---|---|---|
| 差分対 | 87 (13 RX + 1 RXclk + 72 TX + 1 TXclk) | **86** | 🔴 差 1 |
| 单端 | 14 | **11** | 🔴 差 3 |

🔴 **之前"余 3 対"的账是错的** —— 余的那 3 対正好就是 JTAG/PROGRAMN/CSN, 把配置脚当空闲算了。

### bank 分布 (逐脚清点, 与 DS300 196/(39+51) 精确吻合)
真: bank1 `IO_L*` 8 / bank2 `IO_L*` 9 / bank5 `IO_R*` 13 / bank6 `IO_R*` 9 = 39
仿真: bank3 `IO_BE*` 12 / bank4 `IO_BE*` 14 / bank7 `IO_TE*` 17 / bank8 `IO_TE*` 8 = 51

### 回收手段与其可信度
- **JTAG 四脚设 User I/O ⇒ +2 対 (L8/L11)** —— UG303 表 2-1 暗示"软件 JtagPin 设置",
  但 🔴 **TD V6.2 里查不到 EG4 可用的 JtagPin 开关**, 只有 `persist_bit`(管 SPI 组 5 球)。
  `set_device_param` 命令确实存在(错误码 PRG-9029/9030 印证, 参数名含 `tdi_tms_tck_tdo`),
  但 SWUG105 一条没有, 且三档表旁的脚名是 DR1/PH1 命名不是 EG4 ⇒ **无文档依据, 待实测/问原厂**
- INITN/DONE 配置后作输出 ⇒ +2 单端 (DS300 L3251 "可以作为输出管脚使用")
- ❌ **MSEL 対 (R5_6) 拆单端不可行** —— 那対要挂下拉电阻
- ⚠ **C1(MOSI)/D2(SPICSN)/F16(CSON) 三个"干净单端"默认不成立**, 受 SpiPin 控制、
  `persist_bit` 默认 1, **必须位流里显式设 0**, 否则 11 根打回 8 根

## ✅ 三、bank8 可以 2.5V (曾以为会掉到 78 対)

DS300 引脚说明写 `ADC_VDDA` 是 "3.3V 模拟电源输入", 表 3-1-4 注 3 要求它与 VCCIO8(ADC_VDDD) 同电压,
且 EG4A20**NG88** 那张表里 VCCIO7/8 写的是 "**= 3.3V**"(等号) —— 一度怀疑 bank8 被锁 3.3V,
那样 8 対 TE 仿真対不能出 LVDS25E, 干净対 86→78, 差 9 対。
**供应商答复: 不使用 ADC 时 ADC_VDDA 与 VCCIO8 可接 2.5V, 3.3V 只是推荐非强制。**
四条约束我们全满足(同电压 ✅ / VREF ≤ VDDA ✅ / 非 MSPI ✅)。
⇒ 原理图定死: `ADC_VDDA(A1)=2.5V`、`ADC_VSSA(D7)接地`、`ADC_VREF(E2)≤2.5V`。
⚠ 该答复带 [1][2] 角标疑似知识库生成, **建议要 FAE 一句书面确认**。

## 🔴 四、配置链路: 三条会改硬件

1. **MSEL 下拉 4.7 kΩ 拉不下去** —— 内部弱上拉 IPU 最大 250 µA (DS300 表 3-1-11),
   4.7k×250µA = **1.175 V > VIL max 0.7 V** (表 3-1-13) ⇒ 上电误进 SP 模式。上限 2.8k, **改 1 kΩ**。
2. **配置时钟定 12.5 MHz 不是 30** —— `T_clk` min 33 ns 而 `T_dsu` min **16.5 ns**,
   50% 占空比下半周期 16.67 ns 只余 **+0.17 ns**; 25 MHz 余 3.5 ns, 转子排线保证不了。
   12.5 MHz 余 23.5 ns ⇒ **每次上电加载 394~490 ms**。
   ⚠ 别抄 TN301 参考设计的 462 kHz GPIO 模拟 = **10.87 秒**, 必须用 DR1 的 PL 硬件移位器。
3. **2260 的 RSTN 必须加 10 kΩ 下拉** —— 重配时桥片 IO 有 ~400 ms 三态段, 但
   **D[7:2] 六个球例外、恒弱上拉**, 共模 2.5V 落在 2260 的 VIC 1.1~1.3V 窗外。重配完要重跑 I2C 初始化。

**文档陷阱**: **DONE 拉高后 CCLK 还要跑 ≥6 µs 且 ≥10 周期**(DS300 L3552) ——
**TN301/TN303 都没写**, 照它写 DR1 加载代码必漏。建议统一补 256 拍。
时序以 **DS300 表 2-8-3** 为准(`T_ch/T_cl` 15.5 ns; TN301 v1.8 还写 16.5, 已过时)。
码流: 只有"EAGLE 系列 4.8M~6Mbit"(DS300 L3185), **无 A20 专属数字**; `.rbf` = `.bin` 逐字节位反转。
`CSN(J3)`: 不接 DR1, **1 kΩ 下拉到 GND, 绝不上拉**; 注意 J3 与 J4(TDO) 同対而外部网络相反, 极易贴反。

## 五、时钟架构 (TN305 + DS300 §2.3)

- ✅ **真差分対必须与 BUFIO 同 bank** (DS300 §2.3.2 + 图 2-3-7)。14 対必跨 2 bank ⇒ **要 2 个 BUFIO**。
  左侧配 PLL0/1, 右侧配 PLL2/3。
- ⚠ **IOL 内 pclk↔sclk 相位: 结构已答数字没答**。iDDRx2 里 PCLK 两个沿都在采 SCLK 上升沿域的寄存器
  ⇒ 要求是"PCLK 落在两个 SCLK 上升沿之间", 最优在下降沿。但**图 2-6-16 画 180°、图 2-6-9 画 90°,
  两张自相矛盾** ⇒ 只要在窗内即可。**tsu/th 一个数都没有**(DS300 §3.2 没有 IOL 寄存器时序表,
  仿真库也没 `$setuphold`) ⇒ 纸面算不出余量。
- 🎯 **新推论**: 方案 F 的 pclk 插入延迟 1.5~1.9 ns, 在 **332 MHz 档正好落在下降沿附近(179°~227°)**
  —— 厂家把分频器做成 0° 对齐再走 GCLK, 可能就是按 166 MHz 这个 IOL 上限档设计的; 400 MHz 档偏出去了。
- 🎯 **备选**: 方案 F 的 pclk 由 BUFIO 分频器派生, **PLL 调不到它**。要用 `CLKCx_FPHASE/CPHASE`
  静态移相(步长 1/8 VCO 周期 = 104~156 ps), pclk 必须**直接由 PLL 出**(方案 A/K)。
- bank1 因 JTAG 与 DR1 配置口被逼 **3.3V**, 但对真対无害 —— LVDS33 与 LVDS25 同 400MHz、**同 VOCM 窗**。

## 六、仍然只能问供应商的 (原 15 条 → 4 条)

| # | 问题 | 级别 |
|---|---|---|
| 1 | `set_device_param` 完整参数表 —— **JTAG 四脚能否设 User I/O**(回收 L8/L11 补差的 1 対) | 🔴 P0 |
| 2 | **VOCM 量产分布**(典型值/±3σ/能否微调) —— 规格 0.6~1.4V vs 2260 VIC 1.1~1.3V 两端都超 | 🔴 P0 |
| 3 | IOL 内 pclk↔sclk 允许相位窗口 / IOCLK 与 GCLK 插入延迟差 | P1 |
| 4 | A20BG256 生命周期 | P1 |

另需索取 **EG4A20BG256 的 IBIS 模型**(验证板 SI 仿真必须)。

### 自查掉的 11 条 (别再问)
gearing>4:1(❌ `eagle_macro.v` 只到 x2, 只有 EF5 有 x4) · fabric 200MHz 能否量产(❌ 见上) ·
IDDRx2 窗口(自测 40ps/219ps) · 上电时序(**无顺序要求**, UG303 §1.4 注 3) ·
配置脚 post-config 状态(UG303 表 2-1) · 配置期 IO 状态(HSWAPEN=CTRL[31] 默认 1 ⇒ High-Z) ·
speed grade(只有温度等级 C/I, DS303 §5) · 真/仿真対 bank 分布(逐脚数出) ·
BUFIO 与真対同 bank(DS300 §2.3.2) · IDELAY(32 级 0.525~3.85ns **每级 107ps**, TN309 §3.1) ·
3R 推荐值(UG303 表 3-1 给了 LVDSE25/33 两列)

## 七、与 PH1A60 的对照 (同日实测)

| | EG4A20BG256 | PH1A60GEG324 |
|---|---|---|
| 安全线速率 | **700M** | 800M |
| 200MHz 时序 | +0.102(不含抖动) / 5 级 | **+1.488 (余 30%) / 3 级** |
| fabric 天花板 | ~204 MHz | ~380 MHz |
| 対数 | 86 干净 / 需 87 🔴 | 100 全真差分, 宽裕 |
| 色深 | 锁死 8-bit | 12-bit 有余量 |
| 3R 电阻 | 153 只 | 不需要 |

🎯 **4:1 不是问题, 55nm 才是** —— PH1A60 同为 4:1 但 28nm 把它抹平了。

---

# ✅ 2026-09-04 晚 TD 实测 (工程 `pov3d/eg4_a20_pinfit/`, 器件串 **EG4A20BG256I7**)

⚠ TD 里**没有 `EG4A20BG256I`**, 只有 `EG4A20BG256` 与 `EG4A20BG256I7`; arch-db `eagle_20.db`。

## ★ 差 1 対不存在了 —— JTAG 能回收, 但不是 set_device_param

- ❌ 直接绑 JTAG 脚: `USR-8027 ERROR: Location H3 is for dedicate pin.`
- ❌ `set_device_param tdi_tms_tck_tdo gpio`: `PRG-8000 ERROR: Failed to get ConfigReg from tdi.`
  —— 它属 **Programmer 命令族**(作用在 bit + 已连芯片), **答不了这个问题**
- ✅ **真正的开关在工程文件的 `<Device_Settings>`**:
  ```xml
  <Device_Settings><dedicated><tdi_tms_tck_tdo>gpio</tdi_tms_tck_tdo></dedicated></Device_Settings>
  ```
  🔴 **必须两层**(一层报 `PRG-5104 Unknown device setting <xmlattr>`);
  🔴 **值写在元素正文里不是 `Val=` 属性**(写 `Val=` 报 `PRJ-5608 WARNING` 然后**静默回落成 gpio**)
  合法值 `gpio`/`dedicate`/`reserved`; 生效后 `ARC-1004: marked 1 dedicate IOs`(从 5 降到 1)
- ✅ **L8_1(H3/H4) 与 L11_1(J4/J3) 都能当真差分対**(`LVDS33`+`ODDRx2l`→DDRX2L, 到 bit),
  TD 自报可用 IO **191→195**。L9_1 仍废(N 脚是 PROGRAMN)。**净 +2 対 +1 单端(J5)**
- 白捡: ARC-1001 表显示 **`done`(H14)/`initn`(F4)/SPI 五脚出厂就是 gpio**, 一行设置都不用写
- 代价(UG303 表 2-1 背书): **配置后 JTAG 失效, 只能 PROGRAMN 重配** ⇒ 只适合量产位流

⇒ **干净 86 + 回收 2 = 88 対 ≥ 需求 87, 余 1** ✅

## 全量布通了
`build.sh C` 方案甲 103 行约束全部球位现查: `#IO 102/191`、`#pad 189/191 (98.95%)`、
**零 ERROR 零 CRITICAL、到 bitstream**, 无 bank 撞墙(bank1 25 脚一根不剩)。
`R5_6`(MSEL2/1) 作普通 LVDS25 差分対被直接接受, 不需任何设置。
🎯 **LVDS 输入自动开片内 100Ω**(`DIFFRESISTOR:100`, .adc 没写) ⇒ 端接电阻可省。
✅ 采纳 C2 变体: **TX 时钟対从 MSEL 対换成回收的 L8_1** —— 时钟対不该挂在带下拉电阻的 MSEL 脚上。

## bank8 = 2.5V + LVDS25_E: 工具认
8 対 `IO_TE*P_8` 挂 ODDRx2l, 三道 DRC 零报错到 bit, `.area` 全是 `PackReg=DDRX2L`。
TD 不打印 VCCIO 数值但打印 `PHY-3001 : BANK 8 DIFFRESISTOR:NONE VOD:350M VCM:1.2`。
对照实验: bank8 里再放 `LVCMOS33` ⇒ `USR-8001 ERROR: multiple IOSTANDARD setups on bank 8`,
换 `LVCMOS25` 一路到 bit ⇒ **TD 按 bank 统一电压校验, `LVDS25_E` 就是 2.5V** ✅
⚠ `LVDS33_E` 工具也收到 bit, 但 TN309 §4.3 只写 LVDS25E ⇒ **工具接受≠手册背书, 别用**。

## 🎯 VCM/VOD 实测 (推翻了"不可调"那个结论)

**出处: TD 用户手册 `td_ug62` §9.1 表 9-2** —— ADC = **Anlogic Design Constraint**(.adc 约束文件),
不是模数转换器。我之前被缩写误导、又只查了 `eagle_macro.v` 没有 BANKREF 原语就下结论,
**物理约束不走原语, 这是把"没找到"当成"不存在"**。

| Device | VOD(mV) | VCM(V) |
|---|---|---|
| **EG4** | 150/200/250/**350\***/480 | **0.8/0.9/1.2\*** |
| EF2 | 同上 | **不支持** |
| EF3 | 同上 | 0.8/0.9/1.2* |

写法 `set_pin_assignment {x} { LOCATION=A3; IOSTANDARD=LVDS25; VCM=1.2; VOD=350m }`

**TD 自报合法值, 与表 9-2 逐字一致**:
`USR-8059 ERROR: Invalid attribute/value VCM/1.0 ..., valid values are 0.8/0.9/1.2.`
`... VOD/300M ..., valid values are 350M/150M/200M/250M/480M.` (VOD 必须带 `m`)
**能验证生效**: phy_1 log 的 `PHY-3001 : BANK 5 ... VOD:250M VCM:0.8` 跟着约束走(八档全试);
`.area` 报告里**不显示**。

🔴 **两个坑**:
1. **VCM/VOD 是 per-bank 不是 per-pin** —— 同 bank 两个值报 `USR-8001 multiple VCM setups on bank 5`
   ⇒ **同 bank 所有真対共用一个共模, 不能按链调**。方案甲的真対在 bank5/6, 是两个独立组。
2. **给仿真対(`LVDS25_E`)写 VCM 不报错且真写进 bank 配置**, 与手册"只针对 LVDS25/LVDS33"矛盾;
   加在 LVCMOS 上则完全静默 ⇒ **永远别给仿真対写 VCM**。

🔴 **`PREEMPHASIS` EG4A20 不支持**: `USR-8409 ERROR: PREEMPHASIS is not supported by IOBE.LVDS25 in OUTPUT direction.`
(`ZZZ` 与 `ON` 报同一句 ⇒ 属性被否не是值非法; LVDS33 同) ⇒ **800M 上行 SI 只能靠走线/端接/VOD**。
(TD 手册表 9-1 的通用属性表里有 PREEMPHASIS, 但 EG4 这颗不支持 —— 又一处"通用表≠本器件")

## 与 2260 直连的最终账

| 项 | 2260 (DS V1.7) | EG4 可设 | |
|---|---|---|---|
| 共模 | `VIC` 1.1/**1.2**/1.3 V | **`VCM=1.2`** | ✅ 正中 |
| 差分 | `VID` ±100~±600 mV | `VOD=350m` | ✅ |
| 阈值 | `VTH/VTL` ±100 mV | VOD 350 > 100 | ✅ |
| 端接 | `RBD` 80/**100**/120 Ω | 片内 100Ω **自动开** | ✅ |

⇒ **四项全匹配, 22 対真差分可直连, 88 只 AC 耦合元件省掉** —— 但这是"工具接受"级,
DS300 表 3-1-15 只有 `VOCM 0.6~1.4V` 一个**包络**、没有分档规格 ⇒ 仍需 FAE 给容差。

## ✅ VCM 精度已向供应商确认 OK (2026-09-04) ⇒ 共模这条轴关闭

⇒ **22 対真差分直连 2260, 不做 AC 耦合, 省 88 只元件**(22 対 × 2C + 2R)。

### 落到原理图上的三条
1. **VCM 是 per-bank 不是 per-pin** —— 走真差分驱屏的 bank **整个 bank 设 `VCM=1.2`**,
   同 bank 内不能有想用别的共模的真差分対。方案甲真対在 bank5/6, 两个独立组各设各的 ✅
2. **永远别给仿真対写 VCM** —— 实测给 `LVDS25_E` 写**不报错且真写进 bank 配置**,
   与手册"只针对 LVDS25/LVDS33"矛盾。仿真対共模由 3R 网络定 = VCCIO/2 = **1.25V**, 本来就在窗内。
3. `.adc` 写法: `set_pin_assignment {x} { LOCATION=..; IOSTANDARD=LVDS25; VCM=1.2; VOD=350m }`
   (VOD 必须带 `m`; VOD 350m 落在 2260 的 VID ±100~±600 内且 > VTH 100mV)

## 🔴 JTAG 释放的三条落地决定 (2026-09-04)

### 1. JTAG 不是永久失效, 下载一直能用
设置写在**位流**里, 所以时间线是:
```
上电 → 芯片未配置 → JTAG 是专用脚, 可用 ✅ (UG303 表2-1: TMS/TCK/TDO/TDI 的 pre-config 状态是 Pull-up to Vccio)
  ↓ 加载位流
DONE 拉高 → 4 个脚变用户 IO, JTAG 失效
  ↓ 拉低 PROGRAMN
回到未配置态 → JTAG 又可用 ✅
```
**失去的只是"运行中的在线调试"**(读回、TD debug hub), 不是下载能力。

### 2. 而运行中在线调试本来就不可行 —— 屏板在 900 RPM 转子上
离心 68~136 g, **JTAG 排线接不上去**; 停机才能接, 而停机拉 PROGRAMN 就恢复了。
⇒ **真正的调试通道是引脚预算里已有的两根 UART**(桥片↔DR1), 转着也能用, JTAG 做不到。

### 3. 双位流工作流
| 场景 | 位流 | 対数 | JTAG |
|---|---|---|---|
| 量产/上转子 | 释放 JTAG | 88(用 87) | 停机 + PROGRAMN 可恢复 |
| 台架调试 | 保留 JTAG | 86 | ✅ 全程可用(砍一条链或暂不接 RX 时钟対) |

### 🔴 4. J3(CSN) **不要加外部下拉** —— 两份笔记冲突, 以此为准
回收的 **L11_1 = J4(TDO) + J3(CSN)**。`notes_config.md` 建议"CSN 加 1 kΩ 下拉到 GND",
但 **J3 若用作 LVDS 引脚, 这只 1 kΩ 会把差分线拉偏**(相对 100Ω 端接只有 10 倍, 共模塌)。

【UG303 表 2-1 原文】`CSN | Pull-down to Gnd | Pull-down to Gnd | **User I/O**`
—— post-config 是 **User I/O 无条件**(连 JtagPin 设置都不需要); pre-config **内部就有下拉**;
注 1 的要求只是"在 JTAG/SS/MSPI 模式**不能为上拉状态**"。
⇒ **内部下拉已满足要求, 外部电阻不必要且有害。原理图上写死: J3 不加任何外部电阻。**
(`notes_pinplan.md` 的 "J3 CSN 悬空(内部下拉)" 是对的)
⚠ 顺带: 若不释放 JTAG, J4(TDO 上拉) 与 J3(CSN 下拉) 同対而外部网络相反, **打样极易贴反**。

### 备选(不推荐): TX 时钟対改单端
下行 166 MHz 时钟対改 LVCMOS25 单端再由外置扇出芯片转差分, 也能省 1 対。
但引入板上单端 166 MHz 信号, SI 差得多, 且扇出芯片输入要重新选型。
**相比之下释放 JTAG 更干净 —— 反正转子上用不了。**
(400 MHz 的上行时钟対不能这么改, LVCMOS25 上限 166 MHz)

## 仍只能问供应商的 (只剩 1 条)
🔴 **A20BG256I7 生命周期 / 供货**
另需索取 **IBIS 模型**(验证板 SI 仿真必须)。

## 还没做的
- IOL 内 pclk↔sclk 相位: 实验在跑(方案 F vs PLL 直出+FPHASE 移相, 以及能否让 STA 检查这条路径)
- 实验 C 里 IDDRx2 的 pclk/sclk 都接了 sysclk(电气无意义, 只为让 IOL 按 DDRX2 打包)
  ⇒ **"RX 时钟対怎么进 BUFIO/PLL" 仍是独立一道题**
- 所有 ✅ 都只到 bitstream, **是工具层面结论, 不等于上板可行**

相关: [[project_eg4_bridge_verification]] [[project_pov3d_uplink_rate_pin_budget]]
[[reference_eg4s20_bank_voltage_and_lvds33]] [[reference_bridge_fpga_alternatives]]
[[project_pov3d_chip_arrangement_4x6]]
笔记原文: scratchpad `eg4docs/notes_{clock,pinplan,config}.md`; 手册在 `pov3d/EG4/`
