---
name: project_pov3d_voxel_table_payload_measured
description: 2026-09-03 实测「传体素表」链路的真实载荷 — 8 个真实 glb 填满 192×216×192 + lz4-HC12, 最重的 bonsai 220 KB/帧 = 15fps 26 Mbps(余量 4.2×), 病态上界(整圆柱壳随机色)58.5 Mbps; 墙⑤ 纸面倒
metadata:
  type: project
  date: 2026-09-03
---

# 体素表载荷实测 (2026-09-03) —— 08-27 判决第 3 项终于量了

**问题**: 无线墙⑤ 一直按**未压缩 6 B/体素 × 估计 15-22 万体素** 算 ⇒ 5fps 36 / 15fps 108 Mbps,
15 fps 擦着 110-125 Mbps 持续吞吐的线。压缩比从没量过, 5 和 15 之间就一直纠结。

**方法** (`zynq_pov/tools/glb_voxel_payload.py`, 纯 numpy+pillow, 2.6 s/模型, 不用板子):
真实 glb (`aibrain-app/glb_models/`) → 世界坐标 → 等比填满 192×216×192 → 三角形按面积撒点
(k=4/体素², k=8 只多 1.9% 已收敛) → 取整去重 → 纹理×factor×half-lambert → RGB565 →
按索引排序, **索引差分 varint 一段 + 颜色一段分开压** → lz4 block HC12 (= povstream 生产口径)。

## 结果

| 模型 | 体素 | lz4-HC12 B/帧 | B/体素 | @5fps | @15fps | @30fps |
|---|---|---|---|---|---|---|
| **bonsai**(开机默认, 最重) | **136,046** | **220,272** | 1.62 | 8.8 M | **26.4 M** | 52.9 M |
| Dino | 48,633 | 92,071 | 1.89 | 3.7 | 11.0 | 22 |
| Groot / walking | 40-42 K | 75-78 K | 1.8 | 3.0 | 9.0-9.3 | 18 |
| Engine / Robot / Skeleton | 22-36 K | 42-44 K | 1.2-1.9 | 1.7 | 5.1-5.3 | 10 |
| steve(大色块) | 48,942 | 12,322 | 0.25 | 0.5 | 1.5 | 3 |
| 病态上界: 整圆柱壳 + 随机色 | 241,442 | 487,604 | 2.02 | 19.5 | **58.5** | 117 |

- 人物类模型瘦, 填满圆柱后只有 2-5 万体素; 只有枝叶散开的 bonsai 到 13.6 万(和早先"13-22 万"估计的下沿吻合)。
- **颜色流是大头**: 真实纹理 lz4 只压 1.4-1.8×(≈1.2-1.4 B/体素); 索引流差分 varint 后 ≈0.4 B/体素。
  经验公式: **≈1.7 B/体素/帧** (随机色极限 2.0)。
- 布局很关键: 未排序 raw 6B 布局 lz4 只有 1.3×; 排序+差分+分流 3.7×。**索引必须排序、颜色必须单独一段**。
- 旧点云 `anime_points.bin` 只有 ±30/40/20 的坐标(老面阵量化, 10 万点塌成 2 万体素), `globe` 是规则图案(压 20-38× 不可信) —— 都**不能**当样本。

## 结论

- **墙⑤ 纸面倒**: 15 fps 最重真实内容 26.4 Mbps, 对 110 Mbps 持续 **余量 4.2×**; 连 30 fps 也 2.1×。
  病态上界 58.5 Mbps @15 仍 1.9×。**5 vs 15 不用再纠结, 内容率按 15 起步**。
- 无线只剩两件事: 专用 AP + 固定 5G 信道(消 300-840 ms 停顿, 零成本); iperf+有线服务端复测持续吞吐
  ([[reference_dr1_wifi_ceiling_unestablished]] 那个从未确立的天花板)。**换链路物理层的收益仍为零** ([[reference_wireless_link_alternatives]])。
- 前提是 direct-feed 拓扑(切片不进 DDR、只传体素表), 已由 [[project_pov3d_ddr_eta_measured_0950]] 验证 η=0.95。
- 主控解压 lz4 220 KB/帧 × 15 = 3.3 MB/s, 对 Zynq 单核 lz4 解压 (>200 MB/s) 忽略不计; PL 直写 bank 通路已有。

关联: [[project_pov3d_walls_status_2026_09_03]] [[project_pov3d_final_target_chip_verdict]] [[project_pov3d_ddr_two_walls_one_move]]
