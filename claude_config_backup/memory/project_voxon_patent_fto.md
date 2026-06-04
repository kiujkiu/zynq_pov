---
name: Voxon 专利 FTO 评估 (POV3D 旋转 LED panel)
description: Voxon 三件专利分析 + multivox colscatter.h 字面命中 P3 claim 2-5 (按半径调刷新率) + 方案 A 渲染管线吸收
type: project
created_at: 2026-06-03
updated_at: 2026-06-03
originSessionId: b30805da-604a-4e8f-8ae4-1f7896a3edb0
---
## TL;DR

**Voxon 三专利**:
- **P1 EP3230791B1** / **P2 US10401636B2** — GEN1 往复式 + 共振弹簧, 我们旋转架构, **🟢 无风险**
- **P3 WO2026006885A1** — GEN2 旋转式, 仅 PCT 公开未授权, **🔴 命门**: claim 1 ④ "调制区某特征按到转轴径向距离变化"

**multivox 已命中 P3 claim 1 + 2-5 (字面)**:
- `multivox/src/driver/colscatter.h` 注释: "outer columns need to be refreshed more frequently than inner columns" + "actual LED radii (1, 3, 5, 7)"
- `multivox/src/driver/vortex.c:384-406` 用 colscatter[] LUT 实现内圈 blank 降低有效刷新率
- 上游 AncientJames 开源, 我们移植, **当前代码不改商用 = 直接证据**

**绕开**: 方案 A — 删 colscatter[]/`inner` 分支, 统一刷新率, 几何不均匀在 voxel→panel 映射层吸收。1-2 天工作量。

## P3 关键日期

- 优先权日 **2024-07-05**
- 公开日 **2026-01-08**
- 国家阶段截止 **~2027-01** (现仅 PCT 公开, 无国授权)
- 预计到期 **~2045**

## P3 在先技术 (审查员引)
- Tsao US8022895B2 / BOE US20240187564A1 / Design On Impulse US20211344894A1
- "旋转 LED 自发光"已被占, P3 唯一可守: "按径向距离补偿"

## 关键代码命中
| 文件 | 行 | 内容 |
|---|---|---|
| `multivox/src/driver/colscatter.h` | 5-7 | 注释字面: outer 比 inner 刷新更频繁 |
| `colscatter.h` | 16 | "actual LED radii (1, 3, 5, 7)" |
| `colscatter.h` | 60-76 | colscatter[] LUT, 256 entry |
| `multivox/src/driver/vortex.c` | 384-386 | `column = colscatter[*line]; inner = column < PANEL_FIELD_HEIGHT;` |
| `vortex.c` | 403-406 | `if (!inner) { stack[0][1][1] = blank; stack[0][0][1] = blank; }` |

## 绕开方案排序
- **A** ⭐⭐⭐⭐⭐: 统一刷新率, 渲染管线吸收 (推荐, 1-2 天)
- **B** ⭐⭐⭐: 逐元素 LUT (cap_sweep 路径), 注释明确"非半径函数" — 等同原则残留风险
- **C** ❌: 物理排布解决 → 落入从属权 19-21 (表面密度), 更糟
- **D** 兜底: 完全不补偿, 牺牲画质

## multivox 上游
- 作者 AncientJames, GitHub 开源, RPi 原生
- Git first commit **2024-12-27** (P3 优先权日后 5 个月)
- YouTube Rotovox/Vortex 视频可能更早 — 若早于 2024-07-05 可作 prior art 防御性使用 (待查)
- ⚠️ prior art 不阻止被诉, 只是抗辩工具; **前置规避永远比事后抗辩便宜**

## FTO 备忘位置
- `/mnt/d/claude_workspace/pov3d/FTO_voxon_p3.md` (完整 claim chart + 改动 diff)

## 后续动作
1. 立即改 vortex.c + 删 colscatter.h (方案 A)
2. 全工程 grep `radius`/`radial`/`radii` 二次扫描
3. commit message 不用"按半径"措辞, 改用"uniform refresh / upstream voxel correction"
4. 2026 Q4 监控 P3 国家阶段
5. 量产前 3-6 月正式 FTO 法律意见 (中/美/欧)

## 关键提示
- 不要在代码/文档/PR/论文/marketing 里用"radial compensation"/"按半径补偿"措辞
- 几何补偿在 voxel 渲染层 (PC 或 PS), 驱动层 (PL panel_seq) 保持半径无感知
- 若做 LUT 标定, 文档化为"per-element measured calibration", 不是"radial profile"
