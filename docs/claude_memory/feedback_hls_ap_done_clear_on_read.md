---
name: HLS ap_done 是 clear-on-read, 多 IP 并行轮询必须 latch
description: 多 HLS IP 并行等 done 时必须用 done_mask 锁存, 直接每轮读全部 AP_CTRL 会丢 done
type: feedback
originSessionId: 25cdb314-8481-406a-9724-5d3798a00293
---
HLS 标准 s_axilite 控制寄存器 `ap_done` 位是 **clear-on-read**。轮询多个 IP 时如果每轮都读所有 IP 的 AP_CTRL, 先完成的 IP 的 done 位会被读清零, 后续永远凑不齐"全部 done", 看到的就是 timeout + 全部 IDLE (0x4)。

**典型错误代码** (会 timeout):
```c
for (u32 t = 0; t < N; t++) {
    int done = 0;
    for (int ip = 0; ip < 4; ip++)
        if (p4x_r(ip, P4X_AP_CTRL) & P4X_AP_DONE_BIT) done++;  // 读清零!
    if (done == 4) return 0;
}
```

**正确做法 — latch per-IP**:
```c
int done_mask = 0;
for (u32 t = 0; t < N; t++) {
    for (int ip = 0; ip < 4; ip++) {
        if (done_mask & (1 << ip)) continue;   // 已 latch 不再读
        if (p4x_r(ip, P4X_AP_CTRL) & P4X_AP_DONE_BIT)
            done_mask |= (1 << ip);
    }
    if (done_mask == 0xF) return 0;
}
```

单 IP 轮询的代码常常没碰到这坑, 因为见到 done 后 break, 没机会重读清零。多 IP 必须 latch。

**Why:** zynq_pov 4× HLS IP 并行渲染调试: solo-fire 测试每个 IP 单独 DONE 都正常 (polls~8433), BD 接线 query 也都正确, 但 `p4x_fire_all` + `p4x_wait_all` 后 4 个 IP 全卡 0x4 IDLE。最后定位是 wait_all 的 clear-on-read bug。修复后 4× IP 直接达到 60.54 FPS (VDMA scanout 上限), 相比 1× IP 的 30 FPS 翻倍。

**How to apply:** 任何多 HLS IP 并行场景必须 latch done。`ap_ready` 同样是 clear-on-read, 同理处理。`ap_idle` (bit 2) 不是 COR, 但单纯检查 idle=1 不够 (start 前也是 idle), 必须配合 latch 或先用 idle=0 等到 running 再等 idle=1。最简单还是 latch done。
