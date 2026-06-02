---
name: HLS pov_project_batch 不清空 slot 导致 ring buffer 残影累积
description: HLS 只写 anime 点投影位置的像素, ARM 每帧 phase 变化 → slot N 累积多个 angle 的合成, HDMI 出现重影
type: feedback
originSessionId: 25cdb314-8481-406a-9724-5d3798a00293
---
2026-05-13 anime 30K 渲染通了之后, HDMI 上看 anime 角色像有 3-4 层重叠的影像 (上下左右镜像 stacking).

**根因**: `hls_proj/pov_project.cpp` 里 `pov_project_batch` 内层循环只对**有 anime 点投影到的 (sx, sy)** 写 GBR 3 字节:
```c
for (int i = 0; i < num_points; i++) {
    if (in_slab && sx >= 0 && sx < SLICE_W && sy >= 0 && sy < SLICE_H) {
        slot[off + 0] = p.g; slot[off + 1] = p.b; slot[off + 2] = p.r;
    }
}
```
**没有把 slot 清零再写**. ring buffer slot N 这一帧渲染 angle X, 下一帧 phase++ 渲染 angle X+1, **被覆盖的像素更新, 没被新 angle 投影到的像素留旧 angle 数据**. 多 frame 累积 = N 个 angle 的 union, 看着像 3-4 个角色叠在一起.

**修复 (ARM 端, 不动 HLS)**: 在 `pov_render_frame_to_ring` 里 fire AP_CTRL 之前:
```c
memset((void *)RING_BUFFER_ADDR, 0, N_SLOTS * SLOT_BYTES);
Xil_DCacheFlushRange(RING_BUFFER_ADDR, N_SLOTS * SLOT_BYTES);
```
N_SLOTS=72, SLOT_BYTES=38160, 总 2.75 MB. ARM Cortex-A9 666 MHz 写 + flush ~2 ms 开销. 每帧 ~33 ms 预算够.

**更优解 (将来 HLS 重综合时)**: 在 HLS SLICES_LOOP 开头加一个 INNER 循环清空当前 slot, 比 ARM 端 memset 整个 ring 高效 (一次只清一个 slot, 不重读 DDR).

**症状判别**:
- HDMI 显示 anime 角色 (1024-clamp 时也类似但稀疏看不太出)
- 角色看起来像 vertical/horizontal mirror 重影
- JPEG 压缩率低 (因为非黑像素多)
- 修复后 JPEG 文件大小掉 ~40% (50KB → 30KB)

**Why:** 这是 32K resynth + xsdb 注入 anime 后看 HDMI 才出现的, 因为之前 1024-clamp 时角色稀疏, 残影不明显. 32K 完整渲染细节多, 残影一下显现.

**How to apply:** 任何 pov_project_batch (或衍生 IP) 渲染都要确保 slot 在每 fire 前清空. HLS IP 内部清更高效, ARM 端 memset 整个 ring 也行 (workaround).
