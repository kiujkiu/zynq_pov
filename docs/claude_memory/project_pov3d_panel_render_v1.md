---
name: POV3D LED panel 静态渲染管线 v1 (2026-05-29)
description: baremetal 完整 PNG→panel pipeline, 但目标对齐前停下 — 用户提示我可能跑偏 (实际目标可能是 POV 旋转 3D 不是静态 2D)
type: project
originSessionId: 42b483be-17d4-4bd8-9194-41c6b8158af7
---
**当前阶段**: baremetal 静态图渲染管线打通, **但目标未对齐**.

**已交付** (2026-05-28~29):
1. `led_panel.c` 大清理: 1930 → 354 行, 删 22 个废 mode + dead 路径
2. `led_panel.h` 公开 API 精简到 4 个函数 (`init`/`spi_read_flash`/`multi_mode_diag`/`init_pins`)
3. `panel_image_data.c` 由 `tools/image_to_panel.py` 生成, weak 符号链接覆盖
4. `mode_image_render` (48×12×3 RGB, 1-bit threshold) + 4 个调试 mode
5. 标定工具: `cap_sweep.py` / `analyze_sweep.py` / `viz_lut.py` / `cap_chain_id.py`
6. **chain→X 映射确认**: `region = chain/3` (0=右组 R1G1B1, 1=中组, 2=左组 R3G3B3)
7. **chip→Y 映射确认**: chip 0 在 panel 顶, chip 11 在底, 单调
8. anime PNG → display 全管线跑通 (虽然观感差)

**未解 / 已知限制**:
- panel 颜色串扰: G/B 单独点显示 cyan, 怀疑 PCB 短路或 LED 内部并联 — 未排查
- Scan multiplex: camera shutter 内只抓到部分 row (1/20 scan 的 ~50% 帧覆盖), 静态肉眼或许全, 但拍照像缺行
- 1-bit 阈值无灰度: BCM 没实现
- ARM 每帧 46k AXI write 是性能瓶颈 (Plan B 必须做)

**关键悬念 (用户 2026-05-29 提示)**: 我做的是静态 2D, 但项目本身是 POV-3D 旋转显示 (720 slice × 30 Hz × 160×180, 有 HLS pov IP 已渲染 slice 到 HDMI). 用户问 panel 是否在旋转/anime 是 2D 还是 3D/跟 HDMI 关系等. 答案影响 Plan B 设计 (静态 panel 喂 framebuffer, 旋转 panel 要 720 slice 同步).

**下次起点**: 等用户回答 4 个对齐问题后再决定 Plan B 方向, 现成 baremetal v1 可保留作 debug fallback.

**改过的源码** (本会话):
- `02_hello_zynq/vitis_ws/hello_world/src/led_panel.c` (重写)
- `02_hello_zynq/vitis_ws/hello_world/src/led_panel.h` (精简)
- `02_hello_zynq/vitis_ws/hello_world/src/helloworld.c` (删 unreachable call)
- `02_hello_zynq/vitis_ws/hello_world/src/UserConfig.cmake` (加 panel_image_data.c)
- 新: `02_hello_zynq/vitis_ws/hello_world/src/panel_image_data.c` (生成)
- 新: `tools/cap_sweep.py` `analyze_sweep.py` `viz_lut.py` `lut_inverse.py` `cap_chain_id.py` `image_to_panel.py`
