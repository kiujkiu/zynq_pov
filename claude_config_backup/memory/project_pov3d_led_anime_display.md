---
name: HUB75E LED panel 显示 anime 角色 (HDMI fb → 128×64 实时桥接)
description: ARM 在 HDMI render loop 后加 inline 桥接, 每帧把 1280×720 fb 中央 800×400 区降采样 + crop + 颜色映射写入 HUB75E BRAM, 跟 HDMI 同时输出 anime
type: project
originSessionId: cddd55be-5600-43d2-9b26-a291ffc28846
updated_at: 2026-06-03
---

## 当前实现 (2026-06-03 实拍认证 "颜色好很多")

helloworld.c `cpu_scale_blit_one_fb` 之后, 每帧执行 HDMI→LED 桥接:

```c
#define LED_CROP_X 240   /* HDMI 中央 800 宽 → 128 LED (左右各裁 240) */
#define LED_CROP_Y 160   /* HDMI 中央 400 高 → 64 LED (上下各裁 160) */
/* 800:400 = 2:1 aspect-fit, 人物在 panel 放大约 60% 区域 */

for (int ly = 0; ly < 64; ly++) {
    int src_y = LED_CROP_Y + ly * 400 / 64;
    UINTPTR led_bank = (ly < 32) ? 0x4002C000 : 0x40028000;  /* 拼接反 */
    int led_y = (ly < 32) ? ly : (ly - 32);
    for (int lx = 0; lx < 128; lx++) {
        int src_x = LED_CROP_X + lx * 800 / 128;
        const u8 *p = fb_src + src_y * 3840 + src_x * 3;
        int g = p[0], b = p[1], r = p[2];   /* HDMI fb 是 GBR 字节序 */
        int sr = r - 32; if (sr < 0) sr = 0; if (sr > 192) sr = 192;
        int sg = g - 32; if (sg < 0) sg = 0; if (sg > 192) sg = 192;
        int sb = b - 32; if (sb < 0) sb = 0; if (sb > 192) sb = 192;
        /* stretch [32,224] → [0,63] 拉大 anime 100-180 中段值色差 */
        r = ((sr * 21) >> 6) >> 2;             /* R 100% / 4 */
        g = ((sg * 21) >> 6) >> 3;             /* G 50% / 4 */
        b = (((sb * 21) >> 6) * 3) >> 4;       /* B 75% / 4 */
        u32 rgb = (r & 0x3F) | ((g & 0x3F) << 8) | ((b & 0x3F) << 16);
        Xil_Out32(led_bank + (led_y * 128 + lx) * 4, rgb);
    }
}
```

`DISABLE_HUB75E_BRIDGE` 编译宏可以关掉桥接 (用于 HDMI-only debug).

## 关键发现

### 1. panel 物理过亮通道 **不是 memory 早期说的 R, 而是 G**
- memory 旧条目 "panel R>>G>>B" + "R 摄像头白爆" 在当前 FM6124 panel 不准
- 实拍对比期望参考: R 衰减到 62.5% 后 panel 完全没金黄头发, 反而 G dominant
- 正确策略: R 不衰减 (100%), G 衰减 50%, B 75%
- 写纯 R=0x3F panel 确实白爆, 但低 BCM 值时 G 视觉更强 — BCM 不线性

### 2. anime fb 字节序 = GBR (`p[0]=g p[1]=b p[2]=r`)
- 头发 (期望金黄): byte[0]=156 byte[1]=98 byte[2]=173 → G=156 B=98 R=173 = 浅黄 ✓
- 武器/披风同样字节序解析对的上原画

### 3. crop 240×160 = aspect-fit 2:1
- HDMI 1280×720 (16:9 = 1.78:1) → panel 128×64 (2:1)
- 不 crop 会横向 squash; crop 让中央人物保持比例同时放大

### 4. 1/4 亮度避免摄像头过曝
- 不 /4 时 -8 曝光下 panel 白爆 (mean=49+)
- /4 后 -10 曝光 mean=15 色相可辨

## 备份: PC 预生成路径 (2026-06-02, 已不使用)

之前 PC 端 downsample anime PNG → fb_anime_top/bot.bin → xsdb mwr 写入 BRAM. 静态单帧路径, 已被 HDMI fb 桥接取代:
- `tools/single_char_to_fb.py` + `tools/anime_load.tcl`
- 当时预补偿 R×0.35 G×0.9 B×1.3 — 跟现在 inline 公式方向相反 (因 panel 假设不同)

## 待优化

- 6-bit BCM 64 灰阶颜色精度限制 — 升级 8-bit BCM 能让色差更细 (memory 升级计划 #2)
- 摄像头白平衡偏冷 — 实际 panel 颜色比照片要暖, 不需要继续调 R weak
- LED bridge 每帧 ~5ms ARM 开销 (128×64 = 8192 次 Xil_Out32) — 可用 memcpy 优化但当前不瓶颈
