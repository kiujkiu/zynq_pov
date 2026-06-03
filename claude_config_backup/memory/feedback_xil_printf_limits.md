---
name: Zynq BSP xil_printf 不支持 %lx 等格式
description: Xilinx 的 xil_printf 是简化 printf，不认 long 修饰符；打出来是栈垃圾
type: feedback
originSessionId: bafc105a-a8db-471f-ae33-42571927b4da
---
**现象**：`xil_printf("0x%08lx", (unsigned long)addr)` 在 Zynq 标准 BSP 下打出 `0x13B11000000`（13 位 hex）或其他栈垃圾。

**Why：** xil_printf 极简实现，只支持 `%d`, `%u`, `%x`, `%s`, `%c`。遇到 `%l` 或 `%08` 可能消费参数错位或读栈垃圾。

**How to apply：**
- 永远用 `xil_printf("0x%x", (unsigned)val)` 打 32-bit 值
- 打 64-bit ticks 分两半：`("%08x%08x", (u32)(v>>32), (u32)v)`
- 如果非要 printf 格式化，用 stdio.h 的 printf（有点 fat）
