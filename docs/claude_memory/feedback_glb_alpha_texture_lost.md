---
name: glb_to_points 丢 alpha → 半透明贴图渲成实心块 (星星消失)
description: convert("RGB") 扔掉 alpha, BLEND 材质的透明区变实心底色淹没真实图案; 改为 RGBA + alpha_thresh 剔除
type: feedback
---
2026-07-29 用户问 "3D 图里的星星怎么没了, 是渲染时删掉了吗" —— **不是删了, 是被自己的背景板淹没了**。

**根因**: `zynq_pov/host/glb_to_points.py` 加载贴图时
```python
im = Image.open(io.BytesIO(data)).convert("RGB")   # ← alpha 被丢弃
```
Robot.glb 的材质 `holo1` 是 `alphaMode=BLEND`, 贴图 RGBA 512×512、**21% 是透明像素**。
alpha 一丢 → 透明区变成实心底色 → 整个方片成实心色块, 真正的全息图案被盖住。
正交投影里表现为一条**实心黄横带**。

**修复** (3 处):
1. 贴图加载保留 RGBA (无 alpha 的图仍走 RGB, 不影响其他模型)
2. `sample_triangles(..., alpha_thresh=128)` 新参数
3. 采样时 `if px[3] < alpha_thresh: continue` —— 透明点直接丢弃

验证: occupied cells 58751 → **47060 (-20%)**, 与贴图 21% 透明比例吻合; 俯视投影里
holo 盘的绿色外环/青色刻度/紫色扇区/花瓣图案全部显现。

## 🔴 两个连带的坑

**① 点云有缓存**: `stream/pc/cache/*.npz` 存采样结果, **改了采样代码不清缓存完全没效果**。
改 `glb_to_points.py` 后必须 `rm -rf stream/pc/cache`。

**② 采样数对细碎内容影响极大**: 星星是小面积三角面, `sample_triangles` 按面积比例撒点,
采样少就直接消失。动画默认 400K → 提到 1.2M 才够 (渲染 174s → 251s)。
静态 `gen_anime_slices` 默认 1.8M, 所以静态版一直有、动画版没有。

## ⚠ 影响面

`glb_to_points.py` 是**共用的** (`gen_anime_slices` / `povstream` / `gen_projection` 全走它)。
其他用 alpha 贴图的模型 (角色披风/特效/粒子) 观感都会变; 已渲的 30+ 套内容要保持一致得重渲。
需保留旧行为传 `alpha_thresh=0`。备份 `glb_to_points.py.bak_prealpha`。
