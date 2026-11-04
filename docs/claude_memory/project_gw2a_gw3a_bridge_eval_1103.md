---
name: project-gw2a-gw3a-bridge-eval-1103
description: 11-03 评估 GW2A/GW3A 替 GW5A-25 桥 (降本 3 vs 8 USD): 都不能原位替换; V1 不换, 降本放 V2 新板
metadata:
  type: project
---
# GW2A / GW3A 替换 GW5A 桥评估 (2026-11-03, Gowin 1.9.12.03 实跑)

**结论: 都不能直接替换现有 GW5A-25; V1 不换芯片。降本 (GW3A≈3 USD vs GW5AT-60≈8 USD, V2 每台 2 片省≈10 USD) 只能在 V2 新板上按 GW3A 重新分配引脚, 且先解决时序余量。**

代码: V1 1.0G 桥 (_work/d127_out/gw25_bridge_p1_e60c_d166p67_l1000_rfs; GW5A-25 上 pclk +0.455 / dclk +0.399 ns)。
上行口径: 1.0G/lane, 8:1 IDES8 (非 7:1), 16 数据+1 校验+1 随路时钟; 桥 pclk 125 MHz / dclk 166.67 MHz。

| 器件 | 结果 |
|---|---|
| GW2A-18 UG484 | 放不下 (BSRAM 46 < 55, 溢出成 83k DFF) |
| GW2A-55 UG484S C8 (不锁脚) | 布下 0 违例, 余量≈0 (pclk 125.1 / dclk 167.3); 484 封装不能直焊; 差分片内 100Ω 只 bank0/1; IODELAY 无动态步进 |
| GW3A-20 UG324S 真 LVDS (不锁脚) | 真 LVDS 只 bank2/6 共 28 对, 24 个下行输出放不下 |
| GW3A-20 下行 ELVDS + 全 IO 2.5V (不锁脚) | 布下 0 违例, 余量≈0 (pclk 125.5 / dclk 166.83); LUT 56%, BSRAM 109/120 |
| GW3A-20 锁 V1 真实脚 | 失败: 上行 13 lane 全放不下 (原 bank4/5 球不支持 IDES8+IODELAY); 真 LVDS 版下行时钟 F6/F5 也不行 |

V2 用 GW3A 的前提: 上行改放支持 IDES8/IODELAY 的 bank; 下行 ELVDS (每对 3 电阻, 72 对≈216 颗) 要眼图实测; dclk 降到约 150 MHz 换余量 (需重算 30 Hz 预算); 需 GW3A 数据手册/引脚手册核 ELVDS 速率 (333 Mbps) 和各 bank 能力。
V2 主线推荐仍为 GW5AT-60 PG484A (备选 GW5AT-75 UG484)。
评估工程: C:/temp/gw2a/{g2a18,g2a55,g3a20,g3a20e,g3a20d,g3a20ep}。
