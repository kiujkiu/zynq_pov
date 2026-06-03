---
name: ESP32-C5 WiFi 吞吐基线 + HT40 突破 (办公室 undef AP)
description: C5 BW20 / HT40 两档实测 TCP/UDP RX+TX 数字, 及 11n-only 切换方法
type: project
originSessionId: 8002516f-20d0-4b20-8757-a51821fbfd7d
---

## 关键认识
**C5 WiFi 6 (HE) 模式只支持 HE20 (20MHz) — 单流硬件限制**。MCS 表只列 HT20/HT40/HE20/VHT20，没有 HE40/HE80。要突破 BW20 瓶颈**必须切到 11n only 模式**用 HT40。

## 实测数字 (办公室 undef AP, 60s×N iter avg, Mbps)

| 模式 | TCP RX | TCP TX | UDP RX | UDP TX |
|------|--------|--------|--------|--------|
| 2.4G ch1 BW20 (HE20) | 18 | 18 | 30 | 30 |
| 5G ch149 BW20 (HE20 默认) | 28.96 | 29.05 | 41.48 | 48.37 |
| **5G ch149 BW40 (11n only)** ⭐ | **39.53** | **35.19** | **70.57** | **68.35** |

提升路径：
- 2.4G HE20 → 5G HE20: **+60%** (信道质量)
- 5G HE20 → 5G HT40: **+38% TCP / +42% UDP** (信道宽度×2)
- 2.4G → 5G HT40 总收益: **TCP 2.2×, UDP 2.3×**

**HT40 是 C5 在这个 AP 下的真实上限**：TCP ~40 Mbps, UDP ~70 Mbps（理论 PHY 150 Mbps 单流，27%/47% 利用率）。

**2.4G 在办公室 AP 上无法 HT40**：ch1 BSSID 只广播 BW20(NONE)，强制 BW40 协商失败掉到 3 Mbps、UDP 丢 98%。家用 AP 2.4G 多数允许 HT40，但即便能开也不如 5G HT40 快。

## 切 HT40 的代码 (必须在 esp_wifi_start 之后，BAND_AUTO 模式用 plural API)

```c
wifi_cmd_wifi_init(NULL);
wifi_cmd_wifi_start();              // ← 先 start
esp_wifi_set_ps(WIFI_PS_NONE);

wifi_protocols_t protos = {
    .ghz_2g = WIFI_PROTOCOL_11B | WIFI_PROTOCOL_11G | WIFI_PROTOCOL_11N,
    .ghz_5g = WIFI_PROTOCOL_11A | WIFI_PROTOCOL_11N,   // 丢 ac/ax
};
esp_wifi_set_protocols(WIFI_IF_STA, &protos);

wifi_bandwidths_t bws = { .ghz_2g = WIFI_BW40, .ghz_5g = WIFI_BW40 };
esp_wifi_set_bandwidths(WIFI_IF_STA, &bws);
```

**关键坑**：`esp_wifi_set_protocols/set_bandwidths` 必须在 `esp_wifi_start` **之后**调，放前面返回 OK 但 silently 不生效。在 BAND_AUTO 模式下必须用 plural API (`set_protocols`/`set_bandwidths`)，单数版会报 `ESP_ERR_NOT_SUPPORTED 0x106`。

## office `undef` AP 拓扑
- 多 BSSID 同 SSID：ch1/ch6 (2.4G), ch149/ch157/ch161 (5G)
- 5G 给 HT40 OK (40U ABOVE), 2.4G 只给 HT20 (办公室避邻居)
- C5 强制 5G+ch149：`sta_connect undef <pass> -n 149`

## XIAO repo (limengdu) 对比
- Seeed 公布 5G TCP 27-29 Mbps / UDP 50 Mbps — 跟我们 **HE20 数字一致**，他们没测 HT40
- 我们 HT40 模式 TCP 39 / UDP 70 **超过 Seeed 30-40%**

## 已固化到固件
`D:\esp-idf\examples\wifi\iperf\main\iperf_example_main.c` 已 patch HT40 代码，开机自动生效，`sta_connect` 后直接走 HT40 11n 5G。测试脚本 `_run_ht40.py` 在同目录。

## POV-3D 数据流速率定位
| 应用流量 | 推荐 |
|---------|------|
| < 15 Mbps | 2.4G 就够（穿墙好） |
| 15-35 Mbps | 5G HE20 默认 |
| 35-65 Mbps | **5G HT40 (POV-3D 走这个)** |
| > 70 Mbps | C5 触顶，换芯片（裸机无解，参见同会话讨论 RTL8821CS）|

**Why:** 旋转 POV-3D 屏必须无线传输，要在 C5 现有硬件下榨出最大带宽。BW20→HT40 这条路把 TCP 从 30 涨到 40 Mbps，UDP 从 48 涨到 68 Mbps，多数 POV 应用够用。

**How to apply:** 任何 ESP32-C5 (或同代 11ax 芯片) WiFi 吞吐低于 30 Mbps，先确认是不是在 HE20 模式 (`wifi_config_query sta` 看 phymode/CBW)；切 11n only + BW40 通常能 +40-70%。BAND_AUTO 模式记得用 plural API + 放 start 之后。
