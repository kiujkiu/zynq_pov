# PL HLS 点云/体素 → POV compact 切片投影 IP — 设计文档

**目标**: 让 PL 在板上实时把场景渲染成 POV compact 切片写 DDR, 由现有显示 IP
`hub75e_panel_seq_v8.v` DMA 读出驱动 LED panel, 不再依赖 PC 预算切片。

文件:
- `pov_proj.h` / `pov_proj.cpp` — 可综合 HLS top
- `cos_sin_q15.h` — 720-entry Q15 cos/sin LUT (由 `_gen_q15_cossin.py` 生成)
- `pov_proj_tb.cpp` — host gcc 测试台 (逻辑验证, 已 PASS)
- `RUNME_hls.md` — 综合 + 集成 + 触发步骤

---

## 1. 调研结论 — 现有 HLS IP 现状与搁置原因

仓库里已有 HLS 工作集中在 `hls_proj/pov_project.{cpp,h}`, 含 4 个 top:

| top | 输入 | 输出 | 状态 |
|-----|------|------|------|
| `pov_project` | 点云 model[] | **整帧 fb** (720p GBR, 逐点 2×2 写) | 早期单 slice, HDMI 路径 |
| `pov_project_batch` | 点云 32K + z-buffer | **ring buffer** 各 slot (38KB GBR/slot) | Phase 4b 主力, BD 里 `pov_project_batch_0` @ `0x43C20000` |
| `pov_project_batch_v2` | 同上, dual-HP | 同上 | II=1 尝试 |
| `pov_voxel_slice_batch` | 128³ RGB565 grid | ring buffer GBR slot | voxel 路径 |

**为什么不能直接复用 (必须新写)**:

1. **输出格式不对**。现有 IP 全部输出 **GBR 24-bit/像素的"全格式" framebuffer/ring slot** (38KB 或 64KB/片), 是给 **HDMI VDMA / v6 旧 DMA** 看的。现役显示链 `hub75e_panel_seq_v8.v` (CTRL[14]=compact_en=1) 读的是 **compact 1-bit 8 色格式** (8KB/片, 2048 word, lane 3-bit)。两者不兼容。
2. **panel 几何变换没固化进 IP**。现在 PC 管线把 rotate(180)/crop/bank-swap/panel1/2 transform 全部坍缩成 `tools/transform_lut.bin` 静态表; 现有 HLS IP 用的是另一套坐标 (SLICE_W=106×SLICE_H=120, cx/cy 中心化), 跟现役 128×128 dual-panel 物理布局对不上。
3. **4× IP 并行破 HDMI (ADR 已知坑)**。`USE_PL_4X=1` 时 4 个 `pov_project_batch` 同时 fire 让 HDMI 变彩色噪点 (memory `feedback_pov_4x_ip_breaks_hdmi`)，怀疑 `axi_smc_pov_hp` 把 8 个 m_axi 合并到 HP1 的仲裁/cache 一致性。该路径被搁置，1× IP @30FPS 是当前唯一可用配置。
4. 性能瓶颈在 m_axi 写 DDR (memory `feedback_hls_cycle_estimate_optimistic`: 实测 14× 慢于 HLS 估算); 老 IP 单路 ~2800 slice/s, 远低于 LED 需要的 21.6K/s。

**结论**: 现有 IP 是面向 HDMI-debug 的旧路径产物，**输出格式 / panel 几何 / 性能都不匹配现役 LED 显示链**，复用成本高于重写。新 IP 直接对齐已验证的 compact + transform_lut 管线。

---

## 2. 架构选择 — A (点投影) vs B (体素采样)

