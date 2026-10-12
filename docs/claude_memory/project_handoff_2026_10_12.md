---
name: project-handoff-2026-10-12
description: "2026-10-12 傍晚换 WSL 内核 (IP-guard 兼容) 前的交接: 做完了什么、三个待合并分支、D9 停在哪、WiFi 测速、待用户决定的事"
metadata:
  node_type: memory
  type: project
  originSessionId: 8546d15b-e447-401c-ad29-dcf7e23adf7b
  modified: 2026-10-12T08:01:57.155Z
---

2026-10-12 傍晚, 用户决定换 WSL 内核 (IT 给的 IP-guard 兼容 6.6.114.1, 见 [[project-ipg-wsl-kernel-switch]]) 以根治 D 盘 EIO。
用户原话: "本次只做到 wifi 验证, 其余的等 wifi"。换内核前只等 WiFi 点对点测速做完, 合并等其余事都放到换完之后。

## 今天已完成并已合入 feature/lvds-b2b (dr1v90, ~/pov3d/dr1v90, 5204170, origin 已推)
- 1.3.14 目标板 UL_IDLE_OK=1、1.3.6 STRESS 压测 profile、1.3.7 转接板真引脚 (10-10 原理图, 6 链首映射临时) —— 合并验证过; 四套位流在正式分支重综合, 结果在 gw5a_bridge/results/*_rel (含 bridge.fs)。
- 任务表 (zynq_pov) 已更新: 1.3.6/1.3.7/1.3.9/1.3.14 完成, 1.2.1.b D5 完成, 1.2.1.c D8 过 → 70%。
- D5 双面、D8 3-bit ramp 上屏目视通过 (见 [[project_dr1m90_d1_display_bit]])。

## 三个分支已提交但**未合并** (都在 ~/pov3d/dr1v90, 基于 5204170; 用户已同意"WiFi 测完一起合并", 现改为换完内核后做)
- `task/ides8-reset-timing` b70532b: IDES8 复位改 DHCE 停钟释放, 四套 recovery/removal 全清 (VALID −0.448 / STRESS −0.632 / adapter −1.596 → 全正); 新 tb_ides_rst 正反例。未上硅。
- `task/1.1.11a-ota-slots` 80e0aee/2d4dd60/06193f0: 远程升级 A/B 槽 (pov/ota/)、MANIFEST povota-1、PC 推送工具; 离线 76/76 过; 用户 8 项决定已落实。后续: pov_rxd 要重编 -static -no-pie (现 ET_DYN 会被打包拒), up.sh 要从卡上取回入库。
- `task/1.1.7-status` 675e77e: 远程状态回传 PSTS v1 (UDP 9510/9511, 1 Hz, 16 种告警), board/povstat + host/povstat_rx.py; 本机 67 项过。待定: 桥片(GW5A)误码回传通路 A 串口 / B 链路回传 / C JTAG。
合并做法: 先在 ~/pov_work 克隆里试合并 + 验证, 再快进 feature/lvds-b2b, 然后"保存"。

## D9 (电机转起来) 停在"通电低速"之前
板 DR1M90-02: bank A 已灌 helix3b (md5 edd12011…), 0x10=0x008E0004 (传感器模式, fake_en=0, pov_en=0), auto_en=0 屏黑。手转实测 rev_period 0x02E73EEF ≈ 0.97 s/圈 → 传感器有信号 (用户要确认每圈 1 脉冲)。
步骤单要点: 先布 180 s 死人开关再点亮; 0x10=0x008E0005; OE 从 8/4/2 逐档升到 184/92/46 (只对 helix 这类稀疏内容); 推荐 600–660 RPM; 先黑屏再停转。用户说转的不急。

## WiFi
- 办公网测不准 (两台 AP 之间绕, 丢包 33%)。改用 WSL 点对点台架 (第二块 MT7921AU usbipd 2-4, hostapd pov3d-p2p 192.168.77.1, 脚本 ~/pov_work/wifibw/rig_up.sh), 台架 PC 端封顶 ~145 Mbit/s。测速 agent 进行中, 数据在 ~/pov_work/wifibw/2026-10-12_p2p/。**换内核后这套台架失效** (自编 6.6.87.2 模块)。
- 需求结论见 [[project-target-35hz-budget-recheck]]: 目标板走"传体素表+板上切片"只需约 31–62 Mbit/s (病态 68–137), 不需要 200。

## 待用户决定 / 下一步
1. 换完内核: 合并三分支 → 保存; WiFi 结论落记忆。
2. 按 35 Hz (605 片 × 17.5 rps) 重核整条链预算 —— 桥片可能超速 (见 [[project-target-35hz-budget-recheck]])。
3. 下一个大功能候选: 板上切片 (PL 直供), D9 转起来, 主控↔桥片真机对接。

**Why:** 换 WSL 会断开所有会话和 agent, 需要无缝接续。
**How to apply:** 新会话先读本条; 汇报用大功能语言 ([[feedback-big-picture-first]]); POV 活派后台 agent ([[feedback-pov-in-subagent]])。
