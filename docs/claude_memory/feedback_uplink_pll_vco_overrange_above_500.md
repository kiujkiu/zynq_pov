---
name: feedback_uplink_pll_vco_overrange_above_500
description: 🔴 uplink_pll.v 把 CLKC0_DIV 写死成 4 ⇒ sclk > 500MHz 时 VCO 超 2000 上限; 2026-09-18 跑 uplink_tx/build.sh 300 (=1200Mbps) 时 VCO=2400, 那份位流 PLL 锁不住; 时序数据仍可参考(fabric 逻辑与 PLL 无关); 自检只有 $display, 综合不看 ⇒ 静默通过
metadata:
  type: feedback
---

# `CLKC0_DIV` 写死成 4，超过 500 MHz 就静默超规格 (2026-09-18)

## 事实

`dr1v90/uplink_tx/rtl/uplink_pll.v` 里：

```verilog
.CLKC0_DIV (4),        // VCO = sclk × 4
.CLKC0_CPHASE (3),     // = CLKC0_DIV - 1
.CLKC0_DUTY_INT (2),   // = CLKC0_DIV / 2
```

而 **DS1200 V1.0 表 3-18 要求 FVCO ∈ [800, 2000] MHz**。于是：

| pclk | sclk | VCO = sclk×4 | |
|---|---|---|---|
| 200 MHz | 400 | 1600 | ✅ 09-03 实跑的那档 |
| 250 MHz | 500 | 2000 | ⚠ 正好贴上限 |
| **300 MHz** | **600** | **2400** | 🔴 **超 20%** |

2026-09-18 为回答「1.2 Gbps 能不能发」跑了 `./build.sh 300`，**TD 一声不吭地编到 bit**。
那份位流真烧下去 PLL 锁不住。

## 为什么没被拦住

`uplink_pll.v` 里**有**这条自检，但它是 `initial $display`：

```verilog
if (VCO < `DEV_VCO_MIN || VCO > `DEV_VCO_MAX)
    $display("[uplink_pll] 🔴 VCO=%0d MHz 超出 ...");
```

`initial` 块**只有仿真跑得到，综合器不看**。而这个探针工程从来只综合不仿真
⇒ 这条自检在实际使用路径上等于不存在。

📌 一般形状：**写在 `initial $display` 里的参数自检，对"只综合不仿真"的工程是死的。**
要拦住必须用能在 elaborate 阶段炸的手段（越界时例化一个不存在的模块名，
就像 `dev_prim.vh` 结尾那个 `UPLINK_ERROR_no_device_family_selected` 的做法）。

## 结论的影响范围

- 🟢 **09-03 的 200 MHz 结论不受影响**（VCO 1600 合法）。
- 🟢 **09-18 那次 300 MHz 的时序数据仍可参考** —— 违例路径全在 fabric 逻辑上
  （最差那条是 26 位心跳计数器的 19 级进位链），与 PLL 配置无关。
- 🔴 但**不能拿那份 bit 上板**。

## 修法（`lvds_b2b` 已经这么做了）

按「取**最大**的 DIV 使 VCO ≤ 2000」自动选，而不是写死：

| sclk | DIV | VCO | 动态相位细调步长 = T_VCO/8 |
|---|---|---|---|
| 400 | 5 | 2000 | 62.5 ps |
| 500 | 4 | 2000 | 62.5 ps |
| 600 | 3 | 1800 | 69.4 ps |

选**最大**的 DIV 而不是随便一个合法值，是因为 **VCO 越高，动态相移的步长越细**
（UG1206 p.22：每步 = 1/8 个 VCO 周期），扫眼的分辨率直接跟着走。
`CLKC0_CPHASE` 和 `CLKC0_DUTY_INT` 是 `DIV-1` 和 `DIV/2`，必须跟着一起变，
写死成 3 和 2 也是错的。

实现见 `dr1v90/lvds_b2b/rtl/b2b_pll.v`。

相关: [[project_dr1_uplink_tx_probe]] [[project_pov3d_lvds_b2b_bench]]
