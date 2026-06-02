---
name: UART CH340 @ 921600 跑 PPCL parser 不通 (HDMI render 在跑时)
description: PS UART RX FIFO 64B 在 scale_blit 11ms 主循环阻塞下溢出, parser 永远 sync 不上 magic, model_n 卡 boot cube=315; xsdb dow -data 才是当前唯一可靠路径
type: feedback
originSessionId: 42b483be-17d4-4bd8-9194-41c6b8158af7
---
**规则**: 当 helloworld.c 主循环跑 HDMI render (scale_blit + HLS fire, total ~12ms/iter) 且 `sdio_bridge_active=0` 时, 不要用 UART CH340 + test_send_one.py 推 PPCL — parser 不触发, HDMI 永远显示 boot cube=315 点. 用 xsdb dow -data 路径 (tools/dl_helloworld_with_anime.tcl) 直推 DDR + ANIME_MAGIC.

**Why** (2026-05-20 测出):
- PS UART RX FIFO 硬件 64 byte. CH340 @ 921600 baud → 92 KB/s 持续到达
- main loop 一轮 ~12 ms (scale_blit 11.4 ms dominate)
- uart_poll_frame 散在 scale_blit row loop 里 (每 16 row 调一次), 但仍跟不上
- 一轮间隔积累 ~1.1 KB UART 数据 → 64B FIFO 必溢出, 字节大批丢失
- parser 永远找不到完整 16B header + 后续 5B point payload, magic sync 失败
- 验证: tiny 66B frame 也丢 (FIFO 容 64, 多出 2 byte 也丢); drain unfiltered 看不到 `[rxdone]`/`[rx-dump]`/`[comp]` 任何一行; model_n 永远是 boot init 的 315
- guard=256 (sdio_bridge_active=0 时) 不是根因, 提到 16384 也只是延后崩, 根本问题是 FIFO 硬件大小 vs main loop 阻塞时长
- 历史上能跑通的 UART 测试都在 sdio_bridge_active=1 (ESP32 SDIO 桥, 走 sdio_rx_buf 不走 UART HW FIFO), 或 main loop 没在跑 HDMI render

**How to apply**:
- 看 board 日志, model_n 不更新 + 没 `[rxdone]` → 确认是这个 bug, **不要再调 host send code**
- 当前可靠路径 = xsdb 直推 (memory `project_pov3d_anime_xsdb_path`), 30K 点 ~0.5s JTAG 写
- 想救 UART 路径需要 IRQ-driven UART + 大软件 ring buffer (KB 级), 是中等改造, 别 in-line 干
- 第二选择: 走 ESP32-C5 SDIO/WiFi 桥 (memory `project_esp32c5_wifi_bridge_live`), sdio_bridge_active=1 时 guard=16384 + sdio_rx_buf 32KB 能扛住
- 调 baud 到 115200 理论可减 8× 压力但 HDMI demo 主循环没相应慢下来, 没本质解
