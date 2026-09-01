---
name: feedback_dr1_3bit_path_suspect
description: 🔴 DR1 上 1-bit 显示完全正常而 3-bit 内容是满屏噪点 ⇒ 故障锁在 3-bit 专有的东西上(三平面 fb 布局/BCM 权重/bpp3 位); 排线 lane 映射 几何 面板时序全部无罪
metadata:
  type: feedback
---

# 1-bit 正常、3-bit 异常 (2026-09-01 二分定位)

## 怎么分开的

| 工况 | 结果 |
|---|---|
| **1-bit + `povctl fb-file chess_obs_fb.bin`**(数字棋盘格) | ✅ **屏上正确** |
| **3-bit + 推流内容**(helix, 走 PL 或 CPU 解码都试过) | 🔴 **满屏彩色噪点** |

⇒ **排线 / 九条 SDI / lane 映射 / 观察者几何 / 面板扫描时序 / 亮度通路 全部无罪。**
⇒ 嫌疑只剩 **3-bit 专有**的: 三个位平面的 fb 地址布局、BCM 权重、`bpp3` 位。

寄存器旁证: 1-bit 正常那次 `STATUS=0x00001879` / `frame_period=10530` / `edges=861476`,
与 2026-08-31 确认 OK 那次**逐位相同**(`edges` 差 0.05%)。

## 🔴 一条现成的线索: `povctl` 不支持 3-bit fb

`dr1v90/host/povctl.c` 的 `FB_OFF` 是**写死的 1-bit 公式**
`0x8000|(lane<<11)|((row<<3|word)<<2)` —— 每行 8 个字。
而 3-bit 每行是 **18 个字**(`row*18 + plane*6 + word`, 三个平面)。
⇒ **`povctl fb` / `fb-file` 在 3-bit 模式下写的地址是错的。**
⚠ 这**不解释推流乱码**(那条路 fb 由取帧引擎填, 不经过 povctl), 但解释了
"3-bit 下用 povctl 灌图案没意义", 也是个该修的真缺陷。

## 🎯 下一步的判据设计

**生成"每一片都是同一张棋盘格"的 3-bit 帧**, 走推流进去:
- 正常 3D 内容**单片是稀疏的**, 静止时看不出对错;
- 重复图案静止就能判读 ⇒ 把"内容对不对"和"3-bit 通路对不对"分开。

链条: `gen_anime_slices.to_3bit()`(float→0..7 码值) → `pack_obs.pack_slice(bpp=3)` → 0x9000/片。
依赖只有 numpy+PIL(WSL 有), **不需要 pygltflib**(所以 `gen_default_3bit.py` 那条路走不通)。
🔴 映射**照抄 `gen_chess_obs.py`**(2026-07-08 上板实测定的), 别重推。

相关: [[feedback_fb_rows_three_bands_is_correct]] [[project_pov3d_3bit_color]]
[[project_dr1_pl_decode_parity]]
