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

**10-12 决定:** 转轴列中心先用 **95.5** (u = p − 95.5, 与现役 PC 渲染器一致), 等实物转起来再校准; 只改 LUT 不改 RTL。生产表已出: golden 6848846 slice/lut/lut_{A,B}.bin CRC32 **a28f6013 / 36da5ca7** (浮点 gas 几何, 越界输出 0, 对现役 render_slice 有效列 0 不符); `gen_lut.py --center` 校准重出。rtl_full/lut_*.bin (c5c754dc/3f050137) 是 96 中心测试表, 不上板; 合并时 voxrxd 的 CRC/默认路径要改指 slice/lut/。

**10-12 进度:** golden 完成 (6848846, 规格 slice/SPEC.md, 与 pov_slice_v2.cpp / render_slice 逐位一致); sw 完成 (42329a8, voxrxd 新程序与 pov_rxd 二选一, 离线 215 项过, 增量写 16–22 MB/s @15 fps, pov_rxd 已 -static -no-pie)。两分支已推 origin + yjhh。rtl / integ 仍在跑。
- 10-12 rtl 完成 (5d3cd22): 仿真全对, 一片 93.5 µs/110.19 (15%); 150 MHz setup 收敛 (hold −0.19 残留, 疑工具层), 200 MHz hclk 收住但 oclk 191.7/hold −0.82; 建议生产 hclk 150; eram 136/280 (RING 384=2 片/面, 并存 2047 时只能 192 仅作功能验证, 正式位流去掉 2047 fb+lz4)。
- 10-12 integ 完成 (fae9b22): 旧模式 bin 与生产逐位同 (2ac42cbb); 上板推荐 pov_m90sp_h150.bin (pls + hclk150 + RING192, eram 208/280); RING384 并存放不下 ⇒ 30 Hz 正式位流去掉 2047+PL lz4。修了 PLL 输出没过 DR1_LOGIC_BUFG (07_eta 量具同病)。**TD 能在 \\\\wsl.localhost\\... 路径下综合** ⇒ 重 IO 构建放 WSL ext4 可躲 D 盘 EIO (agent 克隆 ~/pov_work/slice_integ)。bin 副本 D:\\claude_workspace\\pov3d\\_work\\slice_integ_out\\。下一步: 上行格式器 + 纯切片位流。
