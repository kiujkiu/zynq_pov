---
name: project_pov3d_ddr_eta_measured_0950
description: 🎯 2026-09-03 实测 DDR 读效率 η = 0.950 — "切片不落 DDR"拓扑 GO 且留 ≥20% 余量; 墙③⑧ 倒; 但**原版 IP 不预取会超线(115 µs > 110.6)**, hls::burst_maxi 提前 2 列是必须改动
metadata:
  type: project
---

# η = 0.950 实测, 直供拓扑 GO (2026-09-03, 鹿小班 XC7Z020)

量具 `zynq_pov/eta_test/`(只读变体 `pov_eta_rd`, PL 硬件计数器 `eta_mon.v`, 纯 xsdb),
bit `build_eta_rd/eta_rd.bit`, 命令 `bash tools/eta_all.sh run rd 6`。结果全文 `build_eta_rd/eta_result_*.txt`。
🔴 上板第一次因 xsdb 拦截 PL AXI 地址失败("PL AXI slave ports access is not allowed"), `mrd/mwr` 全加 `-force` 后通过。

## 决定性的那一行

```
DUAL  两路并发, 相位 0 + 151(正交), 预取 2 列, 各 603 片:
   ip0 81.83 µs/片   ip1 81.93 µs/片   两路同时忙 100%
   合计 DDR 读 2,026 MB/s  ⇒  η = 2,026 / 2,133 = **0.950**
   判据 worst 81.9 ≤ 92.2 (110.6 − 20%)  ⇒  **GO with ≥20% margin**
```

## 全矩阵(每行 XOR 均与主机算的一致 ⇒ 读的是真数据)

| 行 | µs/片 | MB/s | η | 说明 |
|---|---|---|---|---|
| CAL_SEQ 单路连续读 | 70.26 | 1180 | — | 98% 单 HP 口理论值, **量具对** |
| CAL_STRIDE 90° 最散 | **70.26** | 1180 | — | 🔴 **与连续读一字不差, DDR 不在乎访存散不散** |
| CAL_PF0 单路不预取 | 109.85 | 755 | — | = 原 IP 行为, 单路就贴线 |
| SINGLE 单路整圈 pf2 | **69.12** | 1200 | — | **= csynth 69.1**, 预取后达理论值 |
| **DUAL pf2** | **81.9** | 2026 | **0.950** | ✅ 决定性 |
| DUAL_SAMEPH 同相位 | 82.9 | 2001 | 0.938 | 同相位略差, 仍过 |
| **DUAL_PF0 不预取** | **115.21** | 1440 | 0.675 | 🔴 **超 110.6, 原版 IP 会失败** |
| DUAL_PF4 / PF6 | 81.8 | 2026 | 0.950 | 与 PF2 相同 ⇒ **预取 2 列就够** |
| DUAL_FACEB 面B几何 | 81.9 | 2026 | 0.950 | 面 B 无差别 |

## 三条硬结论

1. **η = 0.95, 远超 0.70/0.84 阈值。** 昨天"有效 = 峰值 × 0.6~0.7"那个假设**过于悲观**, 实际 0.95。
2. 🔴 **C2 是生死线**: 原 IP 每列只提前 8 拍发读请求, 每列吃一次完整 DDR 延迟, 白丢 36%;
   双路下 115.2 µs **超线**。`hls::burst_maxi` 提前 **2 列**是必须改动(4/6 列无额外收益)。
   改法见 `eta_test/hls/pov_eta_rd.cpp`(pf_cols 参数化)。
3. **访存模式不影响 DDR 效率**(CAL_SEQ = CAL_STRIDE) ⇒ 昨天担心的"页效应最坏角度慢 25%"没有发生。

## 余量的正确读法

测试让 IP 满负荷(81.9 µs/片)。真实系统每片只需 110.6 µs, IP 空闲 26%:
```
真实负载 = 2,026 × 81.9/110.6 = **1,500 MB/s** = 峰值 70%   (与昨天算的一致)
剩余     = 2,133 − 1,500 = **633 MB/s**   留给 scatter 写/lz4/CPU(合计 0.1~0.33)  ✅
```

## 墙的状态更新

```
① 屏侧物理层  ✅ 09-02 实测      ③ DDR 带宽  ✅ **09-03 实测**     ⑧ 渲染 IP  ✅ 随③
② ④ 板级 IO   ✅ 桥架构纸面过    ⑥ DDR 容量  ✅ 随直供解
⑤ 无线链路    🔴 未动            ⑦ 色深      ⚠ 待验             ⑨ 亮度     🔴 未动
```
**V1 出局(偏心 13.4mm)无所谓 —— η 高到不需要退路。**

## 下一步
1. 把 pf=2 预取合进正式的 `pov_slice_v2`(C2)
2. 上板跑 ppbuf(乒乓直供, 昨天已做出, 仿真 PASS 未上板)
3. ⑤ 无线链路 / ⑦ 色深验证 / ⑨ 亮度

相关: [[project_pov3d_ddr_two_walls_one_move]] [[project_pov3d_walls_status_2026_09_03]]
[[project_pov3d_bridge_architecture]] [[project_icnd2260_working_config_2026_09_02]]
