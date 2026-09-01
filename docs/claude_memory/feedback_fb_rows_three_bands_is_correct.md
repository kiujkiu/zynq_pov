---
name: feedback_fb_rows_three_bands_is_correct
description: 🔴 `povctl fb rows` 显示三条竖带是**对的不是 bug** — row 是扫描区内部的横坐标不是屏上纵坐标, 屏横向切成 3 个并联扫描区 ⇒ 只依赖 row 的图案必然重复三遍
metadata:
  type: feedback
---

# `fb rows` 的三条竖带是正确行为 (2026-08-31 离线结案)

2026-08-28 DR1 第一次点亮时, `povctl fb solid` 全白正常, 而 `povctl fb rows`
(源码 `row < ROWS/2`, **以为**该是"一条分界线半亮半黑") 显示成 **三条竖带**,
当时记为"行号到物理位置的映射和假设不同"的未解现象。

**真相: 映射没问题, 是"一条分界线"这个期望本身就是错的。**

## Why

**`row` 不是屏上的纵坐标, 是每个扫描区内部的横坐标。**
这块屏的扫描轴被切成 **3 个并联扫描区**(各由 3 条 SDI lane 驱动, 共用同一根行选):

| 观察者 X | lane | 宽 |
|---|---|---|
| `0..52` | `{6,7,8}` | 53 |
| `53..105` | `{3,4,5}` | 53 |
| `106..159` | `{0,1,2}` | 54 |

条内 `X = X0 + (宽-1) - row`(**row 沿 X 倒着走**); 屏高 Y `0..179` 来自 `word/bit`,
`fb rows` 根本没碰 Y。
⇒ **任何只依赖 `row` 的图案在屏上必然横向重复三遍。**

代入 `host/povctl.c:138` 的 `row < 27`: 亮列 = X `26..52 / 79..105 / 133..159`
= 三条各 27 列宽的全高竖带, 总亮面积 **50.6%** 【推算】—— 与现场目击吻合。
而 `solid` 与 row 无关所以正常 ⇒ **这两件事互相印证, 恰好排除了排线/lane 故障。**

**出处(2026-07-08 在 Zynq 上board 实测)**: `mlkpai_fs03/tools/pack_obs.py:6-12,40,65-79`;
另两处独立记载 `mlkpai_fs03/docs/led_panel_chain.md:140`("扫描 160 = 3 区 54+53+53 并行")、
`dr1v90/docs/BRINGUP_TOMORROW.md:250`。
🎯 **DR1 自己的 RTL 里就抄了同一张表**: `td_pov/soc_prj/uisrc/01_rtl/pov_dual_top.v:654-657`。

## "3" 与 3-bit 的三个 plane 无关

1-bit 下 plane 位**根本不进地址**(写 `pov_dual_top.v:717` `{1'b0,fbA_addr}` /
读 `icnd2047_panel_core.v:514` `{1'b0,next_row[5:0],3'd0}`, 逐 bit 对齐);
即便 3-bit, 写读两侧同一个 `row*18+plane*6+pair` 公式, `plane*6 ≤ 12 < 18`, 字段不重叠。

## DR1 侧 RTL 没有 bug ⇒ 一个字都不要改

逐文件 diff vs Zynq: `icnd2047_panel_core.v` / `angle_tracker.v` / `row_drv_icnd1028.v`
**0 行**; `panel_engine_2047.v` 24 行只是把 fb 数组搬进 `fb_lane_ram`(AW=10 与
`fb_waddr[9:0]` 一致, 地址原样透传, 逐拍等价); `pov_dual_top.v` 246 行**全是 0x2C-0x3C
取证寄存器**, `fb_we/fb_wlane/fb_waddr/pack_addr/mirror/fold` 一行都没进 diff。
⇒ 从 host 一次 32 位写到 SDI 出线, DR1 与 Zynq **逐 bit 相同**;
同一条命令在 Zynq 上跑也会是三条带(Zynq 一直用 `pack_obs.py` 在**观察者坐标**里出图,
天然不踩这个坑)。🔴 **改 RTL 只会引入 Zynq 上不存在的差异。**

## How to apply

1. **要"恰好一条分界线"就得用观察者坐标的图案**, 别用 `fb rows`。
   已给 `povctl` 补 `half`/`vhalf`(映射照抄 `pack_obs.py`, 别自己重推)。
2. **`fb rows` 出三条带 = PASS**, 把它当判据的地方要改过来
   (`docs/BRINGUP_TOMORROW.md:263-270` / `PANEL_BRINGUP_CHECKLIST.md` 几何节 /
   `board/povboot.sh:663`)。
3. ⚠ **还有一个会给三条带的备选没排除**: 行数停在复位值 384
   (`pov_dual_top.v:308` `au_rows_max<=9'd383`, 08-28 前无人写过 sub10) +
   1-bit 读地址只用 row 低 6 位(`icnd2047_panel_core.v:514`)。
   🎯 **靠几何量区分, 不靠"有没有带": 节距 53 (主假设) vs 64 (备选), 末端暗带 5 列。**
   ⇒ **下次拍屏连屏边一起拍**, 现场那次没记宽度/间距。
4. 板子回来时的可证伪验证(判据不含结论): 逐组点亮 lane{0,1,2}/{3,4,5}/{6,7,8},
   三张点亮区**两两不相交且并集 = 全开**, 每张只有**一条**贯穿屏高的亮带。
   详见 `dr1v90/docs/FB_ROWS_THREE_BANDS.md`。

相关: [[project_dr1_panel_first_light]] [[feedback_criterion_must_not_contain_its_answer]]
[[reference_zynq_dr1_code_drift]] [[project_pov3d_3bit_color]]
