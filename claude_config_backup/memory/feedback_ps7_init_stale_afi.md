---
name: ps7-init-stale-afi-word-swap
description: "PS 配置改了 (开 HP0/改位宽) 必须从新 XSA 重抽 ps7_init.tcl, 旧 init 缺 AFI 写 → HP0 32-bit 读数据 64-bit 字对互换"
metadata: 
  node_type: memory
  type: feedback
  created_at: 2026-07-08 23:00 CST
  originSessionId: cf0c2a7b-313b-434d-ad2d-a32b56239d06
---

2026-07-08 v5 POV anime "每个部分显示 2 次" 根因: `tools/_panel_pov.tcl` source 的 `ps7/ps7_init.tcl` 是 v4 时代旧文件, 而 v5 新开了 `PCW_S_AXI_HP0_DATA_WIDTH=32`。HP0 内部 AFI FIFO 恒 64-bit, 32-bit 模式必须由 ps7_init 写 **AFI_RDCHAN_CTRL(0xF8008000) / AFI_WRCHAN_CTRL(0xF8008014)** 切 32-bit 打包; 旧 init 没这两笔 → PL 32-bit beat 落错 64-bit 半边 → **DDR 读回相邻 32-bit 字两两互换** (fb[2m]↔fb[2m+1]), 屏上表现为相邻 30px 芯片对内容交换 = "成对重复"。

**Why**: ps7_init.tcl 不在 bit 里, 是 JTAG 流程单独 source 的; build 更新了 XSA 但没人把 XSA 里的新 ps7_init 抽出来替换, 老 init 静默配错 PS。与 [[feedback_refresh_bit_stale_xsa]] 同族: 工具链两个半自动产物 (bit/init) 各有 stale 通道。

**How to apply**:
1. 任何 PS7 配置变更 (开关 HP/ACP/位宽/时钟) 后: `python3 -c "import zipfile; z=zipfile.ZipFile('<xsa>'); open('ps7/ps7_init.tcl','wb').write(z.read('ps7_init.tcl'))"` 重抽 (WSL 无 unzip)。
2. 症状识别: HP 口 DMA 数据 64-bit 字对互换 (奇偶字交换、图像 30px 对带交换/重复) → 先查 ps7_init 时间戳早于 XSA。
3. 排查方法论 (今晚全程): 阶梯诊断图案 (word w @ rows 9w..9w+8, 奇偶字点不同半字) 一张照片分辨 word/半字/行/lane 级变形; AXI 直写 fb 做对照实验切开写入/读出; 软件预交换 bin 零成本验证交换理论。诊断工具留存: tools/diag_slice.bin + _pov_diag.tcl (fetch 路径) / _pov_diag_axi.tcl (AXI 对照) / diag_slice_sw.bin (对交换版)。
4. ⚠ 诊断图案别点 bit15/31 (dummy OUT15 通道 G/B 链上真会亮出青色杠, 会当红鲱鱼)。