| | A 点投影 (multivox/老 HLS 风格) | **B 体素采样 (本设计选用)** |
|--|--|--|
| 算法 | 逐点旋转投影 scatter 写 | 逐 fwi gather: LUT→wx/wz→采样 voxel |
| 与已验证 PC 管线 | 不同算法, 需重新对齐颜色/坐标 | **bit-exact 复刻** `_gen_transform_lut.py:slice_via_lut()` (该函数已自验证 == PC 管线) |
| 复用 transform_lut.bin | 否 (scatter 不需要, 但 panel 几何要重写) | **是**, 16384×(d,wy) 原样进 BRAM, 省掉 rotate/flip/bankswap/pack 全部重写 |
| 计算量/片 | O(点数), 残影需清 slot (memory `feedback_hls_ring_no_clear_ghost`) | O(16384 px) 固定, 每 word 直接覆盖写无残影 |
| z-buffer | 需要 (last-write 覆盖, memory `feedback_hls_zbuffer_for_depth`) | 不需要 (壳体素 + 单平面采样, PC 管线就没做 z-buffer) |
| 输出 compact | scatter 后还要 pack 成 lane, 复杂 | gather 天然按 fwi 顺序, **8 lane/word 直接组装** |
| voxel grid 内存 | 不需要 grid | 128³×4B = **8MB DDR** (彩色 6.3Mb 塞不进 4.9Mb BRAM, 必须 DDR) |

**选 B**。决定性理由:
- **B 的输出与现役 compact 格式 + transform_lut.bin bit-exact**，TB 已证 701/720 片完全相同 (差异仅 cos/sin 量化, 见 §6)。A 要重新趟一遍 panel 几何/颜色对齐，等于重做 PC 管线已解决的所有坑。
- B 的 pack 逻辑天然顺着 fwi → compact word，无 scatter 冲突、无残影清理。
- 唯一代价是 8MB voxel grid 留 DDR + 每像素 1 次随机 DDR 读 (gather)，这是吞吐瓶颈，靠批算 + 多 IP 并行摊销 (§5)。

A 路径不丢弃：点云密度极高 / 需要 z-buffer 立体感时再考虑，但那是 HDMI 路径的需求，不是 LED compact 路径的。

---

## 3. 数据流图

```
            DDR                                  PL HLS pov_proj IP                         DDR
 ┌───────────────────────┐   m_axi gmem0  ┌────────────────────────────────┐   m_axi gmem1  ┌──────────────┐
 │ voxel grid 128³ ×4B    │──(随机 gather)─▶│ for s in [slot_start, +n_slots)│                │ compact ring │
 │  @0x1C000000 (8 MB)    │                │   aidx = s (n_total=720)        │                │ @0x18000000  │
 │  voxel_t{r,g,b,pad}    │                │   cs=COS_Q15[aidx] sn=SIN_Q15   │                │ 2048 w/片    │
 ├───────────────────────┤                │   for w in 0..2047:             │  burst write   │ 8KB/片       │
 │ transform_lut 64KB     │──(开头一次)────▶│     for k in 0..7 (UNROLL):     │───(顺序 INCR)─▶│ s*0x2000     │
 │  @载入 BRAM lut_d/wy    │                │       fwi=w*8+k                 │                │              │
 │  16384×{d,wy}          │                │       wx=clamp(rnd(d·cs)+64)    │                └──────┬───────┘
 └───────────────────────┘                │       wz=clamp(rnd(d·sn)+64)    │                       │
                                           │       v=grid[(wx*128+wy)*128+wz]│              hub75e_panel_seq_v8
                                           │       lane=G|B<<1|R<<2 (≥128)   │              DMA 读 SLICE_BASE
                                           │       word|=lane<<(k*3)         │              + slice_idx*0x2000
 angle_tracker.v ── slice_idx ──▶ (角度同步, 见 §4) │ slot[w]=word                    │              → LED panel
                                           └────────────────────────────────┘
```

