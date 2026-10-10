---
name: project_remote_upgrade_x4
description: 2026-10-10 用户定远程升级方案 (X4): 所有可升级件集中在 DR1M90 SD 卡 A/B 槽位, GW5A 每次上电由 DR1 经 JTAG 灌 SRAM 不写 Flash, 热切换+自检窗口+自动回滚+开机 trial 回退; 内核第一期不做; ≈2.5 天排在 D18–D19 后
metadata:
  type: project
---

用户 10-10 提「远程升级的问题」, 我给出按升级对象分的表并倾向"GW5A 不存 Flash、每次上电由 DR1 灌"⇒ 用户:「按你的倾向定整体方案, 排进计划」。
正文: `zynq_pov/docs/软件计划_DR1M90对齐与验证板固件_2026-10-09.md` §10; 任务表 1.1.11 (a–d)。

- 原则: 远程升级 = 经 WiFi 换 SD 卡上的一组文件 (板端程序 / DR1 PL 位流 / GW5A 位流含 2260 寄存器表)。
- GW5A Flash 只放出厂保底位流, **永不远程写**; 每次上电 DR1 经 JTAG 覆盖 (依赖任务 1.1.8 bridge_load aarch64)。
- `/pov/slotA|slotB` + MANIFEST(sha256) + `/pov/current` + `/pov/trial`; 推送只写非当前槽; 热切换后自检 (GP0 MAGIC、link_up、好帧计数、PC 心跳) 通过才 commit, 否则自动回旧槽; 开机见 trial 未清 ⇒ 起旧槽 ⇒ 中途掉电也不变砖。
- 转着也能升级 (屏黑 1~2 s)。内核/启动镜像第一期不做 (要现场), 第二期 u-boot bootcount A/B; 包签名第二期。
- 计划总工期 ≈25.5 天 (20 + X1/X2 + X4)。

相关: [[project_pov3d_sw_plan_20d_2026_10_09]] [[project_validation_board_task_tree]] [[project_dr1m90_jtag_port_checklist]]
