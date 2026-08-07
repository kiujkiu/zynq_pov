---
name: DR1 RTL 移植第一步完成 — ODDR 兼容层 + 综合 + 50MHz 时序收敛
description: 12 个 ODDR 全落 IOL(#pad reg 12); LUT 510/slice 0.84%; setup 富余 12.56ns(Fmax~134MHz); 唯一 hold 违例在测试激励里
type: project
---

2026-08-06。承 [[project_dr1_sku_decision]]（锁 DR1V90）。工程在
**`D:\claude_workspace\pov3d\dr1v90\td_panel\`**。

## 1. ODDR 兼容层 —— RTL 源码零改动

盘点修正: 老记忆写"14 处 ODDR"，**实际是 4 处例化 / 12 个物理实例**
(dclk×1 + le×1 + oe×1 + sdi×9)，全在 `icnd2047_panel_core.v` 一个文件里；
其余 Xilinx 原语 (IDDR/BUFG/MMCM/RAMB/XPM/DSP48/IOBUF) 命中数 **0**。

做法: 写 `dr1v90/rtl/oddr_dr1_shim.v`，定义一个**与 Xilinx 同名同接口**的
`ODDR` 模块包住 `DR1_LOGIC_ODDR` ⇒ **`icnd2047_panel_core.v` 一个字不改，
同一份 RTL 能同时喂 Vivado 和 TD**（TD 侧只要别把 unisims 加进来）。

映射: `C→clk` / `D1→d0`(上升沿) / `D2→d1`(下降沿) / `Q→q`。三个缺口:
| Xilinx | 安路 | 影响 |
|---|---|---|
| `CE` | 无 | ✅ 现设计 12 个实例全 `CE=1'b1` |
| `SRTYPE("SYNC")` | 只有异步 rst | ⚠ 仅复位期间差异 |
| `INIT` + `S`(置位) | **都没有** | 🔴 见第 3 节 |

## 2. 实测结果 (DR1V90GEG484 speed -2)

**资源**（`fpga_prj_gate.area`）:
```
#IO   20/201   #lut 510   #reg 589 (slice reg 577, **#pad reg 12**)
#slice 439/52480 = 0.84%   #dsp 0   #eram 0   #pll 0
```
🎯 **`#pad reg 12` 正好等于 ODDR 实例数 ⇒ 12 个全部落进 IOL，没有一个被拆成 fabric。**
这是移植第一个风险点解除的硬证据（`SYN-1043 : Mark ODDR as IO macro` 也印证）。

**时序**（50 MHz 单域，`create_clock -period 20.000`）:
```
SWNS 12.564ns  STNS 0.000   ⇒ setup 过, fabric Fmax ≈ 134 MHz
HWNS -0.056ns  HTNS -0.056  ⇒ 唯一一条 hold 违例
STA coverage 92.42%
```
🔴 但那条 hold 违例是 **`lfsr[59]→lfsr[60]`，在我自己写的综合表征顶层
`panel_core_synth_top.v(46)` 里，不在被移植的设计中**（HTNS==HWNS ⇒ 全设计仅此一条）。
⇒ **panel core 本体 50 MHz 干净收敛。**

## 3. 🔴 仍未解决: OE 复位态

原设计 `ODDR #(.INIT(1'b1)) u_oddr_oe (.R(1'b0), .S(rst_hi))` —— 要求复位期间 pad=1(消隐)。
安路 ODDR **没有置位端，复位只能拉到 0 ⇒ 复位期间 OE=0 = 屏被点亮**。
结合 [[reference_fs03_board_access]] 的"5V 轨余量紧、热插拔屏会让板子重启"，不能忽略。

shim 当前做法: INIT=1 的实例改用 `ASYNCRST("DISABLE")`，复位职责交回 fabric
(`oe_r` 复位值本就是 1) ⇒ **稳态正确**，残余风险只剩"配置完成→第一个时钟沿"这个窗口。
**接真屏前必须消掉**，两条路（都还没做）:
- a) 查转接板原理图确认 OE 有无外部上拉 —— 有就收工
- b) `.adc` 里给 OE 加 **`PULLTYPE = PULLUP`**（安路支持），或走 `DR1_LOGIC_IOTRIBUF`
  复位期间高阻。代价: OE 与 DCLK 的 pad 延迟不再严格匹配，需重核 OE 相对时序窗口。

