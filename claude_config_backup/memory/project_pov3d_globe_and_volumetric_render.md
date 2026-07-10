---
name: pov3d-vs
description: "旋转面板=过极轴子午面, 物体每片=该平面横截面; 球壳每片圆环转出球面, 实心每片圆盘填实心球; POV 透明无遮挡前后叠加; 地球仪用 _gen_globe_slices.py"
metadata: 
  node_type: memory
  type: project
  created_at: 2026-06-16 13:11 CST
  updated_at: 2026-06-16 13:11 CST
  originSessionId: 241cce13-9bee-40a1-a353-d0f7b04250fa
---

## POV 体积渲染物理 (关键, 做任何 3D 内容都要懂)
旋转面板是**过转轴(竖直极轴)的直径平面**. 角度 θ 的切片 = 物体被该子午面切的**横截面**.
- **实心物体** → 截面实心圆盘 → 转出实心体 (11289 lit px/片 @球R60)
- **空心壳** → 截面圆环 → 转出表面壳 (~1100 lit px/片 @TH3)
- **POV 透明叠加无遮挡**: 每瞬子午大圆含该经线正面+背面, 转一圈所有经线点亮 → **整个球面同时可见, 前后大陆透视重叠**. 物理上做不到"只看朝向你这面、背面被挡" (真地球仪那种不透明遮挡). 用户接受透明壳.
- anime 表面网格 POV 切片只得稀疏轮廓 (43-103 lit px) → 不适合; 实心球体/壳才填得满.

## 地球仪工具 (tools/)
- `_gen_globe_slices.py` — 球壳/实心切片. `TH` 壳厚(3=环形), `R`=60(直径120). 采样 earth_clean.jpg 投影, 分类 8色: 蓝海(b>r+8&b>g+8)/白冰(>170)/绿陆. y=极轴竖直.
- `_gen_globe_pol.py` — 政治版, scipy.ndimage.label 连通区各大洲糖果色 (国家级在128px/8色出不来, 只能大洲级)
- `_make_globe_glb.py [natural|political]` — 生成预览 glb. **坑**: 默认绕序法线朝里→viewer 背面透白网格 (脚本自动 invert 修); PBR 被 viewer IBL 反光→改 **unlit (baseColor黑+emissiveTexture)** 彻底不反光.
- `_render_globe.py` — numpy 正交渲染验证贴图 (不用 viewer)
- `earth_clean.jpg` — NASA Blue Marble Land_ocean_ice_2048, **无 graticule** (旧 earth_equirect.jpg=SW.jpg 烤了经纬网格+红线进去, 显示成"白色部分", 弃用)

## 部署
板 live → `_run_globe_live.tcl` 热换数据; 冷启动 → `_run_globe_cold.tcl` (fpga先再AXI, 见 [[feedback_jtag_dl_reflash_loop_dead]]). sensor 模式 CTRL=0xC5E1. 切内容 = 重生成 compact + live 灌, 不重烧 bit. 关联 [[feedback_angle_tracker_two_interp_bugs]] [[project_pov3d_dual_panel_v34g_chess]].
