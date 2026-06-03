---
name: Zynq HDMI 输出反复 rst -processor 后变黑, 需 power-cycle
description: 多次 xsdb rst -processor reload 后 PL VDMA/VTC/rgb2dvi 进入坏状态, HDMI 输出永远黑屏即使 ARM 正确写 fb_A/fb_B
type: feedback
originSessionId: 25cdb314-8481-406a-9724-5d3798a00293
---
Zynq-7020 + Digilent 风格 HDMI BD (VTC + AXI VDMA + rgb2dvi) 在 xsdb `rst -processor` 反复 reload ELF 几次之后, HDMI 输出会停止. 症状:
- ffmpeg dshow 抓 USB3 HDMI 采集卡 N 帧得到完全相同的 7403 byte 黑图 (HDMI 信号丢失)
- xsdb mrd 0x10000000 (fb_A) 和 0x14000000 (fb_B) 显示 ARM 写入的内容确实在 DDR (rainbow gradient bytes 正确)
- VDMA park ptr 寄存器 (0x43c10028) 在 PS 侧无法访问, xsdb 报 "PL AXI slave ports access is not allowed"
- 多次 ARM 端 write fb 不能恢复, 只有 fb_B 总是被写 (因为 vdma_current_read_idx 永远返回 0), 但即使 fb_A 也写满数据 HDMI 还是黑

**Why:** 2026-05-12 调试 single-3D 显示时发现: 单一 `rst -processor` 不会 reset PL (VDMA/VTC/rgb2dvi 状态留存). 多次 ELF reload 后 PL 模块某处 (可能 VTC generator 或 rgb2dvi SerDes lock) 卡死.

**症状判别**:
- 之前能看到 HDMI 输出, 经过几次 reload 突然全黑
- xsdb 验证 fb DDR 有内容 (写入成功) 但 HDMI 采集端只看到黑帧
- 同 BD 的 SDIO 也可能同时卡 (见 `feedback_zynq_sdhci_stuck_after_rst.md`)

**唯一办法: 物理 power-cycle Zynq 板** (USB power 拔插即可, JTAG 线不动). cold boot 通过 `rst -system + ps7_init + dow ELF` 把 PL VTC/VDMA 状态走完整初始化.

**How to apply**: 调试 ARM 端 fb 内容时如果 HDMI 突然变黑且确认 fb DDR 有数据, 不要继续怀疑 ARM 代码 — 先 power-cycle Zynq. 类似 SDHCI 的 reset state 问题. PL 高频 reload 场景考虑添加 `bd_rst rst` 重置 PL 或干脆走 cold boot.
