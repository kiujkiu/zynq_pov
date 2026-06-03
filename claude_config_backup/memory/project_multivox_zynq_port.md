---
name: Multivox POV → Zynq7020 移植 + 48-IO HUB75E 高速方案 (2026-05-29)
description: 把 multivox 的 RPi HUB75E driver 改成 Zynq 7020 PL IP, 用 48-IO 拆 daisy-chain 架构实现 7K fps × 8-bit color
type: project
originSessionId: 42b483be-17d4-4bd8-9194-41c6b8158af7
---
**项目源代码**: `D:\claude_workspace\pov3d\multivox` (不是 zynq_pov!)
- RPi 4 GPIO bit-bang 驱动 HUB75E LED panel, 旋转 POV 体显示
- 关键文件: `src/driver/vortex.c` + `src/driver/gadgets/gadget_vortex.h`
- 信号: 12 RGB (2 panel × 6 chain), DCLK, OE(BLANK), LE(STROBE), ADDR(CLK/DAT/EN)

**硬件配置 (vortex 设备)**:
- 2 个 128×64 HUB75E panel (旋转轴垂直), 1/32 scan
- 每 panel: 8 颗 FM6124 daisy-chain × 6 chain (RGB×2) = 48 IC per panel = 96 IC 总
- ABCDE shift-register addressing (不是直接 A-E pins)
- 30 Hz 旋转, photodiode sync

**目标**: 7K fps × 8-bit RGB color depth (用户必须显示 3D 模型, 不能少色深)

## 关键技术决策 (2026-05-29 long session 分析结果)

### 1. 不能换 MBI5264
- MBI5264 引脚跟 FM6124 不兼容 (FM6124 OE pin ↔ MBI5264 GCLK pin)
- MBI5264 内置 PWM 周期 8 ms~64 ms (13~16 bit), 显示刷新最高 125 Hz, 比 7K fps 慢 56×
- MBI5264 无 OE pin, 无法外部 BCM, 物理上做不了高 fps
- POV 每 slice 都是新图, SRAM 一次写多次显示的优势不存在
- 详细对比见: `reference_pov_chip_selection.md`

### 2. 不能用标准 HUB75E (6-chain daisy)
- 标准: 6 chain × 8 IC daisy = chain 长 128 bit, 每帧上传 128 DCLK
- 7K fps × 8-bit = 1.38 Gbps 总带宽需求
- 6 chain × 30 MHz = 180 Mbps, 差 7.6×, 物理不可能
- 即使 ICN2053 60 MHz, 6 chain = 360 Mbps, 仍差 4×

### 3. 解 → 48-IO 拆 daisy 方案 (用户提出)
拆开 daisy-chain, 每颗 FM6124 SDI 独立接 Zynq IO:
- 48 chain × 1 IC each (chain 长仅 16 bit)
- 上传 16 col 数据 = 16 DCLK = 533 ns @ 30MHz
- 32 row × 533 ns = **17 µs / BCM plane**
- 8-bit BCM = 8 plane × 17 µs = **136 µs / 帧**
- **7,350 fps × 8-bit** ✓ (256 灰度/通道, 1670 万色)
- duty cycle 25% (BCM 总 display time = 33.7µs / 136µs), Rext 改小 4× 补偿亮度

### 4. 实施路径
**硬件 (1-2 周)**:
- panel PCB 把 8 颗 FM6124 SDI 接线拆开, 48 根独立 SDI 引到 panel 边缘接 Zynq
- DCLK/LE/OE/ADDR broadcast 给全部 IC, 跟原来一样
- 比原 multivox 多接 47 根线

**Zynq 7020 PL IP (1 周)**:
- 48-chain HUB75E driver IP (Verilog)
- 32 row × 8 plane BCM FSM
- OE BCM 计数器 (每 plane 显示 2^i × T 时长)
- ADDR shift 跟 data shift 并行
- 资源: 48 高速 IO + 6 BRAM (帧 buffer 24 KB), 100 PL IO / 140 BRAM 充足

**软件 (3-5 天)**:
- 跟 multivox vortex.c 兼容: mmap volume buffer (shared mem)
- host 端: 24-bit RGB → 8 个 1-bit plane (BCM decomposition)
- ARM 跑 Linux, 数据走 DDR, PL m_axi 读 (Plan B 思路, 跟 zynq_pov 同方向)

### 5. 备选: 9-bit / 10-bit 几乎免费
- 9-bit (512 级): 153 µs/frame → 6.5K fps ≈ 仍接近 7K, 5.4 亿色
- 10-bit (1024 级): 170 µs/frame → 5.9K fps, 10 亿色
- 用户若愿牺牲一点 fps 换更高色深, 调 #define 即可

## 上下文外的相关材料

- **MBI5264 datasheet 中文版** (已翻译): `D:\workspace\zynq_pov\docs\mbi\MBI5264_advance_CN.md`
- **MBI5264 英文版**: `D:\workspace\zynq_pov\docs\mbi\MBI5264_advance.pdf`
- **FM6124 datasheet 仅 2 页中文摘要**, 完整版需找代理或自己测协议
- **zynq_pov 项目里 led_panel_seq.v IP** (LE-长度编码协议) — 跟 multivox 不一样, 那个是 ICND1069 协议
- **multivox vortex.c scan loop** — `vortex.c:570-650` 是 RPi GPIO 主循环, ~1 MHz 有效 DCLK (慢, 因 RPi mmap GPIO 延迟)

## 用户给的关键约束 (2026-05-29 当面确认)

1. multivox 代码在 `D:\claude_workspace\pov3d\multivox`, RPi 驱动现状
2. 目标 fps **必须 ≥7000**
3. panel: 128×64, 1/32 scan, HUB75E 接口
4. PCB 自己的, **可飞线但尽量保持原样** → 48-IO 改动可接受
5. 每 chain 8 颗 IC (8 颗 FM6124 daisy 是现状)
6. **必须 8-bit 色深** (要显示 3D 模型, 色阶不能差)

## 下次开新会话的起点

直接说 "继续 multivox 48-IO 移植" + 引用此 memory.

第一步动手:
- 写 Verilog `hub75e_48ch_driver.v`: 48 SDI shift FSM + BCM OE controller + ADDR shifter
- 草图 .xdc 引脚分配 (Zynq 7020 CLG484)
- multivox 端 mmap 协议 + BCM decomposition 工具 (Python)

不要重新讨论选型 — 已定: **FM6124 + 48-IO + Zynq 7020 PL + 8-bit BCM**.
