---
name: ADR — 平台锁定 DR1V90 (RISC-V), 不上 DR1M90 (ARM)
description: 2026-08-06 定案; 理由是 DR1M90 贵很多; 已知代价是单核慢 2.15×, 需靠 PL 解码补回来
type: project
---

**2026-08-06 决定: 走 DR1V90GEG484 (RISC-V 单核 800 MHz)，不换 DR1M90 (ARM A35 双核)。
理由: DR1M90 贵很多。**

## 这是在知道代价的前提下做的决定, 不是没测就选

[[project_dr1_riscv_verdict]] 已实测: DR1V90 单核整帧 **115.5 ms vs A9 53.7 ms**，
而翻页天花板(转速 16.1 fps)给的预算是**一圈 62 ms** ⇒ **超预算 86%，CPU 变瓶颈**。
⇒ **选了这条路就等于承诺要把解码搬进 PL**，不是"先用着看看"。

## 因此 PL 解码从"可选优化"升级为"必做项"

差 1.86×，补法（[[project_dr1_riscv_verdict]] 有完整清单）:
- **PL 做 lz4 解码** —— 大头(80.8 ms)。lz4 无 Huffman，约 200-300 行 RTL、1-2 周，
  比原评估 scope 的 DEFLATE inflate(500-800 行、2-4 周)便宜得多。
- **PL330 DMA 替 CPU memcpy** —— 实板 dtb 有 `arm,pl330`，省 34.5 ms。

## 不要再重复评估过的选项

- ❌ 指望 DR1M90 的"双核"救场 —— [[feedback_lz4_onboard_reality_check]] 实测双核并行只值 1.06×，
  A35 的价值在单核更强，不在核数。（何况已因价格排除。）
- ❌ 指望换平台解决现有瓶颈 —— [[reference_port_to_other_fpga_deps]] 第 5 条: 逐帧 ACK 推流
  和转速/刷新率不匹配，换 FPGA 一个都解决不了。换安路的正当理由只有供货/成本/国产化。

## 验证顺序（2026-08-06 起）

工具链已全通（[[reference_anlogic_td_toolchain_setup]]，license 到 2027-03-31）。
1. RTL 移植进 TD: **14 处 `ODDR SAME_EDGE` → `DR1_LOGIC_ODDR`** + 约束格式转换 + bank 13→11
2. 综合/时序收敛 + DCLK 眼图（🔴 **眼图需要下载器，目前还没有**，见下）
3. PL lz4 解码器
⚠ **安路 JTAG 下载器(AL-Link FT)至今没到手** —— 没有它 bit 下不进板子。
（我曾把一个 FT2232 误判成下载器，实测那是用户 6 月就有的旧设备，见 [[reference_anlogic_td_toolchain_setup]]。）
