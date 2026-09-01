---
name: feedback_dr1_0x28_face_b_base
description: 🔴 0x28 写=面B基址 读=frame_period — 这块板第三个"读写不同义"寄存器; 不写它则 dual_en 下面B读野地址 ⇒ 3-bit 满屏乱码闪烁, 2026-09-01 卡了一整天
metadata:
  type: feedback
---

# `0x28` 是面 B 基址, 不只是 frame_period (2026-09-01)

## 事情

3-bit 推流上屏**满屏乱码 + 闪烁**, 而 1-bit 完全正常。查了一整天(证伪了地址位宽截断、
RTL 差异、BCM 权重、单缓冲覆写四个假设), 最后在**上游 Zynq 的脚本**里一眼看到:

```python
# mlkpai_fs03/stream/board/pov_boot.sh
pw(0x1C, N_SLICES // 2)              # PHASE_B
pw(0x28, BANK_A + N_SLICES*STRIDE)   # 🔴 面 B 基址
pw(0x18, BANK_A)                     # 面 A 基址
```

🔴 **`0x28` 写=面B基址, 读=frame_period。**
我那天读了它十几次当 `frame_period` 用(判 3-bit 有没有切成功), **一次都没想过写它是别的东西**。
⇒ DR1 上面 B 基址**从没被设置过** ⇒ `dual_en=1` 时面 B 每圈读随机位置
⇒ **满屏乱码 + 闪烁**(闪烁正是面B在读野地址的形状)。

## 这块板已知**三个**读写不同义的寄存器, 三个都在同一条路径上

| 寄存器 | 写 | 读 |
|---|---|---|
| `0x18` | 取帧基址(面A) | `locked_ever` / `slice_max` |
| `0x24` | `row_cfg` | POV_CTRL 影子 |
| **`0x28`** | **面B基址** | **`frame_period`** |

🎯 **模式: 写口是配置、读口是状态, 两者毫无关系。** 遇到没见过的寄存器,
**先查上游脚本写了什么**, 别从读到的值反推它的用途。

## 🔴 为什么二分定位反而把人带偏了

对照表的两行**不可比**:
- "1-bit ✅"走的是 `povctl fb-file` **直写 fb 窗口**(`pov_en=0`),
  **完全不经过** 取片引擎 / `pack_addr` / plane 字段 / 面B基址 / HP0 读通路
- "3-bit ❌"走的是整条 DDR 取片链

⇒ **色深与取片路径从来没有被分开过**, 于是一整天都在 3-bit 专有逻辑里找根因。
🎯 **教训: 对照组必须只差一个变量。** 否则二分只会干净利落地把人引向错的那一半 ——
而且因为它"看起来很严谨", 更难怀疑。

## 顺带被证伪的四个假设(都留着, 免得下次重查)

1. ❌ `fb_lane_ram.v` 地址位宽截断: `panel_engine_2047.v:82` 例化写死 `AW(10)`;
   `pack_addr` max = 53·18+2·6+5 = **971 ≤ 1023**; 综合报告 18 个 `u_ram` 每个 `eram=2`
   ⇒ 深度 1024 确实实现了
2. ❌ DR1 与上游 fb 通路有逻辑差异: **逐位等价**(`icnd2047_panel_core.v` diff 为空)。
   记忆里"`fb_lane_ram` 是唯一真改动"**只对了一半** —— 文件确实重做了(TD 不认 generate
   里的 RAM 推断), 但**行为等价、深度/位宽都对**
3. ❌ BCM 权重/位序: flat 帧三个位平面**逐字节相同**, 权重再错也只该"图案对、亮度不对"
4. ⚠ 单缓冲覆写(`n_slices > drawable`): **方向对但不是这次的成因**(比值降到 0.72 仍乱)。
   **但它是真问题**: Zynq `pov_boot.sh:82` 注释"全屏每圈画得出 143"而它就配 142
   ⇒ **`n_slices ≤ drawable` 是设计前提**, 而 DR1 现在 142 > 95,
   `povboot.sh` 那句 `slices 96..142 never complete` 的 WARN 一直在喊

## How to apply

- 能工作的完整序列见 `dr1v90/board/cmds_3bit_working.txt`(2026-09-01 屏上验证过)
- 🔴 `0x18`/`0x28` 必须**跟着 `pov_rxd` 当前用的 bank 走**(读它的 FLIP 日志 `A=` / `B=`),
  bank 是三缓冲轮转的
- 面B偏移 = `n_slices × stride`(3-bit 是 `0x9000`, 1-bit `0x3000`);
  142×0x9000 = **0x4FE000**

相关: [[feedback_phase_b_must_follow_n_slices]] [[feedback_dr1_3bit_path_suspect]]
[[project_pov3d_3bit_color]]