格式对齐 (与 `_pack_compact.py` / `hub75e_panel_seq_v8.v` 注释一致, TB 已验证):
- compact word = 8 像素 × 3 bit。fwi = word_idx×8 + k, lane k = `word >> (k*3)` 低 3 bit。
- lane bit0=G, bit1=B, bit2=R (阈值 ≥128)。⚠ 注意这是 `_gen_transform_lut.py` 的语义
  (`lane = Gb | Bb<<1 | Rb<<2`)，与 v8.v 显示侧 `bit0=B,bit1=R,bit2=G` 的读法**已经在
  `_pack_compact.py` 做过一次 bit 重排消化**。本 IP 直接复刻 `_gen_transform_lut.py` 的
  打包，输出与 `*_720_compact.bin` 逐字节对齐，所以显示侧不用改。
- fwi 块顺序 = t2,b2,t1,b1 (bank swap), 已固化在 transform_lut.bin 里, IP 不感知。

---

## 4. 接口与控制寄存器

AXI-Lite slave `control` (HLS 标准 AP_CTRL + offset 寄存器):
| 寄存器 | 含义 |
|--|--|
| `AP_CTRL` 0x00 | bit0 ap_start, bit1 ap_done(COR), bit2 ap_idle, bit3 ap_ready |
| `voxel_grid` | DDR 体素网格基址 (建议 0x1C000000) |
| `lut` | transform_lut.bin DDR 基址 |
| `slice_base` | compact ring 基址 = 显示 IP 的 SLICE_BASE (0x18000000) |
| `n_total` | 总片数 720 (角度归一化) |
| `slot_start` | 起始片 (4-IP 并行各分一段) |
| `n_slots` | 本次渲染片数 |

m_axi:
- `gmem0` (读): voxel_grid + lut 共享 bundle。LUT 开头一次性 DMA 进 BRAM (`lut_d[16384]` + `lut_wy[16384]` = 64KB BRAM)，之后只随机读 voxel grid。
- `gmem1` (写): compact 切片, `max_widen_bitwidth=64` + 256-beat burst 顺序写。

**与 angle_tracker / 显示 IP 协同 — 推荐"离线批算整 720 片到 DDR ring"** (非实时逐角度):
- 显示 IP 自己有 `angle_tracker` 出 `slice_idx`，从 SLICE_BASE+slice_idx×0x2000 DMA 当前角度的片。**它要求 720 片全部在 DDR 就绪**。
- 因此 pov_proj 的工作模式 = **一次 ap_start 把 720 片 (或分给 4 IP 各 180 片) 算进 DDR ring**，ARM 等 ap_done，再让显示 IP 跑。场景变化 (动画下一帧 / 点云更新) 时 ARM 重新触发批算。
- **不进显示热路径**：显示 IP 以 panel 刷新率 (8K+ fps) 读 ring，pov_proj 以动画帧率 (目标 24–30Hz) 重算 ring。两者解耦，pov_proj 慢一点也只影响动画帧率，不影响 panel 不闪。
- angle_tracker 不直接驱动 pov_proj；pov_proj 用内置 720-entry Q15 cos/sin LUT 自己算每片角度 (与 PC 一致)。

---

## 5. 怎么避开 HDMI 仲裁坑 (memory `feedback_pov_4x_ip_breaks_hdmi`)

老坑根因: 4 个 `pov_project_batch` × 2 m_axi = 8 个 master 全合到 `axi_smc_pov_hp` → HP1，与 HDMI VDMA 争 HP / DDR 带宽 + cache 一致性，导致 HDMI 噪点。

