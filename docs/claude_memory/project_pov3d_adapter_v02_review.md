---
name: project_pov3d_adapter_v02_review
description: 2026-09-18 审转接板新版原理图 ACG525-LED-V01 — V01 的 5 条大问题改对了(引脚账 154/154、ACK_I 不进 FPGA、P/N 接反、上行挪 bank4/5、FPC 20 対+JTAG); 🔴 但脚位照 09-16 旧灯板画 ⇒ 与灯板 PCB 差 80 个信号脚(链1/2 与链6/11 连错连接器) · VCC3P3 无来源 · VCCIO45 被灌 2.5V(契约要 3.3V 固定) · 2.8V 用 2A 的 STI3411A 带 4.6A · UL_CLK 落到无 GCLK 的脚 · FPC 尾部 9 位错位 · JTAG 无电平转换无下载座 · RSTN 靠下拉保复位在 TXS0108E 上不成立
metadata:
  type: project
---

# 转接板 ACG525-LED-V01 (09-18 版) 审查

原件 `C:\Users\wanqi.liu\Downloads\ACG525-LED-V01_2026-09-18.pdf`(1 页 A2)。完整结论: `zynq_pov/docs/转接板原理图审查_ACG525-LED-V01_2026-09-18.md`。
拓扑澄清(用户 09-18): **灯板 → 转接板 → GW5A 核心板**, 灯板的座子只对转接板。

## 🔴 最要紧的一条(我自己复核过)
转接板 ↔ **灯板 09-16 PDF**: 124 信号脚 0 处不符; 转接板 ↔ **灯板 PCB 09-18 实际**: 只有 44 对得上, **80 处不符**。
两边网名集合相同、位置被打乱; **链1/链2 灯板在 CN2 而转接板按 CN1, 链6/链11 相反** ⇒ 有两条链连错连接器。
换算规则(灯板 k↔转接板 2k−1 / m↔2(101−m))仍成立。⇒ **用户 09-18 定: 只改转接板, 灯板不动**。改表已出: `zynq_pov/docs/转接板脚位改表_按灯板PCB_2026-09-18.md`(逐脚 应接网络/现状/球位)。80 根里 48 根是同座换脚、**32 根(链1/2/6/11)要整链换到另一个座子** —— 要么跨座走线, 要么改这 4 条链的 FPGA 球位(则 .cst 重出), 二选一。注意: 单纯改连接器脚位**不需要动球位**, 但 09-16 那份 .cst 因转接板自己重排过球位仍然作废。

## 其它 🔴 (子代理机读, VCC3P3/VCCIO45 两条我复核过)
- **VCC3P3 无来源**: 全图只有 U5=2.5V/U6=2.8V/U7=3.8V, 没有 3.3V; 而核心板 VCCX/JTAG bank10/片内 100Ω 端接都靠它。
- **VCCIO45 = PWR2V5 经 L3** (渲染确认), 契约 E09 要求 3.3V 固定(bank4/5 挂 flash 与配置电路, 4.7k 上拉到 VCC3P3, 50M 晶振入 T9) ⇒ MSPI 自动加载会失败 + 3.3V 灌进 2.5V bank。根因是把链5 D0 与 4 根边带塞进了 bank4/5。
- U4 一颗 TXS0108E 的 A 口跨 bank2/3/5/6/7 两种 VCCIO(只有一个 VCCA) —— 09-16 本来拆成三颗。
- **U6 STI3411A 只有 2A**(手册首页), 2.8V 满流要 4.6A; 且 10.7A 仍全过 AXK(0.5A/针, 整只 ≤10A)。
- UL_CLK 落到 B5_B6(无 GCLK/PLL), 契约是 B4_B33(GCLKT_9A/BPLL)。
- FPC 契约位 64~72 整体错位(UART/JTAG 四根被短到地), 且 FPC 座疑似只有 70 导体(契约 72)。
- JTAG 无电平转换 + 无本地下载座(CN5 改成 5V 输入座了)。
- **RSTN 靠下拉保复位在 TXS0108E 上不成立**: 它两侧各有内部 4kΩ 上拉 ⇒ B 侧 10k 下拉时 RSTN 高只有 2.71V, 对 2260 VIH(估 2.66V) 余量 50mV。RSTN/SYNC 要换单向带 OE 的推挽转换器。
- 磁珠后面零电容, 核心板座电源脚一只电容都没有。

## 🟠 值得记的
TXS0108E OE 被上拉常使能(TI 要求下拉+等电源稳); U3 VCCA=1.5V 贴下限; ACK_I 上拉改成 4.7k 放远端(定案是 100k 紧靠 N12); 上行每根串 0402 0Ω; 无 EN_3V8/EN_2V8; B5_B8/B5_B12(flash SO/SSPI_WPN)被当上行 lane 用。

**How to apply:** 灯板/转接板任何一方改连接器脚位, 另一方和 `.cst`、`GW5A转LED转接板_逐球引脚分配_mkxlsx.py` 的输出必须同步重出; 比对脚本在 `/tmp/.../scratchpad/adapter_v02_review/`(cn.json = 转接板逐脚) 与 `scratchpad/pcb/pcb_cn.json`(灯板 PCB 逐脚)。
相关: [[project_pov3d_led_board_pcb_v01_review]] [[project_pov3d_led_board_sch_0916_review]] [[project_pov3d_gw5a_adapter_v01_pin_shortage]]
