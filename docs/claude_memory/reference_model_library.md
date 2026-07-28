---
name: POV 内容模型库位置 (models/)
description: D:\claude_workspace\pov3d\models\ 下几十个 GLB 可直接喂 gen_anime_slices.py
type: reference
---
`/mnt/d/claude_workspace/pov3d/models/`（= `D:\claude_workspace\pov3d\models\`），之前记忆里没记过。

- `models/Models/` — **bonsai.glb (盆景树)**、Groot.glb (树人)、Dino、Robot、Skeleton、Engine、walking
- `models/heroes/` — 英雄联盟角色几十个: ahri / akali / ashe / caitlyn / gwen / irelia / **ivern (树精)** / yasuo / axe …
- `models/hogwarts/` — hogsmead_station 场景

生成切片直接指 `--glb`：
```
python gen_anime_slices.py --glb "D:\claude_workspace\pov3d\models\Models\bonsai.glb" --out bonsai_slices.bin
```
几何参数用默认即可（`--gap-mm 13.8` + `--mirror-u` 已是默认，见 [[project_pov3d_offset_axis_geometry]]）。

**盆景特别适合 POV**（2026-07-28 实测选定为开机默认内容）：
- 结构镂空、枝叶分散 → 旋转时层次分明，不像实心模型糊成一团
- 上下结构明确（盆→干→冠）→ 一眼看出朝向对不对，可兼作方向校验图
- 亮点数低（466/片 vs 角色 636）→ 电流余量大，亮度可开满

⚠ 树干在中轴上，会被 13.8mm 中心盲区吃掉一部分（干显得空心就是这个原因，不是 bug）。
