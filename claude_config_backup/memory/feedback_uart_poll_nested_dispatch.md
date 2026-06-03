---
name: uart_poll_frame 嵌套调用会丢 frame_ready
description: helloworld.c 的 uart_poll_frame 在 cpu_render 内部被反复调用 (panel clear, voxel write, cache flush 都会 poll), 主循环看不到内部 poll 的 frame_ready=1 事件.
type: feedback
originSessionId: bafc105a-a8db-471f-ae33-42571927b4da
---
helloworld.c 的 `uart_poll_frame()` 函数返回 `frame_ready` (一帧点云接收完成). 但它在 `cpu_render_voxel_panel` 内部被嵌套调用 (panel clear 每 16 行, voxel write 每 128 voxel, cache flush 每 32 行 都 poll 一次). 当 anime 数据接收完成发生在某次嵌套调用中, frame_ready=1 仅对那一次调用返回, 主循环 (line 1156) 下一次 uart_poll_frame() 调用时已经是空白状态返回 0.

**Why:** 排查"按需渲染右侧 grid"时遇到, anime 数据 [rx-dump] 出现但 [rx] 主循环回调没触发, 右侧 grid 一直是 cube 切片 — 因为 right_dirty 是局部变量, 只在主循环识别 got_frame=1 时设. 改用 global volatile + 在 frame_ready=1 同处设置才生效.

**How to apply:** 任何"收到新点云后做某事"的状态设置都不要依赖 main loop 的 uart_poll_frame() 返回值. 改用全局 volatile, 直接在 helloworld.c line 378 (frame_ready=1 那行) 同时设置. 或者重构 uart_poll_frame 让 frame_ready 全局化.
