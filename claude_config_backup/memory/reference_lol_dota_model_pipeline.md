---
name: lol-dota-model-pipeline
description: "LoL/Dota2 英雄模型获取+技能动画 GIF 固化流水线 (lol_pipeline.py), Khada CDN 直链规律, glb 交错缓冲 byteStride 修复, Blender 烘 LoL 蒙皮会塌球"
metadata: 
  node_type: memory
  type: reference
  created_at: 2026-07-09 18:20 CST
  originSessionId: d0e75b64-c52e-4094-977e-e2daee7e9eb2
---

## 模型源 (2026-07-09 实测全通, 无需登录)
- **LoL**: Khada CDN 直链 `https://cdn.modelviewer.lol/lol/models/{alias}/{key*1000+skin}/model.glb` (UA 必带 Mozilla)。alias=ddragon id 小写 (missfortune/kaisa/leblanc/renata), key 数字查 `models/heroes/champ_keys.json` (源=ddragon champion.json zh_CN)。glb 自带全套骨骼动画 (Spell1-4/Attack/Dance/Death ~50 takes) + 贴图, 亚索 7.3MB/阿狸 17MB
- **Dota2**: Valve 官方 `http://media.steampowered.com/apps/dota2/workshop/{hero}.zip` (workshop requirements 页出链)。FBX+Maya+全套 TGA, **无动画** (绑定姿势); FBX→GLB 用 Blender 4.2 headless, 贴图按 mesh 名绑 `materials/<mesh>_color.tga` (body 在 `materials/base/__axe_base_color.tga`), 脚本 `models/heroes/_axe_convert.py`
- Sketchfab 免费模型必须账号 API token (settings/password 页), 匿名 401
- Printables 匿名可下: GraphQL api.printables.com `GetDownloadLink` mutation 直接给链接

## 固化流水线
`models/heroes/lol_pipeline.py` (**Windows python 跑**, pygltflib/matplotlib 都在): `--alias ahri [--skin N] [--take auto]` → 下载+蒙皮验证(塌缩检查 extent<20% 判死)+技能 take 自动选 (R>E>Q>W>攻击)+镜头跟随点云 GIF → `models/heroes/lol/<alias>.{glb,gif,json}`。批量结果同目录。
推屏续接: `povstream.py render --anim glbanim --glb lol/<alias>.glb --anim-take Spell4 --frames 36` → stream (见 [[fs03-led-panel-chain]] PVS1 栈)。

## 两个关键坑
1. 🔴 **Khada glb = 交错顶点缓冲**: zynq_pov `glb_to_points._get_accessor_data` 原版忽略 bufferView.byteStride, joint 索引读成权重字节 (0x3F80 越界) — **2026-07-09 已修** (stride gather, 紧密缓冲行为不变, 未 commit 时注意)。glb_anim/povstream/lol_pipeline 全靠这个修复
2. 🔴 **Blender 导入 LoL glb 蒙皮塌成球** (人形变团): 别走 Blender 烘焙路, 用 `mlkpai_fs03/stream/pc/glb_anim.py` (纯 numpy spec-correct, 与推屏同管线所见即所得)

## 推屏密度配方 (2026-07-09 亚索案)
LoL 暗淡贴图 (土黄/褐/铁色) 1-bit Bayer 后极稀 (~72/slice vs anime 1456)。**主因=抖动吃中低亮度, 不是采样**。单帧实验: brighten1.8+gamma0.65+sat1.4 ×2.2 / --lighting none ×1.26 / --samples 1.5M 仅×1.08。**标准密度配方**: `--robust-fit --samples 1500000 --lighting none --ambient 1.0 --brighten 1.8 --gamma 0.65 --saturation 1.4` (72→189/slice)。**更狠=`--pure-rgb`** (povstream 新 flag, 2026-07-09 未commit注意): 每点 snap 主导纯通道组合×255, 7色海报风, 抖动存活 100% (亚索 358→1012/slice); ⚠ gas 颜色链是 0..255 not 0..1。**选英雄标准**: 宽体型 (限制轴=高y 的人形半宽仅~40/79, 扎克 Dance 半宽 84 打满) + 亮色/纯色 (扎克纯绿); lit bits 跨英雄别直接比 — 白点 3bit/绿点 1bit。另: R 技能特效骨骼撑爆 bbox 压小人物, --robust-fit 必开 (亚索 scale 32.7→39.2); 离轴 --x-offset 后总 lit 数下降是切片几何正常现象非变暗。

## 其他
- 霍格沃茨: 车站 `models/hogwarts/hogsmead_station.{stl,glb}` (Printables, 无顶开放注意); 城堡×2/火车/山谷在 Sketchfab 等 token
- 女性角色批量清单 `models/heroes/female_list.json` (65 个)
