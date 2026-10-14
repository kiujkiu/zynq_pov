---
name: project-motor-ctrl-interface-1014
description: 10-14 SoC 转接板加电机控制器口 (UART + 模拟光电 IDX), 管脚已确认 (撤 S2, JTAG 菊花链)
metadata:
  type: project
---
2026-10-14 用户提出: SoC 和电机控制器要通信, 用串口; 再加 1 根 IO 传角度, 让电机控制器模拟光电开关上报 (实时性好)。用户要求只整理 SoC 转接板接口。

产出: zynq_pov/docs/SoC转接板接口_电机控制器口_2026-10-14.{html,pdf}。新 CN4 (XH 4 针): GND / MOT_IDX→CEP2_24P / MOT_TX→CEP2_8P / MOT_RX→CEP2_8N, 无备用脚, CEP2_24N 留空 (10-14 用户定), 经 SN74AVC4T774 (2.5↔3.3 V); CN3 真光电保留, 0Ω 二选一。

**Why:** 整板空闲只剩 CEP2_8P/N + CEP2_24N, 用满需 JTAG 维持菊花链 (撤回 10-12 审查单 S2)。
**How to apply:** 10-14 用户确认24P=光电 8P=TX 8N=RX (M3 关闭); 仍待 M1 转子/定子 (🔴 转子无线供电, 跨界无电线 [[project-pov3d-rotor-wireless-power]]; 控制器在定子则 CN4 不能直连, 角度回 CN3 真光电、串口走 WiFi/红外)、M2 电平, 定了再写进改板单。
