---
name: MBI 系列芯片全是 cathode sink driver (无 anode source 同类款)
description: Macroblock MBI5050/5152/5252/5253/5254/5264/5353 整条 PWM 灰度线都是 cathode sink, 跟 ICND1069 anode source 不能直接换. 行管必须额外配 PMOS 高边
type: reference
originSessionId: 27bc7e13-9205-4854-b880-8354c58d6704
---
# 事实

Macroblock 高端 PWM 灰度驱动主线 (5050 / 5152 / 5252 / 5253 / 5254 / 5264 / 5353 / ...) **全部是 cathode sink**:
- OUT 引脚对 GND 灌恒流
- 接 LED 阴极, 阳极接 VLED 高边供电
- datasheet 原文 "constant current **sinks** for driving LEDs" + "Ground terminal for control logic and current sink"
- MBI5264 advance datasheet p36 典型应用图: `VLED → LED阳极 → LED阴极 → MBI5264 OUTx → GND`

Macroblock **没有** PWM 灰度 anode source 同类产品 (高边大电流恒流 + SRAM/PWM 工艺成本不划算)。

# 跟 ICND1069 / 其他 anode source 不能直换

| 项 | ICND1069 | MBI5264/5353 |
|---|---|---|
| OUT 极性 | 从 VCC 灌出 (source) | 往 GND 灌入 (sink) |
| 接 LED 哪端 | 阳极 | 阴极 |
| 拓扑 | VCC→1069→LED阳极→LED阴极→低边行管 (NMOS) | VLED→高边行管 (PMOS)→LED阳极→LED阴极→MBI→GND |

直接换 panel 会:
- LED 反向截止不亮, 或
- 跟低边 NMOS 行管抢同侧, 不导通

要换驱动 = 整块 panel 拓扑翻面 + 重新 layout PCB。

# 行管 (anode source) 选型

跟 MBI 配套的高边行驱通常用**第三方离散 PMOS 阵列**:
- DD311, FP9933, AP3402, SCT2167, ETA9933, SH3050
- 离散 P-MOSFET: SI4435, AO3401 阵列
- (Macroblock 自家有少量 row driver / switch driver 型号属辅助线, 不是主流, 需查官网 selection guide)

# 关联待修条目

memory `project_pov3d_led_chip_decision.md` 写 "90× MBI5264 + **12× ICND3019** 行管" —— ICND3019 是 NMOS 低边 sink, 跟 MBI5264 cathode sink 同侧, **物理点不亮**。
行管必须改成 PMOS 高边 source (类似上面型号), 这条 BOM 待修正。

# 验证日期

2026-05-26 用户对话确认 + MBI5264 advance datasheet V0.01 p1/p3/p36 实读