本设计规避手段:
1. **现役链已无 HDMI**。LED compact 路径 (pov_boot/v8) 不跑 rgb2dvi/VDMA，HDMI 那条仲裁链根本不在 BD 里，老坑的触发条件不存在。
2. **HP 口分离**: 显示 IP 的 DMA 读走一个 HP (如 HP0)；pov_proj 的 gmem0(读 grid+lut)/gmem1(写 ring) 走**另外的 HP** (HP2/HP3)，物理隔离读写通道，不与显示 DMA 共 SmartConnect master 段。
3. **时间解耦**: pov_proj 批算完 (ap_done) → ARM `Xil_DCacheFlushRange` 整个 ring → 才让显示 IP DMA。**避免显示 IP 在 pov_proj write FIFO 未排空时读** (老坑的 cache-stale 模式)。批算与显示不同时跑同一片。
4. **多 IP 并行时**: 每个 IP 独立 HP 口 (参考 v2 的 dual-HP 思路 hp1_read/hp2_write)，不要 8 master 挤一个 HP；或干脆**单 IP 批算 720 片**先验证正确性，吞吐够了 (§6) 再上并行。
5. `gmem1` 写完后**不与显示 IP 同 HP**，避免 SmartConnect 仲裁丢/乱序写 (老坑怀疑点)。

---

## 6. 资源 / 时序 / 性能粗估

**资源** (单 IP, 综合前估算; 实际以 csynth 报告为准):
- BRAM: `lut_d`+`lut_wy` 16384×16bit×2 = 64KB ≈ 18 BRAM36; `slot_local` 8KB ≈ 2–3 BRAM。合计 ~22 BRAM36 / 140 (16%)。比老 32K-point IP (114 BRAM) 省很多。
- DSP: 每 lane 2 个乘法 (d·cs, d·sn), UNROLL 8 lane = 16 乘 + clamp/index 乘。~20–40 DSP / 220。
- LUT/FF: gather + pack 逻辑轻量, 估 < 10%。
- 4 IP 并行资源仍宽裕 (远低于老 mesh 97% 的不可行水位)。

**时序**: 目标 150MHz (6.67ns)。逻辑简单 (乘 + 移位 + 比较 + BRAM/m_axi), Fmax 余量应好于老 IP 的 205MHz。

**吞吐 (关键, 用 14× 实测系数修正 HLS 估算)**:
- 每片 = 16384 次 voxel 随机 DDR 读 (gather) + 2048 word 顺序 burst 写。
- 瓶颈是 **16384 个随机读**。随机读无法 burst, 每读 ~HP 往返延迟。乐观估 ~8 cycle/读 ⇒ 16384×8 = 131K cycle/片 @150MHz = **~0.87ms/片**。
- 720 片 = ~630ms/帧 ⇒ 单 IP **~1.6 fps**。**远不够** 5880 片/秒 (720片×490RPM/60)。
- **缓解**:
  - **批算 + 4 IP 并行**: 4× ⇒ ~6.3 fps。仍不够 30Hz 动画。
  - **voxel grid 缓存进 BRAM/URAM 的子集**: 1-bit 单色 128³ = 2Mb 可塞 BRAM (4.9Mb), 随机读变片上 1-cycle ⇒ 16384 cycle/片 @150MHz = 109µs/片 ⇒ 单 IP **9180 片/s**, 已过 5880 目标。**这是真正的性能解锁方向** (彩色塞不进, 但 1-bit/通道单色或 8 色位平面可以)。
  - 或 **gmem0 读 grid 用 max_read_burst + 把同 wy 行的 voxel 预取** (gather 局部性差, 收益有限)。

**性能结论**: 逻辑已对。**达标路径 = 1-bit voxel grid 进片上 BRAM (2Mb fits) + 批算**，单 IP 即可过 5880 片/s。先用 DDR-grid 版本验证正确性 (TB 已过)，再做 BRAM-grid 优化版本冲性能。当前交付的是 DDR-grid 正确性版本 (8MB 彩色 grid，最通用)。

**TB 验证结果**: globe 720 片 vs PC golden — **701/720 片逐字节相同 (97.4%)**, 19 片差异 (总 393/1.47M word = 0.027%)，根因是 cos/sin Q15 量化 + `np.rint` round-half-even 与定点 round-half-away 在 axis/half 角度的 ±1 voxel 边界差，**非逻辑错误**。要 100% 可让 PC 端 LUT 生成也改用同套 Q15 定点 (二选一对齐即可)。
