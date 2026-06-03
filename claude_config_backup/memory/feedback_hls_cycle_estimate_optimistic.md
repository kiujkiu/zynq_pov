---
name: HLS Latency (cycles) 估算对 m_axi 乐观 ~14×
description: 写 DDR 的 HLS IP 实际 wall time 远超 HLS 报告，不能信 estimate
type: feedback
originSessionId: bafc105a-a8db-471f-ae33-42571927b4da
---
**Why：** HLS csynth 报告里的 "Latency (cycles)" 假设 AXI 1 beat/cycle。但真实 Zynq HP port 路径（IP → smartconnect → HP → DDR controller → DDR3）每 beat 实测 ~10 cycle（还跟 burst 长度、DDR 刷新、VDMA 争带宽有关）。

**2026-04-23 实测**（pov_project IP @150MHz，每点写 12 byte to DDR via HP1）：
- HLS 估算：3.78k cycle = 25 μs
- 实测 wall：355 μs
- 差距：**14× 偏乐观**

**How to apply：**
- 算 HLS IP 时间预算，把 HLS cycle estimate × 8-15 当真实时间
- 想要接近估算值的方法：
  - 写入大 burst（max_write_burst_length=256），但实际效果有限
  - m_axi 数据宽度开到 64 bit 以上（HLS 默认 32 或看 C++ 类型）
  - 避开 VDMA 争 DDR 带宽（用不同 HP 端口）
- 真要逼近理论：做 batch IP（内部循环 N slice），摊薄 per-slice 启动开销
