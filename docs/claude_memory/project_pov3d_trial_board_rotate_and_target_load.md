---
name: project_pov3d_trial_board_rotate_and_target_load
description: 2026-09-17 用户定两条 — ① 试验板(DR1M90 + 2×GW5A + 2 块 160×180 2260 灯板)要上转子转起来 ② 试验板按目标板负载压测(48 扫帧长 9,045 fps / 上行 24 链 18+1 lane 满载); 由此新增的转子侧硬件/结构/软件待办清单
metadata:
  type: project
---

**用户 09-17 原话**: "1.实验板要转 2.实验班按目标板负载压测"。
背景: 最终产品仍是目标板(24 颗/面 192×216 48 扫); 现役能转的只有 ICND2047 偏心双屏, 2260 从没转过
⇒ 试验板是**第一台转起来的 2260 + 桥片 + DR1M90 整链**。见 [[project_pov3d_trial_board_503_slices_60scan_ok]]。

## 两种运行模式 (同一 DCLK 166.67 MHz)
- **显示模式**: 60 扫全画面, n_slices=503, 7,545 slice/s/面 — 看图、调驱动
- **目标压测模式**: 2260 只用 48 扫(49~60 行不亮, 帧长 15,715 拍), n_slices=603 ⇒ 9,045 slice/s/面 = 目标时序;
  上行按 24 链 + 18 数据 + 1 校验 lane 满载, 多出的 12 链是假数据只进误码计数; DR1 侧按 603×41,472/面 的数据量取片+解码; WiFi 按目标载荷推流
- 48 扫帧率上板从没测过(11k 那次是 45 扫) ⇒ 压测模式本身就是这个验证

## 转起来新增的约束 (记忆库已有的事实)
- 离心 68~136 g ([[project_pov3d_master_and_bridge_both_on_rotor]]): USB WiFi dongle / **DR1M90 从 TF 卡启动, 卡座会甩** / ACG525 板对板连接器 / FS03 2.5V 改板的杜邦壳 LDO 模块(v2.2 做法)都不能直接上转子
- 供电: 无线 48 W 天花板 ([[project_pov3d_rotor_wireless_power]]); DR1M90 唯一入口 Type-C VBUS, 突发电流已实测掉电复位 ⇒ 转子上要 24V→5V DCDC + 储能; 储能电容容量计算仍未做
- 光电: 现役 spin_sync_i = W6 (bank11 LVCMOS33), bank11 改 2.5V 后必须挪, 占 V3 余下 IO (15/16)
- 几何: 背靠背间距要按试验板实测重给 gap_mm ([[project_pov3d_offset_axis_geometry]], 旧 13.8mm 是 2047 屏), 镜像/手性要重核
- 转动时没有串口 ⇒ 状态/误码/日志必须走 WiFi 读

## 试验板验不了的 (别误以为压测覆盖了)
24 颗/面的峰值电流与热、目标板 8 层 HDI 的 SI、自研 SoC 板的 LVDS25 共模、192×216 光学。

**How to apply:** 排试验板任务时两种模式都要进固件与上位机; 结构同事那边版本一要加"试验板转子装配"。