## 4. TD 工程手写要点（GUI 不用开）

- `.al` / `.prj` 都是明文 XML，可脚本生成。`.prj` 里源文件用**相对路径**(`../../uisrc/...`)。
- 🔴 **约束文件光在 `.prj` 里列出来不生效**！run tcl 里必须显式写:
  - `syn_1`: `read_adc` 放 `commit_param -step rtl` 之后；`read_sdc` 放 `commit_param -step gate` 之后
  - `phy_1`: `read_sdc` 在 `commit_param -step place` 和 `-step route` 后**各来一次**
  没写的症状: 日志 `TMR-3001 : Initiate 0 clocks from SDC` + 时序报告里
  `Constraint File:` 为空、时钟名是 **`DeriveClock`** 而不是你起的名字。
  ⚠ 我第一次就中招，而且 TD 推导出的默认频率恰好也是 50 MHz，
  **报告看起来完全正常（SWNS 14.318ns）**，差点当成收敛证据。
  **判据: 看时序报告的 `Constraint File:` 和 `Clock-Name` 两栏。**
- 约束格式与 XDC 一一对应:
  `set_pin_assignment {port} { LOCATION=L21; IOSTANDARD=LVCMOS33; DRIVESTRENGTH=8; PULLTYPE=NONE; }`
  ↔ `PACKAGE_PIN` / `IOSTANDARD` / `DRIVE` / `PULLUP`。`.sdc` 就是标准 Synopsys 语法。
- 直接拿 `icnd2047_panel_core` 当 top 会 `SYN-8228 ERROR: IO number may exceed device max IOs`
  (`fb_dout_flat[287:0]` + `chain_data_flat[143:0]` 被当引脚 ⇒ 400+ IO > 200)。
  故写了表征顶层 `panel_core_synth_top.v`: 输入全由 **LFSR** 驱动(接常量会被常量折叠
  ⇒ 资源虚低时序虚好)，状态输出 **XOR 压成一根**(否则驱动它们的寄存器链被整条剪掉)。

## 5. 引脚约束转换完成 + 最终时序（同日稍晚）

**`dr1v90/tools/xdc2adc.py`**: XDC → `.adc` 转换器。
`PACKAGE_PIN→LOCATION` / `IOSTANDARD` / `DRIVE→DRIVESTRENGTH` / `SLEW→SLEWRATE` / `PULLUP→PULLTYPE`。
🔴 设计原则: **任何没识别的行都打到 stderr 并 exit 2，绝不静默丢弃** ——
XDC 末尾那几行 `set_property SLEW SLOW [get_ports panel_*]` 通配覆盖如果被漏掉，
产物看着完全正常但 2026-07-16 定下的 SI 整形(分层驱动)全没了。
实测: 30 引脚 / 5 处通配覆盖全部生效 / 0 行未识别。
`panel_dclk` 拿到 DRIVESTRENGTH=16(强驱动压耦合)、`panel_lat/oe` 4(弱驱动减 dV/dt)、全体 SLEWRATE=SLOW ✓

**pin2pin 从"文档核对"升级为"工具认账"**: 15 个屏 1 引脚喂给 TD，
**零错误零警告** ⇒ 这些球位在 DR1V90GEG484 上确实存在、是合法 PL IO、
LVCMOS33 + DRIVESTRENGTH 16/8/4 + SLEWRATE SLOW 全部支持。
（`row_bk` 本就不分配引脚 —— RTL 注释"接口板确认前悬空"，且它是 `cfg[16]` 静态电平。）

