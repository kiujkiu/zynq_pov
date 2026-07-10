---
name: 反复烧 bit + kill hw_server 让 JTAG 链断, 必须用户冷循环板子救
description: 一个 session 内连续 fpga -file 5+ 次或 ps7_init 反复跑会让 JTAG DAP-AHB sticky error 锁死, rst -dap / kill hw_server 都救不回, 必须物理板子断电 5-10s
type: feedback
created_at: 2026-06-10 02:26 CST
updated_at: 2026-06-23 CST
originSessionId: 9191f0e2-0bfd-4c68-bb07-c85f057b8792
---
## 根因理解 (2026-06-11 补) + 最大预防措施

**机制**: `fpga -file` 重烧 PL 瞬间, 如果 ARM 正通过 AXI 访问 PL 地址 (如 HDMI→LED 桥接每帧写 0x40020000 BRAM), PL slave 消失 → 那笔 AXI 事务永远无响应 → **总线挂死**. DAP 记 sticky error (0x30000021). 软件复位只重置调试链路, 卡死事务在 SoC 总线层, 只有 POR 能清. `rst -processor` 更糟 (PL 还跑/VDMA 不一致, ARM 重启碰半死管线直接 hang — 2026-06-11 实测翻车).

**最大预防 (已固化进 dl_minimal.tcl 2026-06-11)**: **先 stop ARM 两核, 再 fpga -file**. ARM 跑着桥接 (高频写 PL) 时烧 bit = 最高危操作.

**v6+ 时代新增根因 (2026-06-12)**: panel IP 自己是 **HP2 总线 master** (DMA 持续读 DDR), 烧 bit 瞬间 PL 在飞的 AXI 读事务被重配置掐死 → 同样 DAP sticky (0xF0000021). **预防已固化**: _dl_bit_only.tcl / dl_minimal.tcl 在 fpga -file 前先 `mwr 0x40020000 0` (CTRL=0 → DMA 走 D_DRAIN 干净收尾) + 200ms. 凡 DMA 在跑时要烧写, 必须先停 CTRL. **但反坑 (2026-06-15)**: 冷启动后 PL 未配置, `mwr 0x40020000` 往空 AXI slave 写直接挂总线锁 DAP! 守卫不能放进 _dl_bit_only/dl_minimal (冷启动第一次烧用的). 正解: 这俩脚本不碰 AXI; 重烧 LIVE 板子前手动先跑独立 `tools/_stop_dma.tcl` 停 DMA, 再 dl. 即: 第一次冷烧 = 直接 fpga; 热重烧 = 先 _stop_dma 再 fpga.

**烧录器 USB 拔插也能救部分情况** (2026-06-11 两次实测): DAP error 时拔插 JTAG-SMT2 USB → targets 恢复, 不一定要板子断电. 先试拔插, 不行再断电.

## 🔴 2026-06-22 复现确认: 纯只读探测 + 重连 churn 也能锁 (无 fpga -file)
板1 跑 globe: 先 `_probe_state.tcl`(connect→读寄存器→disconnect) 成功 → 接着 `_run_b1_globe_live.tcl`(再 connect) targets none → taskkill hw_server → 再跑 → **DAP 0x30000021 AHB AP transaction error**, APU 靶子消失. **全程没烧 bit, 纯 connect/disconnect/taskkill churn 就锁了** (印证 line 51「query 脚本少跑」+ line 44「跨多次 connect/disconnect」). 教训: **要碰板子就一个 xsct session 干完所有事 (connect→灌→显示→exit), 绝不先探测再断开重连**. 救法照旧: 用户物理冷循环 → 然后**单 session 冷启脚本** `_run_globe_cold.tcl` 一次跑通 (fpga→ps7_init→灌→显示, 0 churn) 干净无锁. 见 [[project_pov3d_two_board_snapshot_2026-06-22]] 部署流程.

## 现象

xsdb 报这些错就是 JTAG 链状态错乱:
```
DAP (AHB AP transaction error, DAP status 0x30000021)
DAP (AHB AP transaction error, DAP status 0xF0000021)
no targets found with "APU*". available targets: (empty)
Memory write error at 0x40020000. AP transaction error
```

## 救不回的尝试

- `taskkill /F /IM hw_server.exe` 然后重连 → 还是 DAP error
- `rst -dap` → 救不了 sticky error  
- `disconnect; connect` → 还是 enumerate 空
- 让 hw_server 闲置等几分钟 → 没用

## 唯一救法

**板子物理断电 5-10s 再上电**. 如果 USB JTAG 也插 PC, 同时拔 USB JTAG 也好 (让 Windows 重 enumerate FT2232H). 不需要重启 PC.

## 触发条件

一个 session 内:
- 连续 `fpga -file` 5+ 次, 或
- `ps7_init` 跟 `mwr -force` 跨多次 connect/disconnect 循环, 或
- `taskkill hw_server.exe` 多次反复

## How to apply

1. **不要写成无限重试循环** — 反正不会自愈, 4 次 fail 立刻 ask user 冷循环, 别浪费时间
2. **合并 dl + fill 到单一 tcl** 减少 fpga -file + connect 次数 (但是 ps7_init 在合并脚本里如果 hw_server 之前没 clean shutdown 也会 fail, 间歇性)
3. **跑测试期间避免多余 connect** — 比如 `_probe_targets.tcl` `_status_only.tcl` 这种 query 脚本能少跑就少跑
4. **如果 fpga -file 成功 + bit downloaded 但后续 mwr -force fail**, 那是 v34i 时碰到的 `BD 41-1356` panel_seq 没 assign 进 PS7 地址空间, 不是 JTAG 问题. 检查 build log

## 实测教训 (2026-06-10 凌晨)

一晚上踩坑序列:
- 22:10 - 01:50 期间 4 次 Vivado rebuild + 8+ 次 xsdb 烧录
- 中间 user 给板子冷循环 3 次救 JTAG
- 每次冷循环救活的 JTAG 还能撑 4-5 次烧录然后再次卡死

**结论**: 这是 hw_server / Digilent FT2232H driver / Xilinx DAP firmware 的 cache 状态问题, 不是软件能完全规避.
