---
name: HUB75E LED panel 显示 anime 角色 (PNG → 128×64 fb)
description: PC 端 downsample anime 图 → fb_anime_top/bot.bin → xsdb mwr 灌 BRAM, panel 显示低多边形角色, 颜色对比弱
type: project
originSessionId: cddd55be-5600-43d2-9b26-a291ffc28846
---
2026-06-02 在 LED panel 上显示 anime 3D 模型角色 (静态单帧). 流程:

## Pipeline

1. **源图**: `tools/anime_crop.png` (anime_62459.glb 的 RAW lighting 渲染截图, 蓝+金+银配色)
2. **PC 转换** (`tools/single_char_to_fb.py`):
   - Crop 顶部 caption + 找内容 bbox
   - Letterbox 到 2:1 aspect (保持人物 portrait, 两边黑边)
   - Replace neutral grey BG with black (低 chroma + mid luma → 0)
   - 预补偿 panel R>>G>>B: R×0.35, G×0.9, B×1.3
   - Gamma 0.85, saturation 2.5
   - Resize 128×64 LANCZOS → fb_anime_top.bin (rows 0-31) + fb_anime_bot.bin (rows 32-63)
   - 输出 fb_anime_preview.png (6× scale) 验证
3. **xsdb load** (`tools/anime_load.tcl`):
   - CTRL=0 disable → mwr -bin -file fb_anime_top.bin → 0x4002C000 (panel bot bank, 物理拼接反)
   - mwr -bin -file fb_anime_bot.bin → 0x40028000 (panel top bank)
   - TUNIT=8 sweet spot, CTRL=0x561 (mode 0 + use_fb=1 + overlap_en=1)

## 实测显示效果 (2026-06-02)

- 角色轮廓清晰可见 (头/身体/腿) ✓
- 主色调蓝白 ✓
- **黄色出不来** ✗: R 衰减后 R+G 黄色变弱, 看不出金色头发
- 黑底干净 ✓
- 两侧 letterbox 边界有竖直亮线 (panel column 边界 di/dt artifact, 不知道怎么修)

## 颜色 trade-off

LED panel R>>G>>B 物理不平衡 + 6-bit BCM (64 灰阶) + 6-bit 截断 = 颜色对比弱:
- R 不衰减 → 所有亮像素都变白 (R 压倒 G/B)
- R 重衰减 (0.2) → 红/黄全丢, 蓝绿主调
- 折中 (R×0.35) → 蓝白能显示, 黄色勉强

更好的色彩还原方案 (待做):
- **量化前 perceptual remap**: 把 muted source 拉到 PURE 色 (R/G/B 各通道极端) 而不是 mid-tones
- **8-bit BCM** 升级 (色深 64→256 灰阶)
- **测试纯色块图** 量化 panel 各通道亮度比, 精确预补偿

## 相关文件

- `tools/anime_to_fb.py`: 多源图转换 (含 vid_frames_slice/f0.jpg HDMI 实拍照片)
- `tools/single_char_to_fb.py`: 单角色聚焦 + 完整 preprocessing
- `tools/hdmi_full_to_fb.py`: 1280×720 全图直接压 128×64 不 letterbox
- `tools/anime_load.tcl`: dl + 启用
- `tools/fb_anime_top.bin / bot.bin`: 当前 fb 数据 (16KB each)
- `tools/fb_anime_preview.png`: 6× scaled PC 预览

## 备份方案

HDMI 死 (见 `feedback_v28_hdmi_broken.md`), 不能拿 HDMI 当颜色参考. 直接看源图 anime_crop.png 调.
