---
name: 面板带宽哨兵 pair_miss 一直读错 + 饱和后无法清零
description: 16 位计数器被脚本当 1 位读 ⇒ 4000 时打印 0; 且只有 PL 复位能清 ⇒ 只能冷启动后测增长率
type: feedback
---
2026-08-24 给 PL lz4 解码器做集成前基线时发现的。

`pov_dual_top.v:76` 打包的是 `R 0x1C = {locked, 6'b0, idx_B[8:0], pair_miss[15:0]}`，
而 `tools/ab_slices.py:51` 一直按 `idx=(v>>1)&0x1ff` / `pair_miss=v&1` 在读 ——
**把 16 位的饱和计数器当成 1 位**。`pair_miss=4000` (0xFA0, bit0=0) 会打印成 `0`。

面板取帧丢对的唯一哨兵，读的一直是噪声。已修为 `(v>>16)&0x1ff` / `v & 0xFFFF`。

## 更麻烦的是: 它没有软件清零口

```verilog
if (pov_en && pair_busy && (at_slice_idx != idx_prev) && pair_miss != 16'hFFFF)
    pair_miss <= pair_miss + 16'd1;      // 饱和, 不回绕
// 复位只有 aresetn (= PL 复位), pov_en 翻转不清
```
每片最多 +1，`11.1 rev/s × 142 片 = 1576 片/s` ⇒ **哪怕只有 4% 的片 miss，26 分钟也打满**。
实测当前读数就是 **65535 = 已饱和**，证明不了当前丢对率。

⚠ 文档里「3-bit 下 `pair_miss` 从来没量过」的真正原因在这 —— 量了也是 65535。

**Why**: 一个读错位域 + 会饱和 + 不能清零的计数器，比没有计数器更坏 ——
它会在真出问题时给出「一切正常」的读数。

**How to apply**:
1. 要拿它当带宽判据，只能**冷启动后定时采样看增长率**，绝对值无意义。
2. 加 lz4 之后的对照必须是「冷启动 → 测增长率 → 开 `--pl-lz4` → 再测增长率」，
   不能拿开关前后的绝对值比。
3. 下次动这个 RTL 时**顺手加一个写 0x1C 清零**的口子。
   参见 [[feedback_changed_instrument_and_design_together]]。
