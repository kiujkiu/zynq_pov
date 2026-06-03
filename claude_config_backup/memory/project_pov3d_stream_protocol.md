---
name: POV3D 点云流协议（极简版）
description: Host → 板子 UART 点云流的 wire 格式；当前版本已端到端跑通
type: project
originSessionId: bafc105a-a8db-471f-ae33-42571927b4da
---
**协议文件**：
- Host 端：`host/pointcloud_proto.py`（pack_frame）
- 板子端：`helloworld.c` 里内联 `pc_hdr_t` 结构 + `uart_poll_frame()` 状态机

**wire 格式**（little-endian）：
```
offset  size  field
0       4     magic = 0x50 0x50 0x43 0x4C  ('PPCL' LE)
4       4     frame_id (uint32)
8       2     num_points (uint16, ≤ MAX_POINTS=1024)
10      2     flags (reserved = 0)
12      4     reserved = 0
16      16*N  point_t 数组
```

每个 point_t 16 字节：`int16 x,y,z,_pad0; u8 r,g,b,_pad1; int32 _pad2`

**Why：** 现有 `receiver/pov3d_protocol.h` 是为 mesh + skin matrix 设计的，太复杂；实际需求只需 "一坨 3D 点 + 颜色"。极简协议 16B 头让字节级状态机 2 秒写完。

**How to apply：**
- 更大模型要把 `MAX_POINTS` 从 1024 再放大，ARM 侧同步改 `helloworld.c` 的 MODEL 区域大小
- 115200 baud 带宽极限：~2.3 FPS for 300 点，换 ETH/WiFi 才能高 FPS 流
- 板子 UART RX FIFO 只有 64 字节，ARM 长操作（memset、flush）期间会溢出；我们在 72-slice 循环中每 slice 间插 `uart_poll_frame()` 来防

**已验证**：Host 发 279 点 cube，板子正确 dump 前 3 个点的 x/y/z/r/g/b 跟预期一致。
