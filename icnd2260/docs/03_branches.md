# 分支矩阵：板子到了按这个顺序试

每个分支只改一处、只回答一个问题。**烧之前先看 LED**：
LED1 常亮 = 没进正常显示（固件卡住/电源没起）；LED1 闪 = 帧循环在跑；
**LED2 亮 = 收到过一条 CRC 正确的 ACK 回包 = 芯片确认活着**。

LED2 比"屏亮不亮"硬得多——屏不亮还可能是电流、灰度、LED 板的事，
而 LED2 亮说明「链路通 + 芯片收到了我们的指令 + CRC 那套推断是对的」三件事同时成立。

出 bit：
```bash
cmd.exe /c "cd /d D:\claude_workspace\pov3d\zynq_pov\icnd2260 && \
  call C:\Xilinx\Vivado\2024.2\settings64.bat && \
  vivado -mode batch -source tools\build_bit.tcl -tclargs lvds"   # 或 ttl
# 产物 build_bit/icnd2260_lvds.bit
```

---

## 分支表

| 分支 | 与主线的差别 | 回答什么问题 | 前置条件 |
|---|---|---|---|
| **`feature/icnd2260-lvds`**（主线） | — | 全套 mini-LVDS 3 通道，41.7MHz 位时钟 | BANK 33 已改 2.5V |
| `feature/icnd2260-ttl` | 默认出 TTL 版 bit | **不用改电阻就能先试**：链路/电源/时序有没有大问题 | 无（3.3V 直接跑） |
| `feature/icnd2260-lvds-phase270` | `CLK_PHASE = 270.0` | 采样相位反了吗？（这是最可能的失败原因之一） | 同主线 |
| `feature/icnd2260-lvds-nocrc` | `VID_CRC = 0` | 图像数据的 per-chip CRC 是不是我推错了？ | 同主线 |
| `feature/icnd2260-lvds-slow` | `CLK_DIV = 48` + XDC `BITCLK_NS 48.0` | 是速率问题还是协议问题？20.8MHz 位时钟 | 同主线 |
| **`feature/icnd2260-lvds-debug`** | 加 VIO 调试核（`DEBUG=1`） | **实时读 frame_cnt / ACK 回包，实时 poke 寄存器** —— 扫帧率参数不用重出 bit | 同主线 |

`-debug` 那个不是二分用的变体，是**验证平台的正式形态**：没有它就只能盯两个 LED，
读不出实际帧率、也改不了寄存器。测帧率上限见 [`04_fps_sweep.md`](04_fps_sweep.md)。

## 建议顺序

```
电阻还没换 ────────► ttl 分支          （验电源/EN/ACK/链路基本面）
                        │ LED2 亮？
                        ├─ 亮 → 换 R13 → lvds 主线
                        └─ 不亮 → 先查电源、LVDS_EN 接法、ACK 是否接通

lvds 主线 ─── LED2 不亮 ──┬─► phase270   （相位）
                          ├─► slow       （速率）
                          └─► nocrc      （CRC 推断）
```

⚠ **一次只换一个分支**。三个变体各自只改一个变量，混着改就失去二分的意义。

## 每个分支具体改了哪一行

`feature/icnd2260-lvds-phase270`
```verilog
// rtl/icnd2260_lxb_lvds_top.v
parameter real CLK_PHASE = 270.0;   // 主线是 90.0
```

`feature/icnd2260-lvds-nocrc`
```verilog
// rtl/icnd2260_lxb_lvds_top.v
parameter integer VID_CRC = 0;      // 主线是 1
```

`feature/icnd2260-lvds-slow`
```verilog
// rtl/icnd2260_lxb_lvds_top.v
parameter integer CLK_DIV = 48;     // 主线是 24
```
```tcl
# xdc/lxb_icnd2260_lvds_pins.xdc  —— 这两个必须同时改, 否则时序约束是假的
set BITCLK_NS 48.0
```

`feature/icnd2260-ttl` 只改 `tools/build_bit.tcl` 的默认变体，RTL 与主线相同。

## 还没做的变体：单通道

`tools/gen_reg_defaults.py` 已经能生成单通道的寄存器表
（`icnd2260_regs_lvds1.mem`，`0xb4[5:4]=00`），但**数据通路没做**：
按手册 §5，单通道模式下 D0 要串行发 `R#0 G#0 B#0 R#1 G#1 B#1 …`
（每像素 3 个字连发），而现在的序列器是「每 lane 每拍一个字」。
要做这个变体得改 `icnd2260_seq` 的载荷源，不是改个参数的事。
若三通道全试完还不通，再考虑。
