---
name: reference_icnd2260_display_rate_model_validated
description: 芯片显示帧率 = GCLK/(扫描行x刷新分组xLine_len), GCLK = DCLK x P/M x N; 出厂 74 分组实测约 1450 fps 与预测 1444 差 2%; 改 0x00=0F3C + 0x06=AA48 后能力 13355 fps, 瓶颈移交链路
metadata:
  type: reference
---

# 显示帧率的模型, 已上板验证 (2026-09-02)

## 公式

```
显示帧率 = GCLK / (扫描行数 × 刷新分组 × Line_len)
GCLK     = DCLK × (P/M) × N

扫描行数 45           Line_len = 0x03 = 0x0034 = 52
刷新分组 = 0x00[15:8] + 1      (出厂 0x493C ⇒ 0x49=73 ⇒ 74 组)
N        = 2^0x00[5:4]         (出厂 0x3C ⇒ [5:4]=3 ⇒ N=8)
P        = 0x06[4:0]           M = 0x06[8:5] × 4 (mini-LVDS)
                               【手册明确·docs/pg.txt:1575-1582, :2067】F_GCLK = DCLK × P/M
```

## 实测验证

| | 0x00 | 0x06 | GCLK | 预测 fps | 实测 |
|---|---|---|---|---|---|
| 出厂 | 493C (74组, N=8) | AA44 (P/M=0.5) | 250 MHz | **1,444** | **~1,470** (差 2%) |
| 改后 | **0F3C** (16组, N=8) | **AA48** (P/M=1.0) | 500 MHz | **13,355** | 吃下发送的全部 4,000 fps |

⚠ GCLK 上限【手册明确·docs/ds.txt】**600 MHz**, 500 未超。

## 量法(唯一可行的)

图案 `dbg_pat_mode=7`(帧相位条纹, 40 列切 8 条, 第 k 帧只亮第 k mod 8 条)
+ **短曝光拍照**。亮起的条数 = 曝光窗口内芯片显示的不同帧数。
🔴 **必须 A/B 对比且发送帧率相同**, 这样未知的曝光时间在比值里被约掉。
实测 A(2.5 相位) vs B(6 相位), 而且 **A 的曝光更长却捕获更少** —— 方向与混淆项相反,
所以定性结论不受曝光不一致影响(定量则需要同一套相机设置)。

## 结论: 瓶颈从显示移交给链路

```
显示侧  16 分组 + P/M=1.0            → 13,355 fps  ✅ 够 10k
链路侧  62.5 MHz 单颗 (15,270 拍/帧) →  4,093 fps  🔴 现在卡这
        喂满 10k 需 DCLK ≈ 152.7 MHz, 而 155.36 MHz 实测芯片收不了(屏全黑, FPGA 侧完好)
```

⇒ 下一步是**二分链路上限**(142.9 / 125 / 100 / 83.3 MHz 的 cas2 bit 均已编好),
  且 **WNS 一律忽略** —— 见 [[feedback_wns_was_a_mirror_of_my_own_margin_knob]]。

相关: [[reference_icnd2260_gclk_pm_and_link_ceiling]] [[feedback_time_average_cannot_measure_display_rate]]
[[project_icnd2260_single_chip_fps_pivot]]
