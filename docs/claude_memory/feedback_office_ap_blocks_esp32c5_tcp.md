---
name: ESP32-C5 反复 reason 203/204 = 密码错 (假装"AP 阻塞")
description: pov_bridge sdkconfig 密码占位 'undef' 没换成 'undefoffice1010', 看起来像 AP 阻塞但其实是 4-way handshake 直接拒
type: feedback
originSessionId: 25cdb314-8481-406a-9724-5d3798a00293
---

**2026-05-14 翻案**: 之前以为 office "undef" AP 阻塞 ESP32-C5 TCP, **实际是 `sdkconfig.defaults` 里 `CONFIG_POV_WIFI_PASSWORD="undef"` 没替换成真密码 `"undefoffice1010"`**, 导致 EAPOL 4-way handshake 必败 → reason 203/204/205 循环。修密码后:
- iperf example 5G HT40 ch149 TCP ~30 Mbps 直接通
- pov_bridge `WIFI_BAND_MODE_5G_ONLY` + ch=161 5G undef rssi -34 connect OK, TCP :8888 listening OK

## 关键诊断教训

**密码错的 disconnect reason 跟 AP 阻塞**长得**一模一样**:
- reason 4 (ASSOC_EXPIRE)
- reason 203 (AUTH_FAIL)
- reason 204 (ASSOC_FAIL)
- reason 205 (HANDSHAKE_TIMEOUT, EAPOL)
- reason 2 (PREV_AUTH_NOT_VALID, 重连时残留)

加上 ICMP/ARP 由 AP 转发, ping 通但 TCP 不通的现象也吻合 "密码错只完成 L2 attach 没完成 L3 EAPOL", 容易误诊成 "AP 做 DHCP-snooping"。

## 排查 checklist (下次 reason 203/204 先做)

1. **grep sdkconfig 密码值**: `grep PASSWORD sdkconfig sdkconfig.defaults` — 看是不是占位符没换
2. **iperf example 拿同 SSID/密码做对照**: `sta_connect <ssid> <pass>` 手输密码, 一对就排除密码因素
3. 都连不上才考虑 AP 策略/HT40 不兼容/PMF mismatch

## 也别忘的: BAND_AUTO + 显式 channel hint

pov_bridge 改 5G 时只设 `WIFI_BAND_MODE_5G_ONLY` + 无 channel hint → reason 4 后 reason 203 — scan 撞错 BSSID。加 `.channel = 149` + `WIFI_ALL_CHANNEL_SCAN` 提示后连上 (最终 AP 给的是 ch161, 但 hint 帮 STA 起步)。

**Why:** 浪费了 2026-05-12/13 两天调 WiFi 桥, 写了一堆 "AP 阻塞" 推测, 实际是 sdkconfig 密码占位符。这种错误 esp_wifi log 不会直接说 "password wrong", 全是 generic reason code, 容易把人引偏。

**How to apply:** 看到 ESP32 反复 ASSOC_FAIL / HANDSHAKE_TIMEOUT, **永远先确认密码字符串**, 然后再怀疑 AP 策略。手输 CLI 测一遍是最快的确认手段。WiFi 桥路径活的, 没死。