**最终时序 (带真实引脚)**:
```
SWNS 12.091ns  STNS 0.000    ⇒ setup 满足
HWNS +0.009ns  HTNS 0.000    ⇒ hold 满足
Fmax 126.438 MHz             ⇒ 需求 50 MHz 的 2.5 倍
STA coverage 92.53%
```

🔴 **但 hold 是靠打开 `fix_hold` 才干净的，默认是关的。**
不开时: `HWNS -0.011 / HTNS -0.019`，两条违例在 **`u_core/mchain_sh` 移位链**
(`icnd2047_panel_core.v:155`)，成因是 clock skew 0.171ns + TD 默认 clock uncertainty 0.100ns
(我的 SDC 没写 `set_clock_uncertainty`)。**hold 违例降频救不了，必须开这个开关。**

设参数的语法（手册只列参数不给命令，是我逐个试出来的）:
```tcl
set_param place fix_hold on     # 放在 commit_param -step place 之前
set_param route fix_hold on     # 放在 commit_param -step route 之前
```
即 **`set_param <步骤> <参数名> <值>`**；`set_param fix_hold on`(不带步骤)会失败。
可调参数从 run.log 的 "Print Place/Route Property" 表里看
(effort / fix_hold / opt_timing / post_clock_route_opt / pr_strategy / relaxation / priority)。
`fix_hold` 实测耗时 1.6s，setup 零退化。

## 下一步
1. IO delay 约束 + 眼图 —— ⚠ **需要安路下载器，至今没到手**（唯一硬阻塞）
   安路有 `InDelay`/`OutDelay` 引脚属性可当 DCLK 半拍落点的微调旋钮。
2. OE 复位态收口（第 3 节，`PULLTYPE=PULLUP` 或 IOTRIBUF）
3. 把 P3 那一组(屏 2)也纳入 —— `xdc2adc.py` 已能一次转全部 30 个引脚

## ✅ 2026-08-06 上板实测: DCLK 波形出来了

探针工程 `dr1v90/dclk_probe/`（接屏零风险: 只有 DCLK 翻转, OE 恒 1 消隐 + 引脚上拉,
LAT/SDI×9/行驱全恒 0, 板载 LED 跑马灯当心跳）。经 Linux 侧 PL 加载
（[[feedback_dr1_load_bit_without_jtag]]）烧入，实测:

- **DCLK = 12.5 MHz** ✓ (= 板载 sysclk 25 MHz ÷ 2，符合设计)
- 引脚链路 `panel_dclk` → ball Y10 → CEP2 J12.12 通 ✓
- 板载 LED 跑马灯正常 ✓（**LED 是低有效**，第一版写成高有效被用户一眼看出"一灭七亮"）

🎯 **顺带得到一个免仪器的时钟校验法**: 心跳 LED 每 2^24 拍走一格 ⇒
25 MHz 下应为 **0.671 s/格**。用户掐表 **33 s / 50 格 = 0.660 s/格**（误差 1.6%）
⇒ **sysclk = 25 MHz 被独立确认**。这个方法在怀疑时钟源时非常好用，不需要示波器。

### 🎯 半拍边沿推迟已验证 (2026-08-06 晚, 用逻辑分析仪抓包反算, 不需要示波器)

做法: 在同一连接器上再引一路**普通寄存器**产生的同频方波当参考
(`panel_lat`/AA9/J12.15, 驱动强度对齐到与 DCLK 相同的 16mA), 与 DCLK(Y10/J12.12) 同时抓,
然后**自己解析 `.dsl` 原始采样**算相位差(工具 `dr1v90/tools/dsl_duty.py`;
`.dsl` 就是 zip: header/session + 每通道 1bit/采样的位流, `numpy.unpackbits(bitorder='little')`)。

