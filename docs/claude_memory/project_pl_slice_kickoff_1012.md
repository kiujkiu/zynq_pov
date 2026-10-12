---
name: project-pl-slice-kickoff-1012
description: 2026-10-12 板上切片 (PL 直供) 大功能开工, 4 个并行 agent 各自分支 task/pl-slice-{golden,rtl,sw,integ}, 按 30 Hz
metadata:
  type: project
---

2026-10-12 17:2x 用户选"下一个大功能 = 板上切片", 要求多 agent 并行。PC 只传体素表 → 板上 CPU 散写 DDR 网格 → PL 按角度 LUT 取列出片。目标 30 Hz (见 [[project-target-35hz-budget-recheck]])。

| 分支 (D 盘 dr1v90) | 内容 | 克隆 |
|---|---|---|
| task/pl-slice-golden | 黄金模型 + slice/SPEC.md + 测试向量, 须与现有 PC 切片逐位一致; 规格以它为准 | _work/slice_golden |
| task/pl-slice-rtl | PL 切片器 RTL (双 HP 64 bit, LUT 预取, 片间 FIFO, GP0 寄存器), 仿真+最小 TD 综合 | _work/slice_rtl |
| task/pl-slice-sw | PC 体素表编码推流 + 板端解压散写 (qemu 离线对拍) + pov_rxd 改 -static -no-pie | _work/slice_sw |
| task/pl-slice-integ | td_pov 集成方案 slice/INTEGRATION.md + 骨架综合 + HP1 换 DDRC 端口实验步骤 + 上板清单 | _work/slice_integ |

暂定接口: 网格 (mx,y,mz) 地址 = base + ((mz*192+mx)*216+y)*2, 列 432 B 连续, 双缓冲; LUT 605×192 项 32 bit。TD 构建用 flock ~/.td_build.lock。都不碰板子, 不推 GitHub; 主会话收齐后合并 + 保存。

**How to apply:** 新会话接手时先 `git -C /mnt/d/claude_workspace/pov3d/dr1v90 branch -v | grep pl-slice` 看进度; 规格冲突以 golden 分支 slice/SPEC.md 为准。
