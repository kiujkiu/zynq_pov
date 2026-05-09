# ADR-001: 产品 LED slice 路径 — voxel 4× IP vs mesh single IP

**Status**: 待拍板 (2026-05-09)
**Context**: Phase 9.5 综合 + Phase 8 实测后, 7020 装不下两条路径全部 IP. 必须二选一作为 LED 屏 720 slice × 30Hz 产品输出路径.

---

## 选项 A: voxel 4× pov_project_batch_v2 IP

**架构**: 4 个并行 HLS IP, 各跑 18/72 slot, 通过 phase + ring_base 偏移分工.

| 指标 | 数据 | 来源 |
|---|---|---|
| 单 IP throughput | ~12K slice/sec @150 MHz (v2) | Phase 4b 实测 + H 优化 |
| 4× 并行 throughput | ~48K slice/sec | 估算 |
| **vs 21.6K 目标** | **2.2× 余量 ✓** | |
| 资源 (实测综合) | LUT 56% / FF 38% / BRAM 22.5% / DSP 38% | Vivado impl_1 |
| Timing | WNS +0.240 ns ✓ | impl_1 |
| 数据形态 | 256³ voxel grid (16M cell, RGB565 = 32MB DDR) | |
| 颜色质量 | 离散点散布, **LED 上不连续** | Phase 8 结论 |

**优势**:
- 综合已过, bit 已生成, **无需再改 BD**
- 资源余量大 (LUT 余 44%), 后续加 ETH/WiFi/HDMI 还能塞
- v1 IP 已板上验证 60.54 FPS 稳定

**劣势**:
- voxel 离散表达上限固定, anime 大色块在 LED 不能连续渲染 (Phase 8 反复确认)
- 需要 host 把 mesh 转 voxel grid, 颜色质量在转换时已 lost
- DDR 占用大 (32MB voxel grid)

---

## 选项 B: mesh single pov_mesh_slice_render IP

**架构**: 单 HLS IP 做 mesh→平面 切片, two-phase (segments + scanline fill), Gouraud lerp.

| 指标 | 数据 | 来源 |
|---|---|---|
| 单 IP latency (estimate) | 73 μs/cell (1K tri) | HLS estimate |
| 单 IP latency (real est) | 300-500 μs/cell (anime 2-4K tri) | HLS 偏乐观 14× 经验修正 |
| 24 cell × 1 fb | ~7.2 - 12 ms (估算) | 串行 |
| **24 cell × 30Hz × 24** | **24 × 30 = 720 cell/sec, 1.4 ms/cell** | 720 slice 1 fb |
| 资源 (单 IP 综合) | LUT **97%** / FF 64% / BRAM 22% / DSP 28% | HLS report |
| Timing (估) | 未实跑 BD impl, 估算紧张 | |
| 数据形态 | mesh (8B vert + 6B tri, max 32K tri) | 32K × 14B = 448KB DDR |
| 颜色质量 | **实体填充连续切片**, 大色块自然 | Phase 8 mesh path 优势 |

**优势**:
- **LED 上颜色连续** (mesh 切平面 = 实心切片), Phase 8 关键洞察
- DDR 占用小 (~500KB), 远低于 voxel 32MB
- mesh 数据 host→板效率高, wire 协议 v3 已成熟

**劣势**:
- LUT 97% 几乎无余量, **HDMI/ETH/USB 等无法共存**
- 单 IP 串行 24 cell, 720 slice × 30Hz 需 1.4 ms/cell — HLS estimate 73 μs 看似够, 但 **estimate 偏乐观**, 实测可能 hit 上限
- HLS estimate→real 多 5-15× 慢化 (m_axi DDR 写实际很慢)
- 综合还没在主 BD 跑过, 工程风险

---

## 拍板维度

| 维度 | 选 A (voxel 4×) | 选 B (mesh single) | 加权 |
|---|---|---|---|
| **颜色 LED 视觉效果** | ❌ 离散散布 | ✅ 连续色块 | 高权 |
| **达 720@30Hz 性能** | ✅ 2.2× 余量稳 | ⚠️ estimate 紧, 风险 | 高权 |
| **资源余量** | ✅ 余 44% LUT | ❌ 余 3% LUT | 中 |
| **工程风险** | ✅ 已实测 | ⚠️ 未实测 | 中 |
| **可扩展性** | ✅ 加 IP 还能塞 | ❌ 几乎无余量 | 低 |
| **DDR 占用** | ❌ 32MB voxel | ✅ 500KB mesh | 低 |
| **host 编译路径** | mesh→voxel 转换 | mesh 直送 | 低 |

---

## 推荐: **选 B (mesh single), 但加 fallback 测试**

**Why**: Phase 8 反复确认 LED 上颜色连续是产品决定性指标. voxel 离散 4× IP 性能再快, LED 视觉上也是"碎片色块" — 这是离散表达的本质上限, 不是 throughput 能解的.

mesh single IP LUT 97% 紧张但**单 IP 即够 720@30Hz** (按 estimate). 风险在 estimate 偏乐观, 实测可能不达标. Mitigation:
1. **第一步**: 先在 BD 集成 mesh single IP (替换现 voxel IP), 综合 + 实测板上 throughput.
2. 实测达标 (≥ 720 cell/sec) → 选 B 拍板.
3. 实测不达标 → 退回 A, 接受颜色限制 走 voxel 4× (Phase 8 已验证).

**预期工程时间**: BD 切换 ~30 min (改 tcl), Vivado 综合 ~25 min, 板上 timing 测 ~10 min. **总 65 min, 可解锁产品路径.**

---

## 推荐执行时机

- **现在做**: ADR 评审 (用户决定) → BD 集成测试 (我执行)
- **暂不做**: 等 LED 屏到货再做的: 视觉真实验证, host pipeline 切换 (test_send_one.py mesh path)

---

## 反向选 A 的场景

如果发现:
- mesh HLS estimate 实测离谱 (>5× 慢于估算)
- LUT 97% 后 timing 不收敛
- BD 集成有 IP 接口/地址冲突难解

→ 回退选 A. voxel 4× 已实测稳定, Phase 8 颜色已 tune 到 anime 接近 (warm bake), LED 上不连续也接受 (用户接受度).
