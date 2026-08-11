---
name: reference_panel_oe_no_pullup_anywhere
description: 屏 OE(网名GCLK) 全链路四块板都无外部上拉; 但 FS03 HSWAPEN=0 使配置期自带片内上拉, 真危险窗口只有 PhaseRAMP, 而 Zynq 同链路已长期验证可接受
metadata:
  type: reference
---

# 屏 OE 上拉排查结论 (2026-08-07, 查图纸得出, 未上板)

OE 在链路上的网名是 **`GCLK`**（旧 PWM 芯片遗留名，别被名字骗了）。
FS03-DR1 上 = ball **AB9 = CEP2_6N = J12.14**；屏2 = **AB1 = CEP2_16N = J12.34**。

## 1. 全链路四块板：一颗上拉都没有

| 板 | 图纸出处 | OE 网上有什么 |
|---|---|---|
| FS03-DR1 底板 | `MLKPAI_FS03_DR1_241023.pdf` sheet 17 (P17_GPIO) | R201 排阻 **33Ω 串阻**，无上拉 |
| 米联派接口板 | `zynq-mlp_gpio_pV1.0/SCH/mlp_panel_v1.0.pdf` | **10Ω 串阻**(R16/R22)，无上拉 |
| 转接板 v1.2 | `zynq-mlp_pV1.2/SCH/LKS_FOC.pdf` | 网 `NLGCLK` 全网**只有 2 个脚**；全板 6 个电阻全是 TPS565201 的 FB 分压 |
| 屏本体 | `C2-P0.9375-ICND2065-RT5960-IC-SCH.pdf` | **33Ω 串阻 + 33pF 对地**。全屏 38 个电阻 = 37×33Ω + 唯一 1 个 4.7K(R21，是 `HDCLKIN` 的**下拉**) |

顺带纠正：`reference_led_panel_hardware.md` 记的「74HC245×8 level shift」在这张屏图纸上找不到，
OE 是**直接进 ICND2049** 的。

## 2. 但风险分段和原先猜的不一样 —— 这是关键

| 阶段 | PL I/O | OE | 判断 |
|---|---|---|---|
| PhaseRAMP（上电中，POR 未完成） | 全三态（DS1200 §3 图3-2 注2） | 悬空 | 🔴 唯一真危险，片内上拉此时还没配置 |
| POR 完成 → 配置成功 | **HSWAPEN=0 ⇒ Pull-up to Vccio** | 1 = 消隐 | ✅ 本来就安全 |
| DONE → 第一个 aclk 沿 | ODDR 驱动，初值未文档化 | ❓ | ⚠ 但 aclk=p2f_clk 已在跑 ⇒ 窗口 **≈20 ns** |
| 之后 | q = oe_r = 1 | 1 | ✅ |

**HSWAPEN=0 硬证据**：FS03 sheet 5 右下 `VCC_3V3 —R29(NC)— HSWAPEN —R30(1K)— GND`，
上拉 DNP、下拉实装。对应 DS1200 §2.8.2 表 2-5「PL I/O 非配置: HSWAPEN=0 → Pull-up to Vccio」。

⇒ **原来担心的「配置期间整屏导通」在这块板上不成立。**

## 3. 为什么最终判定「可以直接接屏，不必先焊电阻」

**Zynq 那套用的是完全相同的下游三块板**（推导链 `ball ↔ J12 ↔ 接口板 P1/P3 ↔ 转接板 ↔ 屏J1`，
见 [[project_pov3d_trans_v12_pinmap]]）。Zynq PL I/O 上电期同样三态 ⇒
**Zynq 已经带着「上电期 OE 悬空」跑了几个月这块屏，没烧过**。
经验上这一段风险可接受 —— 这是纸面推理给不出的结论。

## 4. 已做/可选的加固

- ✅ **已做，代价 0**：`.adc` 给 `panel_oe`/`panel_oe_2` 加 `PULLTYPE = PULLUP`
  （不再依赖 HSWAPEN 跳线）。TD 5.9.1 接受输出脚带 PULLTYPE，`.area` 报告可见
  `panel_oe OUTPUT AB9 LVCMOS33 HRIO 4 PULLUP`。
  改动放在 `tools/xdc2adc.py` 的 `DR1_EXTRA` 表里而非手改 `.adc`（源 XDC 在只读的 `mlkpai_fs03/`）。
- ⚪ **可选加固**：FS03 J12 焊 4.7 kΩ，pin1(VCC_CEP2=3.3V) ↔ pin14(OE)；屏2 是 pin1 ↔ pin34。
  上拉到 VCCIO 同轨 ⇒ 连 PhaseRAMP 都覆盖。4mA 驱动器灌 0.7 mA、经 33Ω 只产生 23 mV 偏移。
  ⚠ 50pin 排线的 pin1 本来就要求断开（接口板会把自产 5V 灌回），但 **FS03 侧 J12.1 的 VCC_CEP2 仍在**。

## 5. 为什么**不**走 `DR1_LOGIC_IOTRIBUF`

- 只能消掉那 20 ns，而 PhaseRAMP 才是真危险 —— 性价比反了
- 原语要求「connect directly to top-level port」⇒ 顶层 `panel_oe` 得改成 `inout`，
  破坏 [[project_dr1_rtl_port_step1]] 的「core RTL 零改动」性质
- `ODDR.q → IOTRIBUF.i → pad` 之后 TD 还能否把 ODDR 打进 IOL **未验证**；
  一旦掉出 IOL，实测过的「半拍边沿推迟」（50 Mbps/lane 的物理前提）会**静默失效**。
  判据：综合后 `.area` 的 `#pad reg` 是否仍等于 ODDR 实例数
- 高阻期要靠片内弱上拉拉过屏的 VIH≈2.66V，而 **DS1200 表 3-8 的 IPU 全是 "TBD"** ⇒ 纸面无法论证

（`t` 极性已查实：**high=高阻 / low=驱动**，见 `sim_release/dr1/dr1_logic_iobuf.v`。留档备用。）

## 6. 一个前提，将来可能失效

上表第 3 行的「20 ns」依赖 **加载 bit 时 p2f_clk 已经在跑** —— 目前 PL 由 Linux 起来后加载
（见 [[feedback_dr1_load_bit_without_jtag]]），成立。
若将来改成**上电从 flash 直接配 PL**、而那时 p2f_clk 还没使能，这个窗口会变成**无界**，
届时 §4 的板级上拉就从「可选」变成「必须」。
