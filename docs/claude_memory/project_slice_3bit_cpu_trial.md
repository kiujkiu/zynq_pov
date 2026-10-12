---
name: project-slice-3bit-cpu-trial
description: 2026-10-12 在现有 3-bit 试验屏 (ICND2047 160×180) 上先用 A35 CPU 板上切片跑通"WiFi 传体素表→板上切片→上屏"; 切片线程绑 CPU1; 分支 task/slice-3bit-cpu
metadata:
  type: project
---

用户 10-12 晚: "我们现在这个3bit屏幕试一下"、"切片线程绑到 CPU1, 先跑起来看看"。PL 切片器 (目标屏 192×216 RGB565) 未完成, 所以试验屏先在 CPU 切: voxrxd 收 VOXTAB → 散写网格 → LUT 逐片取列 → 量化 3-bit → 打包进现役 pov_rxd 帧 bank → 翻页。双面各 142 槽。

- 开发 agent 在 /mnt/d/claude_workspace/pov3d/_work/slice_3bit, 分支 task/slice-3bit-cpu (基于 task/pl-slice-sw), 交付离线对拍 (与 render_slice+pack_obs 逐字节) + 上板清单; 不碰板子。
- 要求: 切片线程绑 CPU1, 收包/解压 CPU0 (参数可改); 切片帧率 ≤ 翻页率 (~15 fps), 网格不变不重切; 每秒打印线程 CPU 占用与切片耗时。先求能跑, 优化后放。
- 估算 (未实测): 一帧 ~820 万像素, A35 单核 20–40 ms, 10 fps 约占一核 20–40%。
- 上板由主会话做 (**10-12 用户已授权: "agent 做完直接上板试"**, 不必再问): 假转 (fake_en) 静止上屏, 不需电机; 先备份 bank A 的 helix 帧; 收尾写 0x80000010=0x008E0004; 回退 = pov_rxd。

**Why:** 用 CPU 先验证整条板上切片链路, PL 切片器完成后替换 CPU 这一段。
**How to apply:** 接手先看 `git -C /mnt/d/claude_workspace/pov3d/dr1v90 log -3 task/slice-3bit-cpu`; 与 [[project-pl-slice-kickoff-1012]] 同一大功能。

