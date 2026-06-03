---
name: 每帧 memset 整 fb 边界出 cache-stale 红点
description: ARM 每帧 memset 2.76MB fb + 大块 DCacheFlush 导致 [958,1280) 黑边偶发 isolated red pixel, 改成只 blit 中心+per-row flush 解决
type: feedback
originSessionId: 25cdb314-8481-406a-9724-5d3798a00293
---
2026-05-13 anime HDMI 输出在 scale-blit 写区外 (dst_x=1211, row 354) 偶发 isolated 亮红 pixel.

**确诊不是数据/HLS bug**:
- anime_points.bin 30803 voxel, r>200&g/b<80 = 0 (无纯红 voxel)
- PC 模拟 HLS pov_project_batch 跑 64 angle, 任何 slot 任何 px 都没生成 bright-red (r>150&g,b<50) 像素
- 图像 cluster 分析: 3 个红点都在同一 dst_y=354, 最右那个 dst_x=1211 在 scale-blit 写区 [322, 958] **之外**

**根因**: ARM 主循环每帧
```c
memset((u8 *)fb_t, 0, HEIGHT * STRIDE);   // 2.76MB
... scale-blit 中心 [322, 958] ...
Xil_DCacheFlushRange(fb_t, HEIGHT * STRIDE);  // 2.76MB flush
```
2.76MB memset 走 cache, 大量 cache eviction + L2 PL310 + VDMA HP0 并发读 → 边界字节偶发未 flush 到 DDR. VDMA 读到 stale byte → HDMI 显示散点.

**修复**: 边界 [0, 322) + [958, 1280) 在 boot 一次性 memset 0, 主循环只 scale-blit 中心 + per-row flush 中心 [322, 958]:
```c
const u32 BLIT_BYTES_PER_ROW = S3D_VIEW_W * 3;  /* 1908 */
for (int dy = 0; dy < HEIGHT; dy++) {
    /* ... scale-blit dst_line[0..1907] ... */
    Xil_DCacheFlushRange((UINTPTR)dst_line, BLIT_BYTES_PER_ROW);
}
```

**Why:** 一次 2.76MB memset+flush 涉及 720 行 × 8 个 64B 缓存行 = 5760 cache line. ARM A9 + PL310 L2 controller + 并发 VDMA HP read 在大块同步操作下时序不稳定, 边界字节偶发 stale. per-row 小粒度 flush + 不动边界区域避免这种 race window.

**How to apply:**
1. 任何 ARM 写大块 fb/ring 给 PL/VDMA 消费时, 避免 2 MB+ 整块 memset+flush, 切成行/slot 粒度
2. 不变区域 (黑边/padding) 在 boot 一次性清, 之后不动
3. xsdb 验证: stop ARM, mrd 直接读 DDR (绕过 cache) 检查边界字节, 应为 0
4. 性能附带收益: 每帧省 2.76MB×2 fb memset ≈ 50ms (Cortex-A9 666MHz, memset throughput ~110 MB/s)
