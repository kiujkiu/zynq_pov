---
name: dual-core 启用下 UART rx 协议 desync (2026-05-11)
description: ENABLE_DUAL_CORE=1 + PC send model via UART → parser 中途 desync, model_n 不更新. cache race fix 已解但 UART 仍有 issue.
type: feedback
originSessionId: 25cdb314-8481-406a-9724-5d3798a00293
---
**现象**: ENABLE_DUAL_CORE=1 + python `test_send_one.py` 发 154KB voxel:
- python 报 "done" 无 [rxdone] echo
- 板上 `model_n` 仍是 boot 默认 315 (cube), 没更新到 30803
- `model[0]` DDR 内容 IS anime data 部分写入 ✓
- HDMI 显 axes/bbox 默认 (因为 model_n=315)

**Root cause** (未完全实证, 推测):
- dual-core 主循环 CPU0 = kick + RIGHT render + wait CPU1, 每帧 13.5 ms
- 帧内有 uart_poll_frame 调用 (主循环 line 2204 + wait loop line 2247), 频率上够
- 但 PMSH/PPCL 协议解析状态机非 reentrant. cpu_render 内部嵌套 poll 会消费 frame_ready (memory `feedback_uart_poll_nested_dispatch`)
- 加上 dual-core 双核共享主 state, parser 中途同步丢失 → model_n update 行 (helloworld.c:510) 触发条件不满足

**Why**:
- single-core same code path 实测稳, parser 一致
- dual-core 引入 wait 长 + 调度时序变化 → parser 边界条件触发概率高

**How to apply**:
- 当前 ENABLE_DUAL_CORE 默认 0. 启 dual-core 时**用户必须接受**: UART model load 失败.
- 启用 dual-core 真值前需先**UART IRQ-driven 改造** (半天工程): UART rx 走 hw interrupt + ring buffer, 主循环只 drain buffer, 不在 render 里 inline poll. 这消除 parser reentrancy + 长 render 下 sync 风险.
- 或: voxel path single-core 已 60.54 FPS @ 13.5 ms render avg, 不需 dual-core. dual-core 真正价值 = mesh path heavy render (30+ → 8 ms). 但 mesh send 也受同 UART desync issue.

**实测数据 (2026-05-11)**:
| 场景 | render avg | FPS | UART model load |
|---|---|---|---|
| single-core 无 model | 8 ms | 60.54 | N/A |
| single-core + anime voxel 30803 | 13.5 ms | 60.54 | ✅ rxdone OK |
| dual-core 无 model | 8 ms | 60.54 | N/A |
| dual-core + try anime send | 13.5 ms | 60.54 | ❌ model_n stuck 315 |

**Cache invalidate race fix 是好的** — dual_core.c 加了 CPU1 渲染前 Xil_DCacheInvalidateRange (commit `0178c4a`), 解决了 LEFT panel 噪点根因 (CPU1 L1 stale). 但 UART 路径是独立 issue.
