---
name: zynq-jtag-flash-cold-board-sop
description: "鹿小班/Zynq JTAG 烧 bit 的快查 SOP — 冷板(拔SD)+冷板绝不写CTRL=0+按SN选器件+别churn; 2026-06-30 烧 ICND2047 棋盘格耗数小时血泪总结, 下次照这个几分钟搞定"
metadata: 
  node_type: memory
  type: feedback
  created_at: 2026-06-30
  updated_at: 2026-06-30
  originSessionId: fe6cecaa-6915-4b7c-91e6-2e0b62bc1aaa
---

鹿小班/Zynq 用 xsct JTAG 烧 bit, **照这个顺序几分钟搞定**, 别再像 2026-06-30 烧 ICND2047 棋盘格那样耗数小时. 背景细节见 [[project_pov3d_icnd2047_p3_bringup]] / [[feedback_jtag_dl_reflash_loop_dead]].

## ✅ SOP (烧前必做, 顺序别乱)
1. **拔掉 SD 卡** → 板子不自启动 → 上电后 **PL 空 / ARM idle = 冷板**. (SD 上的 BOOT.bin 自启会用 PCAP 配 PL + panel IP DMA 在飞, JTAG fpga 重配就冲突锁 DAP). 等价: 拨 SW3 到 JTAG/NAND ([[feedback_lxb_boot_mode_sw3]]), 但拔 SD 最省事.
2. **一次只插一块板 JTAG** (或脚本按 cable SN 过滤). 多板同接 fpga 会报 `Multiple FPGA devices`.
3. **PowerShell 清进程** (taskkill 常杀不动 rdi_xsct): `Get-Process rdi_xsct,hw_server | Stop-Process -Force`.
4. **冷循环板子** (断电~10s 再上电; SD 别插回). DAP 锁(0x30000021/0xF0000021)只有 POR 能清, `rst -dap` 没用.
5. **单 session 跑 `tools/_flash_icnd_log.tcl`** (每步 flush→flash_progress.txt, 挂住能看卡在哪步). 看到 STEP8 DONE + STATUS run位=1/frame_count涨 = 成.

## 🔴 5 条铁律 (违反就锁 DAP / 挂死, 这次全踩了)
1. **冷板绝不先写 CTRL=0 (`mwr 0x40020000 0`)**: PL 空时往空 AXI slave 写 → 锁 DAP 0xF0000021. **冷板直接 fpga**; 只有热板(PL已配置+DMA在跑)才先 CTRL=0 停 DMA drain 再 fpga.
2. **fpga -file 要按 SN 选 `xc7z020` 器件, 不是 APU**: `targets -filter "jtag_cable_name=~{*SN*} && name=~{*xc7z020*}"`. 选 APU 会 `Multiple devices`.
3. **`jtag_cable_name` 过滤只对 `jtag targets`(JTAG链)有效, 对 debug `targets`(A9/APU核)无效会报错中断脚本** → debug 靶子用简单 `name=~{*Cortex-A9*#0*}` + `catch` 包.
4. **fpga 前先 stop ARM 两核**; fpga 后选 A9 再 ps7_init (ps7_init 要核 stopped, 否则 "Cannot read memory if not stopped").
5. **绝不 churn**: 别先探测(probe)再断开重连; 别反复 taskkill hw_server; timeout 杀 xsct 留孤儿 rdi_xsct 会重启 hw_server 毒化后续每次. 一个 xsct session 从 connect 干到 exit.

## 诊断口诀 (挂了怎么看)
- `flash_progress.txt` 最后一行 = 卡点. STEP2/CTRL=0 卡 = 冷板误写空slave. STEP3/fpga 卡 = 热板没停DMA/PCAP冲突 或 marginal连接(降频5MHz+retry). STEP5/ps7_init `0xF0000021` = DAP锁(前面有空slave写或fpga冲突).
- `DAP status 0x30000021 / 0xF0000021` + A9核消失 = DAP sticky 锁 → **冷循环板子** (POR), 别再试.
- xsct stdout 有 buffer, **plog 写文件+flush** 才看得到进度.

## 复刷棋盘格的现成命令 (鹿小班 SN 210251A08870, ICND2047 屏)
`cd zynq_pov_icnd2047/tools && xsct _flash_icnd_log.tcl` (mode3棋盘格 CTRL=0x507 已硬编). bit=`02_hello_zynq.runs/impl_1/hello_zynq_wrapper.bit`(06-17验证版). 只 ps7_init+CTRL 不烧 bit = `_finish_icnd.tcl`.
