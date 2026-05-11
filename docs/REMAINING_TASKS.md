# 剩余任务清单 (2026-05-11 update — ESP32 + Zynq SDIO 全栈代码就绪)

## ✅ 新增完成 (2026-05-11)

- **ESP32-C5 SDIO firmware** (IDF master `9bbb6446b`): pov_bridge.bin 969 KB, WiFi STA undef + SDIO slave 4-bit DDR50 + TCP:8888 + mDNS `pov-bridge.local`, build verified
- **Zynq baremetal SDIO host driver** (`sdio_esp.h/.c`): IO card init seq (CMD0/5/3/7/52/53) + send/recv API, ELF 99930 byte build verified
- **BD tcl** `tools/bd_enable_sd0_for_esp32.tcl`: PCW_USE_SDIO0=1 + MIO40-47 配置 (待 user 跑 Vivado)
- **PC 测试脚本** `host/test_wifi_bridge.py`: mDNS / TCP / 吞吐量验证

## 等用户硬件 wire (按顺序)

1. flash ESP32-C5 (`esptool --chip esp32c5 -p COM5 write-flash 0x2000 bootloader.bin 0x8000 partition-table.bin 0x10000 pov_bridge.bin`)
2. `idf.py monitor` 验 "Got IP: x.x.x.x"
3. PC 跑 `python host/test_wifi_bridge.py` — mDNS + TCP echo 验同 LAN
4. Vivado 跑 `bd_enable_sd0_for_esp32.tcl` + 综合 + 重 export XSA
5. 接 SDIO 线: ESP32 GPIO 9/10/8/7/14/11 (CMD/CLK/D0-3/INT) ↔ Zynq MIO40-47 (断 microSD)
6. ENABLE_SDIO_ESP_BRIDGE=1 + rebuild + dl
7. UART log "[sdio-esp] CMD5 OP_COND OK, RCA=..." 验通信通

---

# 旧版剩余任务清单 (2026-05-11 之前)

Phase 9.5 + LED panel prep 全部完成. Boot QSPI standalone 通. 跑产品需以下分类任务推进.

## 🟢 软件可立刻推 (无硬件依赖)

| # | 任务 | 预估工时 | ROI | 说明 |
|---|---|---|---|---|
| S1 | **UART rx IRQ-driven 改造** | 半天 | 高 | 现 polling-based parser 在 dual-core / 长 render 下 desync (memory `feedback_dual_core_uart_desync`). 改 Zynq UART hw interrupt + ring buffer, 主循环只 drain. 解锁 dual-core + 长 render 路径下的 model 加载. |
| S2 | **mesh slice HLS IP BD 集成** (备用 B 路径) | 1 hr | 低 | A 路径已锁 voxel 4× IP (ADR-001). 若 LED 屏到货后实测 voxel 离散问题严重, 切到 mesh single IP. tcl 骨架在 `tools/bd_swap_to_mesh_slice.tcl` 已就位. |
| S3 | **HLS v2 IP swap 到 BD** | 30 min | 低 | 现 BD 用 v1 pov_project_batch (Phase 4b). v2 (dual-HP, iter latency -58%) IP zip 在 hls_proj. 切到 v2 解锁 fmax 205 MHz. 切换 risk 低. |
| S4 | **Final BOOT.bin with all features** | 10 min | 中 | 用最新 hello_world.elf (含 LED 1Hz, dual-core 备 off, led_panel.c 编进, qspi fix) 重打 bootgen → QSPI 烧入. 上电脱机演示状态最佳. |
| S5 | **HDMI 颜色微调收尾** | 主观, 任意 | 低 | Phase 8 已锁颜色到 anime 接近. 若用户主观再调 brighten/gamma/saturation/tonemap, 现有 voxelize_mesh 参数即可. |

## 🟡 半阻塞 (需小硬件 / 用户操作)

| # | 任务 | 阻塞条件 |
|---|---|---|
| H1 | **ESP32 桥接通** | 烧 `esp32_bridge/firmware/main/pov_bridge.c` 到 ESP32-C3/S2 模块, 接 UART/WiFi 桥. PWFR 协议 stub 已写 (Phase 9 B). 测 lwIP UDP burst 实际带宽. |
| H2 | **WiFi credentials 配置** | WiFi 路由 SSID/密码, ESP32 mDNS 找板子. |
| H3 | **JTAG 调试自检** | SW3 切回 NAND mode 防 standalone boot 干扰, JTAG dl 调试. |
| H4 | **HDMI capture 流水线** | OBS Virtual Camera 占用 capture 卡 → 调 OBS 优先级 / 用独立物理 monitor + 手动观察, 不影响开发流程. |

## 🔴 全阻塞 (等硬件就位)

| # | 任务 | 缺什么 |
|---|---|---|
| HW1 | **LED panel 接通 (阶段 1: 物理 verify)** | 24× ICND3019 + 108× ICND1069 + 8× 74HC245 panel 实物到货. 万用表测 FPC pinout. |
| HW2 | **LED panel 阶段 2: 最小 demo** | ARM bit-bang driver (`led_panel.h/.c` 已写) JTAG dl 测试图案 (黑/白/红/绿/蓝/棋盘格). |
| HW3 | **LED panel 阶段 3: PL HW 移植** | Verilog `led_panel_drv.v` (已写 xsim 通过) 通过 `tools/bd_add_led_panel_drv.tcl` 集成到 BD, 综合 + 真测 throughput. |
| HW4 | **LED panel 阶段 4: POV 旋转测试** | LED 屏装电机 + 编码器 + slip ring 供电, voxel 4× IP 跟编码器 angle 同步. 这是 720 angle × 30 Hz POV 真验证终点. |
| HW5 | **WiFi 实链路实测 PWFR** | ESP32 桥 + 板上 lwIP 接通后, 测 720@30Hz=186 MB/s vs WiFi 极限 20-50 MB/s, 必须 delta encoding (Phase 9 B 已设计). |

## 🔵 工程清理 (低优先, 看心情)

| # | 任务 |
|---|---|
| E1 | GitHub PR `phase9.5-task-I-dual-core` → `master` merge (UI 操作) |
| E2 | README / HOWTO 更新: dual-core 状态 (default OFF + UART desync 已知) / QSPI standalone boot / SW3 拨码 |
| E3 | 测试套件: qspi_flash_writer / dual_core / HLS IP 各 standalone test |

## ⭐ 我的推荐执行顺序

1. **S4 Final BOOT.bin** (10 min) — 当前最高 ROI, 收口 phase 9.5+ 状态
2. **S1 UART IRQ 改造** (半天) — 真正解锁 dual-core 3.7× 加速
3. **HW1+HW2 LED panel 阶段 1-2** — panel 到货立刻可推
4. **H1 ESP32 桥** — WiFi 模块到货后即可推

执行计划:
- 短期 (本周): S4 + (待 panel 到货) HW1
- 中期 (下周): S1 UART IRQ + HW2 LED bit-bang
- 长期 (panel + ESP32 全到): HW3-5 + H1
