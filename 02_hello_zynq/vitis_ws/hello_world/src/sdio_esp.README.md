# sdio_esp — Zynq baremetal SDIO host driver to talk to ESP32-C5 SDIO slave

`sdio_esp.c/h` 实现 PS SDIO0 host driver, 跟 ESP32-C5 上的 ESP-IDF SDIO slave
firmware (`pov_bridge.bin`) 通信. 替换原 CH340 UART 路径, 让 PC 通过 WiFi → ESP32
→ SDIO → Zynq 推点云/控制数据.

## 接线 (鹿小班板 SD0 扩展)

鹿小班 SD0 走 MIO40-47, 在板上跟 microSD slot 共用.
**用 ESP32 时必须断开板载 microSD (物理拔卡或飞线切断)**.

| 信号    | Zynq MIO  | ESP32-C5 默认 IO         | 备注                |
|---------|-----------|---------------------------|---------------------|
| CLK     | MIO40     | GPIO9                    | 25-50 MHz           |
| CMD     | MIO41     | GPIO10                   | 上拉 10k 到 3.3V    |
| DAT0    | MIO42     | GPIO8                    | 上拉 10k 到 3.3V    |
| DAT1    | MIO43     | GPIO7                    | 上拉 10k 到 3.3V    |
| DAT2    | MIO44     | GPIO14 (或 IO0)          | 上拉 10k 到 3.3V    |
| DAT3    | MIO45     | GPIO11                   | 上拉 10k 到 3.3V    |
| GND     | -         | GND                      | 共地                |
| 3.3V    | -         | 3.3V                     | 单独给 ESP32 供电   |

(具体 ESP32-C5 引脚以 pov_bridge 实际烧的 SDIO slave config 为准.)

## Zynq SD0 启用流程

1. 跑 `tools/bd_enable_sd0_for_esp32.tcl` 改 BD (`PCW_SD0_PERIPHERAL_ENABLE=1`,
   MIO40-45 = SDIO).
2. 在 Vivado: `reset_run synth_1; reset_run impl_1; launch_runs impl_1 -to_step write_bitstream -jobs 8`.
3. 等综合完, `write_hw_platform -fixed -include_bit -force` 重导出 `hello_zynq_wrapper.xsa`.
4. 回 Vitis: 用新 XSA refresh `hello_plat` platform, BSP 自动添加 `xsdps` driver
   + `XPAR_XSDPS_0_BASEADDR` 宏.
5. 重 build `hello_world`. `sdio_esp.c` 检测到宏后, 编译 real path; 否则 stub.

## 启用 driver

`helloworld.c` 顶部:

```c
#define ENABLE_SDIO_ESP_BRIDGE 1     /* 默认 0 */
```

main() 会 try `sdio_esp_init()`. 失败 (no BSP / 没接卡) → fall-back UART 不破坏.

## 测试

板启动后 UART log 应该看到:

```
[sdio-esp] CCCR ver=0x11
[sdio-esp] RCA=0x0001
[sdio-esp] CMD5 OP_COND OK, RCA=0x1, ready
```

之后 main loop 每帧 poll `sdio_esp_recv(buf, MODEL_RX_BUF_SZ, &got)`.
ESP32 firmware 端通过 WiFi 收到 host PC 的 PPCL frame 后 enqueue 到 SDIO TX,
Zynq 这边读出来交给原 model parse 流程.

## TODO (未硬件验证)

- BD 没真综合 — user 决定何时停掉 microSD 切到 ESP32.
- ESP32-C5 SDIO slave 板上接线尚未实物.
- `XSDPS_BUF_DAT_PORT_OFFSET` PIO 4-bit @ 50 MHz 吞吐可能不够 720 slice/30 FPS;
  以后可以切 SDMA 路径 (`XSdPs_WritePolled`).
- `SDIO_ESP_PKT_LEN_REG / TX_REG / RX_REG` 用了 ESP-Hosted 慣例偏移, 实际跟
  `pov_bridge.bin` 烧的 slot 布局对齐时可能要调.
- 没开 SDIO interrupt, 全 polling — 后续切 GIC 中断减开销.

## 兼容性

- `ENABLE_SDIO_ESP_BRIDGE=0` (默认): 编译进 ELF, 不调用. 不破坏现有 UART /
  dual-core 路径.
- `ENABLE_SDIO_ESP_BRIDGE=1` + BSP 含 xsdps: real driver 起来, 初始化失败时
  fallback UART poll.
- `ENABLE_SDIO_ESP_BRIDGE=1` + BSP 不含 xsdps: stub 编进去, 启动报
  "xsdps not in BSP" warning, 自动 fallback UART.
