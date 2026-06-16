# 右屏半像素交错 (256³ interleave) — 设计与验证

利用两块 panel 的**机械错位**做像素交错, 把径向 + 竖直有效分辨率各翻倍 (128 → 256)。
1-bit/通道 8 色不变。无交错 128³ 路径完全保留 (新文件 + 新 LUT, 旧文件不动)。

---

## 1. 偏移轴推导 (从 assembly_stack.py 几何)

`macha/pov3d/assembly_stack.py` L147–181 的 LED placeholder:

- 两块 128(W)×256(H) HUB75 module 立在 Y-Z 平面, 背面贴 fin (X=-14.3), **前面 X=0 = 转轴平面**。
- panel **宽 = assembly Y** (水平, 在 rotor 旋转帧里就是切片的径向方向)。
- panel **高 = assembly Z** (= 转轴 / 竖直方向)。
- `+Y screen` (`yc = SCR_W/2 + 1.0`, `dz = 1.0`) = **panel1 = viewer's RIGHT**,
  相对 `-Y screen` (panel2 = LEFT):
  - **+1mm Y** (panel 宽) , pitch 2mm → **径向 +0.5 px**
  - **+1mm Z** (panel 高) , pitch 2mm → **竖直 +0.5 px**

### 轴对应结论 (物理 → 采样)

| 物理偏移 | panel 方向 | 切片采样轴 | 偏移量 |
|---|---|---|---|
| +1mm Y | panel 宽 (水平) | **径向 d** (panel col → `d=col-64`) | +0.5 px |
| +1mm Z | panel 高 (竖直) | **竖直 wy** (panel row → `wy=127-row`) | +0.5 px |

**关键: 径向 +0.5 是 `d` 的偏移, 不是世界 z 的平移。**
偏移固定在 panel/rotor 帧里, 随转子一起旋转。所以是 `d += 0.5`, 旋转后自然变成
`wx += 0.5·cosθ`, `wz += 0.5·sinθ`。若错把它当成静态世界 z 平移 (`wz += 0.5`)
就会在大多数角度上错位 —— 这是从装配几何推出来的, 不是拍脑袋。
竖直 wy 偏移则是纯静态 `wy += 0.5` (转轴方向旋转不变)。

---

## 2. 256³ 交错方案

为了表示半像素, 把体素网格从 128³ 加密到 **256³ (1 unit = 半个旧 voxel)**。
- **左屏 panel2 (fwi 0..8191)**: 采**偶数**格 → `d = (col-64)*2`, `wy = (127-row)*2`
- **右屏 panel1 (fwi 8192..16383)**: 采**奇数 (+1)** 格 → `d = (col-64)*2 + 1`, `wy = (127-row)*2 + 1`

两屏的 d 偶/奇交错 → 径向 256 个不同采样位置; wy 同理 → 竖直 256。等效 256³ 体分辨率。

采样公式 (center 64→128, grid 128→256):

```
wx = round(d·cosθ) + 128        # d 已是 256³ 整数坐标 (含右屏 +1)
wz = round(d·sinθ) + 128
wy = LUT.wy                      # 已是 256³ 坐标, 直接用
rgb = vox256[wx][wy][wz]         # 阈值 / pack 不变
```

**取整约定**: `d` 是整数 (右屏的 +0.5px 已吸收成 `*2+1` 的整数), `round` 只作用于
`d·cosθ` / `d·sinθ`, round-half-to-even (host numpy rint) / Q15 round-half-away (板端)。
clip 范围 128 → **[0,255]**。右屏奇坐标 + round 偶/奇边界差 1 是亚像素, POV 转起来不可见。

偏移**完全吸收进 (a) 新 LUT (`transform_lut_il.bin`, 256³ d,wy) + (b) center/grid 常数**。
ARM/HLS 不需要任何 per-panel 分支判断 —— LUT 里左偶右奇已经编码好了。

---

## 3. 改了哪些文件

| 文件 | 说明 |
|---|---|
| `tools/_gen_interleave.py` (新) | 生成 `transform_lut_il.bin` (256³ 交错 LUT) + 交错 globe 切片 + 自洽 verify。复用 `_gen_transform_lut.py` 的几何追踪, 只改坐标缩放 (`*2` / `*2+1`)。 |
| `tools/transform_lut_il.bin` (新, 64KB) | 16384×int16 (d,wy), 256³ 坐标。左屏偶 / 右屏奇。旧 `transform_lut.bin` 保留不动。 |
| `tools/_verify_interleave.py` (新) | 高频同心环测试, 数值 + 可视化证明分辨率翻倍。 |
| `tools/INTERLEAVE_design.md` (本文) | |

