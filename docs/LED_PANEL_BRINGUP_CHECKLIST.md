# LED Panel Bring-up 工作清单

针对 160×180 RGB POV LED panel (24× ICND3019 + 108× ICND1069 + 8× 74HC245).

## 阶段 0: panel 到货前 (软件准备)

- [x] **Datasheet 收齐** — ICND1069 / ICND3019 / ICND1039 (备用)
- [x] **Memory 记录** — `~/.claude/.../reference_led_panel_hardware.md`
- [ ] **(A) ARM bit-bang driver** — `02_hello_zynq/.../led_panel.h/.c` (agent 跑中)
- [ ] **(B) PL Verilog driver IP** — `hls_proj/led_panel_drv/` (agent 跑中)
- [ ] **BD 集成 tcl 骨架** — `tools/bd_add_led_panel_drv.tcl` (本文档预备)

## 阶段 1: panel 到货 + 物理 verify

- [ ] **目视检查** — 焊接 OK, 元器件无松动, 24×3019 + 108×1069 + 8×245 数对
- [ ] **万用表测** — FPC 连接器 pinout: 哪些是 GND? 哪些是 VCC (3.3V/5V)? 哪些是 signal? 通常 GND 多, VCC 一般 1-2 个
- [ ] **示波器抓** — panel 配套控制器 (如果厂商有给) 上电时 FPC 信号: 识别 DCLK / SDI / LE / ROW / RCLK 各信号实际位置 + 时序
- [ ] **Reverse engineer 协议** — 对比 datasheet, 确认:
  - cascade 顺序 (4 chain 怎么映射 panel 物理 quadrant?)
  - scan ratio (1/180? 1/16? 其他?)
  - PWM 位深 (16-bit / 8-bit / 6-bit?)
  - LE length 编码具体 mapping (1=数据写? 多=寄存器配置?)

## 阶段 2: 上电 + 最小 demo

- [ ] **接 FPC 到 FPGA** — 通过 GPIO 扩展接口 (BANK 33 / BANK 35), 电源连 5V
- [ ] **JTAG dl ARM bit-bang driver** — 跑测试图案:
  - 全黑 → panel 不亮 (基线)
  - 全白 → 整 panel 同色 (cascade 通信 OK)
  - 全红 / 全绿 / 全蓝 → 验证 RGB 三路分别工作
  - 棋盘格 → 验证 column/row 寻址正确
  - 色条 → 验证 PWM 灰度
- [ ] **HDMI mirror** — 同一 fb 同时送 HDMI debug 和 panel, 视觉对比

## 阶段 3: PL HW driver 替换 ARM bit-bang

- [ ] **BD 集成 led_panel_drv IP** — 跑 `tools/bd_add_led_panel_drv.tcl`
- [ ] **重综合 + dl new bit** — Vivado synth+impl ~25 min
- [ ] **替换 ARM call** — helloworld.c 切到 PL HW IP fire/wait 流程
- [ ] **测真实 throughput** — UART log 看 frames/sec, target ~21.6K slice/sec

## 阶段 4: POV 真实测试 (LED 旋转后)

- [ ] **物理装上旋转结构** — panel 装电机 + 编码器 + slip ring 供电
- [ ] **角度同步** — voxel 4× IP 输出 ring buffer 跟编码器 angle 同步
- [ ] **视觉效果验证** — 720 angle 旋转 30Hz POV 立体像
- [ ] **颜色微调** — agent E warm bake 路径在真 POV 显示效果

## Bring-up 常见坑 (来自经验)

- **VCC 错** — 5V panel 接 3.3V 不亮, 或反之烧 IC. 上电前万用表测.
- **FPC 反插** — pin 1 位置错, 信号互换. panel 烧或不亮. FPC 标记位置确认.
- **74HC245 方向** — DIR pin 高低决定 buffer 流向. 默认应是 FPGA→panel (B→A 或 A→B 看连接). 反了 panel 收不到信号.
- **Cascade 链长** — 27 cascade × 25 MHz 实际可能 cascade 末端时序衰减, 需要降速到 12.5 MHz / 5 MHz 测.
- **REXT 错** — 电流过大烧 LED, 过小不亮. 默认 3kΩ ≈ 4mA 安全.
- **GND 多点 vs 单点** — 8 个 245 buffer 的 GND 必须跟 panel + FPGA 共地, 否则 logic level 漂移.

## 厂商沟通 checklist (如果可联系)

- [ ] FPC connector pinout 文档
- [ ] 推荐 DCLK 频率 (25 MHz upper limit OK?)
- [ ] panel scan ratio 设计值
- [ ] 推荐 REXT / LED 电流值
- [ ] panel 工作 VDD (3.3V or 5V?)
- [ ] 是否有 reference driver code (即使是 STM32 / Arduino 也行)
