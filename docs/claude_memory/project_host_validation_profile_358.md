---
name: project_host_validation_profile_358
description: 2026-10-10 任务 1.4.2 主机侧验证板口径 (vb358) 离线完成 — povstream --profile vb358 出 VXT1 体素表 (160×180/358 片/RGB565/双面元数据), 2047 路径逐字节不变; 板端 C (vox_scatter + pov_slice_v2 -DPV2_CFG_VB358) 358×2 面全角度对独立浮点参考 PASS; VOXTAB 标志从 bit7 挪 bit8 (撞 3BIT); 切片器列中心比 gas 差半像素待板端定
metadata:
  type: project
---

# 主机侧验证板口径 vb358 (2026-10-10, 任务 1.4.2, 离线, 不碰板)

## 之前有什么
- (a) 渲染→体素表: `zynq_pov/scatter/gen_voxtab.py` (08-05, VXT1 格式) 只在 `feature/voxel-scatter` 分支 / wt-scatter,
  从没合进主分支, 也**没接进 povstream**; 口径 1bit 160×180/360 与 target 192×216/603。
- (b) 体素表→切片: `scatter/vox_scatter.c` (ARM scatter, 增量清理) + `hls_proj/pov_slice_v2.cpp` (纯 C 可编, Q8 LUT 只有 360/603)。
- (c) 推流: `mlkpai_fs03/stream/pc/povstream.py` (PVS1) 只发 2047 切片 (pack_obs 1/3-bit 位平面), 动画源体素格固定 160×180。
- 🔴 撞位: VXT1 设计的 `PVS_FLAG_VOXTAB = 1<<7`, 而 08-20 的 `PVS_FLAG_3BIT` 也是 bit 7 ⇒ **挪到 bit 8** (头 flags 是 u16)。

## 改了什么
- `mlkpai_fs03/tools/pov_profile.py`: profile 表 (2047 / **vb358** / tgt603) + VXT1 编解码 + 显示圆柱裁剪 (半径 82.8 px 外的体素板端永远切不到)。
- `povstream.py --profile vb358`: render 出 `frame_*.vxt` + meta.json(profile 全参数); stream 发 PVS1 `flags=VOXTAB|LZ4, n_slices=0`。
  不给 `--profile` / `--profile 2047` ⇒ 1-bit 与 3-bit 双面渲染输出 md5 与改前逐字节相同 (已验)。
- `fake_board.py` 认 VOXTAB (校验 VXT1 + md5); 回环 8/8 PASS。`protocol.h/.md` (fs03 + dr1v90 板端副本) 补 bit 8 定义。
- `zynq_pov`: scatter/ 合进 `feature/icnd2260-lvds-debug`; `pov_slice_v2.h` 加 `PV2_CFG_VB358` + `pov_slice_v2_lut_358.h`;
  补写一直缺失的 `tools/gen_pv2_lut.py` (对 360/603 旧表逐字节复现); `scatter/vb_slice_all.c` (x86 + aarch64 交叉编);
  `scatter/vb358_e2e.py` (对拍) / `vb358_budget.py` (预算)。

## 验证 (vb358_e2e.py, PASS)
- 几何探针 (满网格每格编码坐标): 面A/面B 最大误差 cheb 0.64 / eucl 0.85 px, **0 列超出 0.5+Q8 上界**; 最近邻命中 92.4%/91.5%;
  面B 参考按"背对背: 垂距取负+手性取反"物理推 ⇒ 证实 phase=179 (=358/2) 正确; y 翻转 ✓; 面B 8 列内外分歧全在网格边沿舍入带内。
- 内容 (立方体×3 帧/螺旋×3/棋盘×2, 跨帧增量 scatter + 裁剪): C 输出 vs 预测 **0 不符**; vs 浮点参考差 2–5% 亮像素, 全部可由 Q8 舍入解释。
- povstream 真产物 (rgbhelix 4 帧): C scatter+切片 vs Python 解码 0 不符。
- Q8 表是 92% 命中的原因: Q10 98.3% / **Q12 99.5%** / Q14 99.8% (纯 Python 模拟)。

## 预算 (vb358_budget.py)
- 载荷 lz4-HC12: 真实 glb 12–175 KB/帧 (bonsai 最重 175 KB = 16.8 Mbps@12fps, 余量 9.4×), rgbhelix 218 KB (21 Mbps, 7.6×),
  病态圆柱壳随机色 533 KB (51 Mbps@12fps, 3.1×) —— 对 159 Mbps 全过。
- DR1M90 切片: 57,600 B/片, 两面 8,592 slice/s, 每面时隙 232.8 µs; PL 显示读 0.495 GB/s 恒定。
  **CPU 切进 DDR**: 12 fps 时 写0.495+读0.495+显示0.495 = 1.48 GB/s = DDR 实测 1.79 的 **83%** (10 fps 74%), A35 估 54 ms/内容帧 ≈ 单核 65%;
  **PL 直供** (pov_slice_v2 读网格直喂显示) 只要 0.495 GB/s = 28%。

## 留给板端 (D6/D16) 的问题
1. 切片在 A35 还是 PL? CPU 路径 DDR 83% 擦线, 推荐 PL 直供。
2. 列中心约定: 切片器 u=px−80, povstream/gas 用 px−79.5 ⇒ 半像素系统差 (平均误差 0.37→0.59 px); 看 2260 板实际轴位, 切片器宜改半像素中心 (Q8 里一行)。
3. 面B 相位 179 只能施加一次: 切片 phase=179 + RTL PHASE_B=0, 或切片 phase=0 + RTL PHASE_B=179, 二选一。
4. mirror_u=1 / 面B 13.4mm 照 2047 现役, 2260 验证板机械朝向未确认。
5. Q8 角度表建议升 Q12 (命中 92→99.5%)。6. 板端 (重)连接后须 `vox_scatter_desync()` (预渲染帧 KEY 位只在首帧)。
7. RGB565 → 2260 16-bit 灰度的 gamma 在板端/PL 定; 径向亮度补偿 (radial-comp) 在体素表路径上没有了。
8. tgt603: 603 奇数 ⇒ 面B 无法精确差半圈 (差半槽 0.30°)。

相关: [[project_validation_board_task_tree]] [[project_pov3d_voxel_table_payload_measured]] [[project_pov3d_v31_dualface_geometry_solved]] [[feedback_phase_b_must_follow_n_slices]] [[project_dr1m90_ddr_eta_x1]]
