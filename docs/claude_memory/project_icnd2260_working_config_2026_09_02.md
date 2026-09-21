---
name: project_icnd2260_working_config_2026_09_02
description: 2026-09-02 收工的完整可用配置 — 单颗 ICND2260 40x45, DCLK 166.67MHz, 实测 11,000 fps, GCLK 500MHz, 色深 12.0 位; 含全部寄存器/构建命令/瓶颈分析
metadata:
  type: project
---

# 📌 单颗 ICND2260 可用配置全表 (2026-09-02 收工)

## 一、最高帧率配置 —— **实测 11,000 fps**

### 构建
```
tools\build_bit_dbg.tcl -tclargs 6 lvds casc1 f167 noprobe
产物  build_dbg_cas1_f167_np/icnd2260_lvds_dbg_div6_cas1_f167_np.bit
时序  WNS = -0.470  (= MARGIN 基线, **零真实退化**)
```

### 时钟
| | | |
|---|---|---|
| 输入 | `clk50` | 50 MHz |
| VCO | `VCO_MULT_X8=160` | **1000 MHz(原生)** |
| DCLK(位时钟) | `CLK_DIV=6` | **166.67 MHz** |
| GCLK | `DCLK × P/M × N` = 166.67×0.375×8 | **500 MHz** (上限 600 ✅) |

🔴 **优先用原生 VCO 1000 的整数分频档。** 为凑 155.36MHz 把 VCO 拉到 1087.5 反而付时序代价:
`166.67MHz WNS=-0.470` vs `155.36MHz WNS=-0.695`。

### 芯片寄存器 (相对 `rtl/icnd2260_regs_vendor.mem` 出厂表的改动)
```
0x00 = 0F3C    刷新分组 16 (出厂 493C = 74), N=8, 低字节 3C 不动
0x01 = 0020    刷新倍率 F=32                (出厂值, 未改)
0x06 = AA43    P=3, M字段=2 ⇒ M=8, P/M=0.375
0x2d = 223F    红色 IREF=0.4mA igain=15 (拉满, 仅测暗端时用; 常规用出厂 2215)
```
🔴 **`0x06` 必须随 DCLK 调**, 否则 GCLK 超 600:
```
 62.5MHz → AA48 (P/M=1.0)  GCLK 500
142.9MHz → AA44 (P/M=0.5)  GCLK 571
155.4MHz → AA43 (P/M=0.375) GCLK 466   (用 AA44 会到 621, 超限)
166.7MHz → AA43            GCLK 500
```

### 数据通路
```
CASCADE   1 (只喂第一颗; 下游会显示残帧噪声)
          若要整屏只剩第一块 ⇒ CASCADE=2 + 第二颗全黑(--pad-chips 1), 链路速率减半
          ⚠ 2026-09-14 E104(EG4) `PATT=1 CASCADE=1`: 9 块**都是蓝为主 + 点状杂点**, 没有一块整块纯蓝(用户看屏)
            ⇒ 后 8 块很可能也在显示 slice 0 的蓝; 候选(未验): VHEAD「级联数−1」=0 让每颗都吃开头那片;
            点点原因未定; 见 `dr1v90/eg4_2260_e104/README.md` §6.53
帧内容    14,755 拍  (关读探针后; 未关是 15,270)
          = 数据 14,400 (1800像素×16bit÷2 DDR, **协议硬地板**) + 开销 355
READ_PROBE_FR = 0, QUIET_CYCLES = 0   (`noprobe` 关键字)
```

## 二、性能与瓶颈

```
实测发送     11,000 fps 【实测·FPGA 侧 1 秒计数器】
链路上限     166.67e6 / 14,755 = 11,296 fps   ← 🔴 **瓶颈在这**
显示能力     500e6 / (45×16×52) = 13,354 fps   (富余 18%)
理论天花板   170MHz(手册 DCLK 上限) / 14,755 = 11,522 fps
色深         16 × 32 × 8 = 4,096 级 = **12.0 位**  ⚠【推断】
```

**已验证通过的链路频点**: 62.5 ✅ / 100 ✅ / 125 ✅ / 142.9 ✅ / 148.2 ✅ / **166.67 ✅**
(155.36 早先记为"全黑"**已作废** —— 那次读探针开着让 PLL 每秒失锁 300 次, 且 GCLK 超限)

## 三、两条核心公式

```
帧率 × 刷新分组 = GCLK / (扫描行45 × Line_len52) = GCLK / 2340
   【已验证】预测 1,444 fps 对上实测 ~1,470 (差 2%)

灰度级 = 刷新分组 × F × N
   ⚠【推断】未上板验证。验法: 数斜坡起点全黑的 LED 颗数
   (见 [[feedback_count_dark_leds_to_measure_quantization]])
```

由此得**帧率 ↔ 色深兑换表**(GCLK 顶 600 时 `帧率 × 分组 = 256,410` 为常数):
| fps | 分组 | 位深 |
|---|---|---|
| 5,000 | 51 | 13.7 |
| 10,000 | 25 | 12.6 |
| 11,133 | 23 | 12.5 |

**帧率翻一倍只掉 1 位色深** —— 交易极其划算。

## 四、明天接着做

1. 色深公式验证(数暗端全黑 LED 颗数, 74 组 vs 16 组应为 3~4 vs 16)
2. "芯片是否每帧都显示" —— 固定机位重拍或上工业相机/光电二极管
3. DCDC 需重启才恢复的故障 ([[feedback_lightboard_dcdc_needs_power_cycle]])
4. 供应商三问: `VHEAD[23:20]` 还支持哪些值 / 接收端 setup-hold 最小值 / ACK 接没接

相关: [[project_icnd2260_9404fps_measured]] [[reference_icnd2260_display_rate_model_validated]]
[[reference_icnd2260_gclk_pm_and_link_ceiling]] [[feedback_wns_was_a_mirror_of_my_own_margin_knob]]
[[reference_icnd2260_8bit_pixel_rejected]] [[reference_icnd2260_scans_by_column]]
