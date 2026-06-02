---
name: POV3D 后续架构: PS Linux + PL 时序 (2026-05-28)
description: 战略决定 — PS 端切 Linux 解决 WiFi 问题, 所有时序相关代码必须搬到 PL, DDR 帧 buffer 成为 Linux↔PL 唯一契约
type: project
originSessionId: 42b483be-17d4-4bd8-9194-41c6b8158af7
---
**决定**: PS 上跑 Linux (替代 baremetal) 解决 WiFi 吞吐瓶颈; 所有 timing-critical 代码搬到 PL.

**Why**:
- 现在的 ESP32-C5 WiFi 桥被 single-core RISC-V 100KB/s 卡死, 30fps 上限 hardware-bound
- Linux 有成熟 WiFi 栈 (USB dongle / 第二 SDIO) — 直接绕开 ESP32, 上 Mbps 级
- Linux 非实时, baremetal 那种 ARM 写 46k AXI/frame 的活在 Linux 下会被调度抢占 → jitter 死

**How to apply** (所有未来设计都按这个原则):
1. **PL 拥有所有时序**: panel scan / POV slice / DCLK / SDIO 协议 / 帧同步 — 全部 PL FSM 实现, 不依赖 ARM 时间
2. **DDR 是唯一契约**: Linux 写帧 buffer + 一个 CSR 启动, PL 自己 m_axi 读 + 跑
3. **ARM/Linux 只做**: 数据搬运 (socket→DDR), 一次性 init (chip register cfg), 状态汇报
4. **当前 baremetal led_panel.c 的 render_frame_targeted() 在 Linux 下不可用** — 必须先做 Plan B (panel_seq IP 加 m_axi master + frame walker)

**对当前进度的影响**:
- Plan B 从"性能优化"变成"必须做" — Linux 跑不动 baremetal 那 46k AXI/frame
- HLS pov IP 已经在 PL ✓, 但 ARM 触发 fire 的循环也要迁 PL (slice trigger FSM)
- HDMI VDMA 已经 PL ✓
- WiFi → SDIO → ARM → DDR 路径在 Linux 下变 WiFi → 网卡 → kernel → mmap → DDR (省掉 ESP32 + SDIO)

**下一步顺序锁定**:
1. 完成 LED panel chain→X 映射定标 (manual visual, 5 min)
2. Plan B 实施: panel_seq IP + m_axi + frame walker → ARM/Linux 写 82KB 帧 buffer 就够
3. 类似改造 pov 触发链路 (slice timing 全 PL)
4. 评估 Linux 移植路径 (PetaLinux / Buildroot, USB WiFi 选型)