```
上升沿相位差 均值 -19.75 ns    分布仅两档: -16ns(53.1%) / -24ns(46.9%)
下降沿相位差 均值 -20.35 ns    同样两档
理论:  半个 sysclk 周期 = 40/2 = 20.00 ns          ⇒ 误差 1.3%
```
分布在 8ns 采样格相邻两档间近似对半分 = 真值恰在两档正中的特征;
反推 `(24-t)/8=0.531 → t=19.75ns`, 与均值自洽。
⇒ **`ODDR SAME_EDGE` 的半拍延迟在安路 IOL 上成立**, 这是 50 Mbps/lane 的物理前提。

### 🔴 "占空比 60%" 是测量假象, 不是 IOL 失真

仪器显示 DCLK 60%/参考 50%, 一度以为是安路 IOL 的真实占空比失真(那会很严重:
全速数据眼仅 20ns、边沿裕量 10ns)。解原始数据后推翻:
- 高电平时长在 **5点(40ns)/6点(48ns) 之间抖动**, 不是稳定 6 点 ⇒ 跳变落在采样格之间, 界面显示的是中位数
- 算真实均值: 两路**都是 ~56%**, 包括构造上必然 50% 的参考路 ⇒ **共模偏置, 来自测量链路**
- 根因: `Threshold Level = 1`(约 1V, 而信号摆幅 3.3V) **门限不在中点** + `SLEWRATE=SLOW` 的慢边沿
  ⇒ 上升沿提前过门限、下降沿推迟过门限 ⇒ 高电平被系统性拉长

**方法论**: 单看一路的占空比数字无法区分"真失真/量化误差/门限偏置";
**在同一连接器上加一路构造已知的参考信号做差分**, 一次就把三者分开了。

⚠ **仍未测: 边沿质量**(上升/下降时间、振铃、过冲)。门限偏置反推提示边沿可能偏慢,
但逻辑分析仪测不了这个, 需要 **≥100MHz 带宽示波器 + 短地线探头**。
全速(aclk 50MHz)时数据眼只有 20ns, 边沿若真的很慢会吃裕量 —— 这一项仍挂着。

~~⚠ **仍未验证: `SAME_EDGE` 的半拍边沿推迟**（25 MHz 下 = 20 ns）。~~
频率正确只能证明 ODDR 在工作、分频对，**证明不了边沿落在数据眼中点** ——
而那才是 50 Mbps/lane 成立的原因。需要 **≥100 MHz 带宽示波器 + 短地线探头**
（长地线会自己引入振铃，而 2026-07-16 那次 SI 排查的根因正是 CLK 上 2-4 ns 振铃假沿）。
逻辑分析仪回答不了这个问题。
⚠ 排查中一度读出 500 kHz —— 是**采样率 1 MS/s 混叠**(|12.5−12×1|=0.5 MHz，分毫不差)，
后经用户复核确认实为 12.5 MHz。测高速时钟先确认采样率。

## 🔴 教训: 目录改名时的全局 sed 事故 (2026-08-06)

代码目录 `anlogic_dr1/` 改名为 `dr1v90/`(用芯片命名建仓库)后, 我对记忆库跑了
`sed -i 's/anlogic_dr1/dr1v90/g' *.md` —— **误伤两处**, 因为这个字符串有三种不同含义:

| 出现处 | 该不该改 |
|---|---|
| `D:\...\anlogic_dr1\bench\` 路径 | ✅ 该改 |
| `reference_anlogic_dr1_fs03_eval` **记忆文件名/wiki 链接** | ❌ 改了变死链 |
| `anlogic_dr1_kernel_defconfig` **SDK 里的真实文件名** | ❌ 改了配方跑不通 |

**批量替换前先看一遍所有命中**(`grep -o` 列出上下文), 尤其警惕:
标识符/文件名里恰好含有同样的子串。改完必须**回读校验受影响的引用是否仍然解析得通**
(本例: `ls reference_anlogic_dr1_fs03_eval.md` 是否还存在、defconfig 名是否与 SDK 一致)。