**10-12 18:3x 上板实测 (屏黑, 假转 16.15 rps, OE 8/4/2 未点亮):** 链路跑通, 0 NAK / 0 forced。bonsai@15 推: 实际 rx/切/翻页 12–13 fps, **切片 78–82 ms/帧 (估算 30–50 的 2 倍), 切片线程 CPU1 93–95% 打满 = 瓶颈**; rx 线程 CPU0 24–26% (scat 13 ms, dec 2.5 ms); 整板 70% 忙。static: 同网格不重切 ✓, 切片 0%, 但 rx 线程仍 16% (每帧整表重收重散写比对) ⇒ PC 端静止时应停发。离线对拍 96 帧逐字节一致 (task/slice-3bit-cpu 887c831)。下一步: 用户在场时 `m90_vs.sh light 60` 目视; 优化切片 (NEON / 翻页线程挪 CPU0)。
- 10-12 18:4x 派优化 agent (task/slice-3bit-cpu 续): 目标 bonsai 稳 15 fps (切片 ≤55 ms), 翻页线程挪 CPU0 / NEON / 两核分担 / PC 静止不重发; 允许它上板测性能但屏必须黑。
- **10-12 20:4x 光电开关模式上屏 ✅**: voxslice 0.2 + `m90_vs.sh start` 后写 0x10=0x008E0005 (传感器) + light; 用户确认屏上看到机器人。手转测到 rev_period 0x047A5D93 ≈1.50 s/圈 (aclk 50M); 静止时引擎停在某片 (slice_idx 不动, 翻页窗等不到 → voxslice 每 2 s 强制翻页, 正常)。0.2 版 (dddf19a, 紧凑列存+双核分片+翻页挪 CPU0) bonsai 稳 15 fps 切片 34–36 ms (0.1: 79–82 ms)。教训: 优化 agent 起的实例进程名是 vs_base, 占 9500 导致主会话的 voxslice bind 失败退出; 上板前查 9500 占用 (netstat) 而非按名字 grep。
- **10-12 21:2x D9 首次转起来看立体像 ✅**: 电机 ~640–654 RPM (光电开关每圈 1 脉冲, 板测与实际一致), voxslice 0.2 传感器模式。用户: 机器人可见; **走路骨骼动画 "效果很好, 颜色也不错"**, 亮度最终定 OE 32/16/8 (8/4/2 太暗)。动画来源: host/anim_vox.py (glb_anim.AnimSampler → 160 网格体素表, 需 ~/.venv_pov 含 pygltflib; walking 1.07 s/11 帧@10fps)。可选动画: Groot 跳舞、Dino 4 段、Robot。用户要求"固化到启动" → 派 agent 做 task/m90-show: 卡上本地循环播放 + 转速门控 (400–900 RPM 且在转才亮, 否则立刻黑) + pov/noshow 开关; 安装/重启测试由主会话在用户开电机时做。教训: kill 推流用 pgrep -f "^python3 .*voxpush", 别用 grep 命令行 (会杀到自己的 shell, exit 144)。
- 10-12 用户定: 开机演示默认 **walking 走路** (先定 Groot 后改), OE 32/16/8; groot 可选。卡上 pov/vs/show.conf 已写 CONTENT=walking.pvs。
- **10-12 22:0x 开机演示手动验证通过** (task/m90-show a232359, voxslice 0.3 --local/--sensor + spin_gate.sh): 卡上 groot.pvs 本地播放有画面; 停转 ~0.4 s 自动黑, 再转自动亮。判转依据 0x80000010 bit31 locked (>2 倍周期无脉冲清 0; 假转下强制 1, 须同时看 0x24 pov_en=1 fake_en=0); RPM=3e9/rev_period。卡上: pov/vs/ 0.3 全套 + show.conf 可选; 备份 autorun.sh.bak-show (c918bf9f) / vs/voxslice_aarch64.v02 (0.2, 9b69ccbe)。**autorun.sh 尚未改、未重启验证**。用户新需求: 停转时低亮 (OE 8/4/2) 显示 0° 片, 已派回开机演示 agent。
- 教训: `m90_vs.sh stop` 用 ps|grep voxslice 杀进程, 若 ssh 命令行里含 voxslice 字样会把自己的 shell 杀掉 ⇒ stop 单独一条 ssh 命令执行, 后续命令另起。
- ✅ **10-12 上电自动显示 重启验证通过**: 卡上 autorun.sh 换成 m90-show 版 (cc140579, 加 3 行调 vs/show_boot.sh; pov/noshow 跳过), 重启后 uptime 26 s 门控 LIGHT rpm=656 播 walking (show.conf CONTENT=walking.pvs)。回退 autorun.sh.bak-show。停转低亮 0° 片版已做完离线验证 (task/m90-show 7a8c402: voxslice --idle-ctl 空闲帧放 bank 间隙 +0xA00000 并拨 pov_en 重取; spin_gate v2 三状态 SPIN/IDLE/FAULT), 待上板 (VOXSLICE_M90.md §8.5)。
- ✅ **10-12 22:3x 停转低亮 0° 片上板通过并固化**: 卡上 pov/vs/ 换 0.3+idle 版 (voxslice cbb82eaa / show_boot fa983fb2 / spin_gate 56ce1c09; v1 备份 *.v1), autorun 不变即生效。用户确认: 停转见低亮静止截面, 起转恢复体显示; 4 次起停 SPIN/IDLE 成对无 FAULT。task/m90-show 合入主线 feature/lvds-b2b = 3bc5736。
