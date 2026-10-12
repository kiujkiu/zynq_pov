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
- 上板由主会话做, 先问用户: 假转 (fake_en) 静止上屏, 不需电机; 先备份 bank A 的 helix 帧; 收尾写 0x80000010=0x008E0004; 回退 = pov_rxd。

**Why:** 用 CPU 先验证整条板上切片链路, PL 切片器完成后替换 CPU 这一段。
**How to apply:** 接手先看 `git -C /mnt/d/claude_workspace/pov3d/dr1v90 log -3 task/slice-3bit-cpu`; 与 [[project-pl-slice-kickoff-1012]] 同一大功能。
