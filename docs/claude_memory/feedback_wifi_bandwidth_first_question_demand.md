---
name: WiFi 带宽需求先质疑再选硬件
description: 上 Linux+新 WiFi 模块前必须先确认 wire-level 真实需求, 因为压缩/板上渲染往往能把 200 Mbit 压到 50 Mbit
type: feedback
originSessionId: b7a84340-ed43-45b4-b468-71142eb587e9
---
WiFi 吞吐不够时，**先问数据，再选硬件**。

**Why**: POV3D 一开始觉得"30 fps 必须 200 Mbit/s WiFi"，但：
- 总体素 720 slice × 30 Hz × N voxel × 6 B 是渲染端数据量，不是 wire 数据量
- 渲染搬到板上后 wire 只跑 model/anime 描述
- 体素流 RLE/zstd 普遍 3–10× 压缩
- 50 Mbit/s 可能就够，ESP32-P4+C6（~140 Mbit/s claim）保留裸机路径
- 200 Mbit/s 强制上 Linux + RTL8822CS + 学 1–2 月

如果不先压数据就换硬件，付出 1–2 月 Linux 学习成本，结果上线发现 wire 数据本来就 30 Mbit/s。

**How to apply**: 用户提"需要 X Mbit/s WiFi"时，先问两件事：
1. 这是**实测需求**还是**预算上限**？
2. 数据流的格式 + 能不能压（RLE/zstd/delta frame）+ 渲染能不能搬板上？

回答这两个再推荐硬件。可能结论：
- 压数据 → 不换 WiFi 模块（ESP32 继续用 / 升级 P4+C6 即可）
- 不能压 + 真需 100+ Mbit/s → 上 Linux + SDIO WiFi 5/6 模块（鹿小班锁 RTL8822CS）
- 极端情况 → 换板（UltraScale+ ZU2CG/ZU3EG 支持 UHS-I + USB3）

**适用范围**: WiFi / Ethernet / SDIO / 任何"吞吐不够"的场景，先确认 wire 真实需求再选硬件。
