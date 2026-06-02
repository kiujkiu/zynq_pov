---
name: glTF UV v 轴多翻一次 → HDMI 体素花斑 (迷彩) 现象
description: glb_to_points.py 用 1.0-uv[1] 做 V 翻转, 相邻 tri 采到无关纹理 → HDMI 上看到马赛克/迷彩, 修法是去掉 1.0-, 因为 glTF 2.0 v=0 已经在图片顶部
type: feedback
originSessionId: 42b483be-17d4-4bd8-9194-41c6b8158af7
---
**规则**: 处理 glTF/GLB 贴图 UV 采样时, **不要**写 `1.0 - uv[1]` 翻 V 轴 — glTF 2.0 spec 明确 v=0 在图片**顶部**, 跟 DirectX/Metal 一致, 跟 OpenGL/OBJ 相反. 写翻转就是双重翻转, 相邻三角面采到 UV map 不同区域 → 表面**散列乱码型花斑**(迷彩感, 不是上下颠倒).

**Why** (2026-05-20 修出):
- host/glb_to_points.py 两处 (`sample_glb` line 284 + `voxelize_mesh` line 483) 写了 `ty = int((1.0 - (uv[1] % 1.0)) * tex.shape[0]) % tex.shape[0]`
- HDMI 上 anime 角色显示成蓝/金/橙乱混的迷彩斑, 看不出金发/蓝披风/白铠甲哪是哪, 跟 memory `project_pov3d_color_tuning` 描述的"金发/深蓝披风/白铠甲/金剑可辨"完全对不上
- 调 saturation/lighting/brighten 参数都救不回来, 因为根因不在调色而在采样位置错
- 改成 `ty = int((uv[1] % 1.0) * tex.shape[0]) % tex.shape[0]` 立刻出来标准 anime 配色, 色块连续
- 参考 `docs/claude_memory/glb-texture-flowerspot-postmortem.md` (用户从另一个项目 Soulog Spectrum 给过来的复盘, Bug ③ 一模一样)

**How to apply**:
- "迷彩感/花斑" + 调参数救不回来 → 先查 UV 采样代码有没有 `1.0 - v` 多余翻转
- glTF v=0 顶部 vs OpenGL v=0 底部, 不同格式 UV 约定不同 (OBJ 也是底部), 不要"凭习惯"加翻转
- 验证手段: 用半红半蓝测试贴图导入 + voxelize 看红蓝位置对不对, 比看 anime 模型靠谱

**关联损失**: 这个 bug 让之前所有 voxel anime HDMI 显示都是花斑, color_tuning memory 里说的"Option B/Option A 调参" 都是在调一个根本错的采样基础上的微优化, 修完 UV 后可能很多调参参数要回到默认.

**关联文件**:
- host/glb_to_points.py (line 284, 483 已修)
- anime_to_bin.py (重新生成 anime_points.bin 才能 xsdb 推上)
- docs/claude_memory/glb-texture-flowerspot-postmortem.md (源参考)
