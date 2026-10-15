---
name: project-handoff-2026-10-14
description: 10-14 傍晚交接 (主窗口 compact/换窗前): V0 83.8% 出口 5/8; 在跑 D7c 上板 + D15b 查 32 bit 硅上不一致; 待办与板子状态
metadata:
  type: project
---

**状态 (10-14 傍晚):** V0 83.8% / V1 60% / V2 53%; V0 出口 5/8 (①PL 切片 ②实时推流 ③几何镜像 ④启动 12.4 s/找板 ≤20.9 s ⑧内容+交互 ✅)。主线 dr1v90 feature/lvds-b2b = daef100 (含 D1–D6、D15 阶段 1、D18 开机默认 PL 切片+D13)。看板: zynq_pov/docs/progress/显性目的进度_交互.html (每次进展加 daily_log.csv 后 python3 mk_progress.py)。

**板子 DR1M90-02:** 开机默认 PL 切片 (pov/pls 位流 c0671058, povmem 64 MB, voxslice 0.5 --pl --stream-hold 300, 本地 geo_loop.pvs, 几何 0decad54); 卡上已装 D13 第二步 (uboot.env bootdelay 0 + 精简 uInitrd, 回退 d13_boot/boot_levers.sh uenv-off / initrd-restore); D7c 上板测试会装 autorun v2 + povnetd 1.1 + OTA。COM28 串口接着 (失联先插串口取现场, 能出不能进先试 dhcpcd -n)。回退: 板上 sh /mnt/mmcblk0p1/pov/d18_restore.sh 或 touch pov/noplslice。

**在跑:**
- ⑤ D7c (task/d7c-net-robust f8b6dbf): 主会话上板 `rotor_ops/verify.sh --board dr1m90-02 --only V3N --repeat 3` 再 `--only V2` (日志在 /tmp/claude-1000/.../scratchpad/v_d7c2_*.log, 新窗口 scratchpad 路径会变, 可直接重跑)。判据: V3N 连续 3 次 PASS + V2_no_bursts PASS ⇒ 合主线 (task/d7c-net-robust 已含 D7b 合并), 勾 ⑤。
- ⑦ D15b (task/d15b-color-p2 58bfebb, agent 在查): 上板速率全达标, 但 **32 bit PL 输出 ≠ CPU (4/4, 对拍 0/6), 16 bit 一致, 仿真一致** ⇒ 硅上差异待查; 修好后主会话上板 `slice/color/verify.sh --board dr1m90-02` (新克隆要先补 bench/deps/aarch64musl)。
**下一步:** ⑤⑦ 过 → ⑥ 8 h 无人值守长跑过夜 (KR7.2) → V0 完成。之后 V1 准备: 纯切片/D3 上行档按新切片核重综合、D8 联合仿真、D10 整合位流、D11 C1 台架 (用户接线 + DR1M90-01 COM24)、D16 网格 4×4 分块 (待用户定)、QoS 寄存器写 (待批)。
**规则提醒:** 子 agent ≤5, 按难度 Opus/Sonnet/Haiku, 复验过即 TaskStop, 安静汇报 (feedback_dispatch_token_playbook)。

## 10-14 晚更新 (19:30)
- ⑤ D7 合主线 dee9be6 (V3N 11/11 + V2 12/12); ⑦ D15 合主线 3a41eb7 (上板全过; 32 bit 只到 10.83 rps); 回归修基准 0808333 全过。V0 出口 7/8。
- ⑥ 8 h 长跑 19:20 开跑, 预计 03:20 结束: 克隆 ~/soak_v0 (26e69ec), 结果 ~/soak_runs/v0_8h_1014_1919/ (run.log, report.md); soak.sh PID 27278 (setsid, 关窗不死);
  判读 `bash soak8h/soak.sh --judge <目录>`; 中断时板子自己回开机默认。过了 ⇒ 勾 ⑥ (KR7.2=8), V0 完成。注意 S8: 试跑 15 min voxslice RSS 24→34 MB, 看 8 h 是否涨。
- 用户 10-14 授权: D15b 过了直接合主线并开长跑。V1 台架硬件清单已给用户 (等用户接线后告诉)。
- 用户 10-14 晚: 长跑若没过, 不用等用户, 直接查根因并修 (照闭环: 修好→新克隆复验→合主线→重跑长跑)。
- 用户 10-14 晚批准: QoS 寄存器 0xF8440804 可写 + D16 网格 4×4 分块开做。长跑完后在 2047 上做对照 (同负载 写前/写后迟到率 + 32 bit 满速完成率); D16 agent 离线做, 好了上板同口径对照。
- 10-14 晚: D16b agent 已停 (额度, 推到下周); QoS 对照照做 (主会话, board_qos.sh)。
- 10-14 晚: D16b 阶段 1 (只量化, 做完停) 在跑; QoS 对照已排在长跑后自动跑 (~/qos_runs/chain.sh, 长跑没过就不跑)。额度 >70% 先保存再停。
- 10-14 晚用户: "把 D16 做完" —— D16b 阶段 2 (Sonnet) 在做; 完成后主会话新克隆复验 → 板子空了 (长跑+QoS 后) 上板 A/B (现布局 vs tile 4, D16 --attr A0/A6) → 过了合主线, 不用再问。
- 10-14 23:45 重开长跑: 第一轮第 6 段企业 WiFi 踢线 ~5 s, voxlive 不重连直接退出 -> 修 voxlive 断线自动重连 (主线 5cbe79f, 回归全过), 判读 S5/S6 允许重连。第一轮前 4 h 板端: 停摆 0 / 死 0 / RSS 稳 34.4 MB。
  新一轮: ~/soak_runs/v0_8h_1014_2345 (PID 见 ~/soak_runs/last_8h.pid), 约 07:45 结束; 接力 ~/qos_runs/chain_all.sh: 判读 PASS -> QoS 对照 (attr --with-qos + color@QoS 0x0F) -> D16b tile A/B (~/rv_d16b, 离线复验 5 套全过)。
- 10-15 07:50 V0 出口 8/8: 8 h 长跑 9/9 (报告 zynq_pov/docs/progress/soak_v0/); QoS 对照 + D16b A/B 在跑 (~/qos_runs/chain_rest.sh)。
- 10-15 08:35 QoS 带载迟到 4.1%→0 (决定性); D16b 分块无收益 (漂移内), 不合主线。待用户定: QoS 0x0F 是否做进开机默认。