旧 `_gen_globe_slices.py` / `_gen_anime_slices.py` / `_gen_transform_lut.py` / `display_128x128.py`
**未改** —— 无交错 128³ 路径继续可跑。交错版输出格式与 v6 DMA 完全一致
(720×8192 = 5,898,240 B, 与 `globe_slices_720_compact.bin` 同字节大小)。

---

## 4. 对 ARM / HLS 的接口变更清单

两版都**只**改: 喂新 LUT + 3 个常数 (grid 128→256, center 64→128, vox 大小 ×8)。
采样循环主体、阈值、pack、cos/sin 表逻辑全不变。

### ARM (`02_hello_zynq/vitis_ws/pov_render_src/pov_render.{c,h}`)
- `pov_render.h`: `POV_GRID 128 → 256`。`POV_VOX_BYTES` 自动变 256³×3 = 50 MB
  (注意 DDR 占用 ×8, 见下「成本」)。
- `proj_xz()` / 定点分支: `+ 64` → `+ 128` (2 处), `clip127` → `clip255` (新 helper, 上限 255)。
- 体素化 `vx=clip(x+64)` 等: 若点云仍是 128³ 坐标, 改成 `clip((x+64)*2, 0, 255)`
  (或直接产出 256³ 点云)。LUT 指针换成 `transform_lut_il.bin`。
- `vox + (((wx*POV_GRID)+wy)*POV_GRID+wz)*3`: 公式不变, `POV_GRID` 已是 256。
- **无 per-panel 分支** —— 右屏 +0.5 在 LUT 里。

### HLS (`02_hello_zynq/hls_pov/pov_proj.{cpp,h}`)
- `pov_proj.h`: `VOXEL_RES 128 → 256`, `VOXEL_HALF 64 → 128`。`FWI_COUNT/COMPACT_*/MAX_SLICES` 不变。
- `pov_proj.cpp`: `clamp127` → `clamp255` (上限 255), `q15_round(d*cs)+VOXEL_HALF` 的
  `VOXEL_HALF` 已经是 128。`wy = lut_wy[fwi]` 直接用 (LUT 已是 256 坐标)。
  `vidx = (wx*VOXEL_RES+wy)*VOXEL_RES+wz`: 公式不变。
- m_axi `gmem0` voxel 接口 depth: 128³ → 256³ (BD/pragma `depth` 改, IP 重综)。

### 成本提醒
- voxel grid DDR: 6 MB → **48–50 MB** (256³)。HP port 带宽 + DDR 容量要核。
- LUT 大小不变 (16384 entry)。切片输出大小不变 (8 KB/slice)。
- 若 DDR 吃紧: 可只在径向 (d) 交错而 wy 保持 128, 把 grid 做成 256×128×256 (~24 MB),
  代价是竖直不翻倍。本方案默认 256³ 全翻倍。

---

## 5. Host 验证结果

`_verify_interleave.py`: 高频同心环方波 (256³ 周期 4 = 128³ 周期 2, 正好 128 Nyquist 边缘)。

```
distinct radial samples in [0,120]: no-interleave=61  interleave=121     # 翻倍
ring reconstruction L1 error vs ground truth: no-interleave=0.499  interleave=0.249   # 减半
RESULT: INTERLEAVE WINS
```

- 无交错 128 径向采样: 细环混叠, 重建误差 0.499 (≈ 随机, 完全分不出环)。
- 交错 256 径向采样: 误差 0.249, 环清晰分辨。
- 对比图 `tools/interleave_radial_compare.png`: 上排 GT / no-IL / IL 二维圆环重建,
  下排径向 profile (no-IL aliased vs IL resolved)。

LUT 自洽 (`_gen_interleave.py verify`): 左屏 d,wy 全偶, 右屏全奇, 且
`left == old*2`, `right == old*2+1` 逐元素一致 (== 旧 128³ LUT 的精确加密)。

真实地球交错切片 (`globe_slices_il_720.bin`) 跑通, 720 片 × 8192 B 与现有格式同字节,
v6 DMA 直接可吞。
