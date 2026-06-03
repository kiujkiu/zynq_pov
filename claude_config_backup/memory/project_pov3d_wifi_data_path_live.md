---
name: POV3D WiFi 数据通路完整跑通 (PC→TCP→ESP32→SDIO→Zynq)
description: 2026-05-14 端到端 39 KB/s 稳定, anime_stream.py --host 替代 UART, helloworld.c ENABLE_SDIO_ESP_BRIDGE=1
type: project
originSessionId: 25cdb314-8481-406a-9724-5d3798a00293
---
**2026-05-14 完成日期**

替代 UART COM4 (1-5K pts) 和 xsdb JTAG (静态) 两条窄路径, 主推路径。

**完整通路**:
```
PC (10.168.168.119)
  ↓ TcpAsSerial wrapper (host/anime_stream.py --host 10.168.168.137)
  ↓ TCP :8888 (TCP_NODELAY)
ESP32-C5 (10.168.168.137, 5G HT40 ch161, rssi -40)
  ↓ pov_bridge_sdio server_task → recv → sdio_tx_bytes
  ↓ SDIO slave TX queue (block 512, 16 bufs)
Zynq SD0 host (helloworld.c ENABLE_SDIO_ESP_BRIDGE=1)
  ↓ sdio_esp_recv() pulls 16KB chunks main-loop
  ↓ sdio_rx_buf[16KB] → uart_rx_byte() (透明替换 UART)
  ↓ PPCL frame parser
  ↓ model[] in DDR @ 0x1A000000
  ↓ HLS pov_project_batch / VDMA / HDMI
```

**实测**: 30 帧 @ 5 fps × 500 pts × 16B + 16B header = 234 KB / 6s ≈ **39 KB/s 持续, 无丢帧**
- ESP32 短测 5 帧 19 KB/s, 长流 30 帧 39 KB/s — 后者更接近真值
- model_n 实时跟随 PPCL frame: anime inject 30803 → PC 推 800 → 500
- sdio_rx_head == sdio_rx_tail 一直 drain 完, ESP32 SDIO queue 无积压

**xsdb 直读诊断地址** (符号位置可能随 build 变, 用 nm 找新值):
```
sdio_bridge_active  0x0011c2f4  期望 1
last_sdio_init_rc   0x00114548  期望 0 (SDIO_ESP_OK)
sdio_rx_head/tail   0x0011c264 / 0x0011c2f8  应同步
model_n             0x0011c25c  跟 PPCL frame
```
COM4 UART 物理可能没接也无所谓, xsdb mrd 直接看状态.

**Why:** 之前两天调 WiFi 死路是密码占位 'undef' 没换 (memory 翻案), 修对后 WiFi/TCP 秒通. SDIO bridge 代码早就写好 (sdio_esp.c + sdio_esp_recv), 飞线接好后 `ENABLE_SDIO_ESP_BRIDGE 0→1` 一改就工作.

**How to apply:**
1. PC 推: `python anime_stream.py <glb> --host 10.168.168.137 --tcp-port 8888 --points N --fps F --color keep`
2. 重启 Zynq: `xsdb dl_helloworld_with_anime.tcl` (anime fallback 仍有用, boot 立刻显示 anime, PC 推送才切流)
3. 验证: xsdb mrd 看 sdio_bridge_active 跟 model_n; HDMI 屏看是否切到 PC 推的 model
4. IP 是 DHCP, 重启 ESP32 可能换, 用 mDNS `pov-bridge.local` 更稳
