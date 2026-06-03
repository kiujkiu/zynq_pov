---
name: POV3D panel chain→X 物理映射 (2026-05-28)
description: 9 SDI chain 跟 panel 物理 X 区域 + RGB 色组对应表, frame compositor 必备
type: reference
originSessionId: 42b483be-17d4-4bd8-9194-41c6b8158af7
---
**chain 索引 → 物理 X 区域 → 色组** (auto-cap chain_id 测出):

| chain | label | X 区域 | 色组 | 备注 |
|---|---|---|---|---|
| 0 | R1 | **右** | R | 红正常 ✓ |
| 1 | G1 | 右 | G | (推断, 测时 G 出青色 → 跟 B 串扰?) |
| 2 | B1 | 右 | B | |
| 3 | R2 | **中** | R | 红正常 ✓ |
| 4 | G2 | 中 | G | 实测出 cyan = G+B 混合 ⚠ |
| 5 | B2 | 中 | B | |
| 6 | R3 | **左** | R | 红正常 ✓ |
| 7 | G3 | 左 | G | |
| 8 | B3 | 左 | B | 实测出 cyan ⚠ |

**软件公式** (chain → image 坐标):
```c
int region   = chain / 3;           // 0=R1组(右), 1=R2组(中), 2=R3组(左)
int color    = chain % 3;           // 0=R, 1=G, 2=B
int image_x  = 2 - region;          // image 左→右 = 0→2 (R3组在左)
```

**已知问题** (尚未排查):
- G/B 颜色穿场: 单独点 G2/B3 出 cyan, 不是纯色. 怀疑 PCB 上 G/B 信号短路或 LED 内部 GB 并联
- chip→Y 映射经证实单调 (chip 0 在上, chip 11 在下), 但 bit→subpixel 关系仍未理清

**测试图位置**: `D:\workspace\zynq_pov\tools\calib_out\chain_{0..8}_*.jpg`

**触发**: 任何 frame compositor / image_render 模式都要按这个表 emit chain_data
