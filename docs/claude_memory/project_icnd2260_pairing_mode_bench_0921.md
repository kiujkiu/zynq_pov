---
name: project_icnd2260_pairing_mode_bench_0921
description: 2026-09-21 在 E104 + 9 颗 40×45 样板上验 2260 配对模式 (60 扫=30+30, reg0x04=1E1E/reg0x08=5105): 四版 bit 已出 (P0 对照/P1 配对/P2 单颗扩展/P3 30 扫), PATTERN=5 半帧签名 + LINES 钩子, 判据表在 dr1v90/eg4_2260_e104/README.md §6.54; 样板列不共用 ⇒ 只能验语义/第 2 跳/占空比, 验不了行列共用电气
metadata:
  type: project
---

# 配对模式台架验证 (2026-09-21, 待上板)

背景: 厂家对配对/独立链路一律"没有" ([[reference_icnd2260_vendor_inquiry_0920]]), 用户定自己验。
工程 `dr1v90/eg4_2260_e104`, 全部设计与**先写死的判据表**在 README **§6.54**; 下载 `tools/dl54.sh P0|P1|P2|P3`。

## 样板能验什么 (3×3 颗, 每颗 40×45 **自己的行管**, 列不共用, S 型一条链)
| 问题 | 版 | 看什么 |
|---|---|---|
| 第 2 跳稳不稳 (1串2 先决条件) | P1/P0 (CASCADE=2) | 块 1 亮不亮, `rdbad`(TGTDEV=1), 重复 ≥5 次 |
| 扩展模式语义: 级联第 1 颗 = 芯片一管前 30 时隙? 第 2 颗只显示行 30–59? 每颗收全 60 行? | P1 (`ext60`, LINES=60) vs P0 (vendor 45 扫) | **PATTERN=5 半帧签名**: 片 0 上红/下绿, 片 1 上蓝/下黄 ⇒ 配对成立 = 块 0 只剩红、块 1 只剩**黄**、行 30–44 黑、亮度减半; 块 1 剩**蓝** = 扩展没生效 |
| 单颗 30+30 在"芯片二"时隙真不开行? (问询单第 6 问相位错开的前提) | P2 (CASCADE=1 LINES=60 ext60) vs P3 (LINES=30, 0x04=1E00) | P2 亮度 ≈ P3 一半 ⇒ 不开行 |
验不了: 行列共用电气、60 行占空比亮度、12 颗电流 —— 等新板。

## 数
- 帧周期 = (40×LINES×8+8)×CASCADE + 224 + FRAMEGAP; 芯片扫描时间 = 扫数×74×52×2 拍 (DCLK=100, GCLK=DCLK/2); FRAMEGAP 按 §6.44 锚 65.4%
- P1 706,640 拍 141.5 fps · P0 529,040/189.0 · P2 706,432/141.6 · P3 352,832/283.4
- 四版 TD 零违例 (SWNS 0.31~0.92), bram9k=2 与历史版相同, LUT 978→1076
- ✅ iverilog 整机 (DIRECT 时钟 + 真实 seq/tx + EG 原语桩) 四配置 `fb_q` vs `pattern(pix_addr)` 0 不一致, VHEAD rows=59/cascade=1, `.mem` 0x04/0x08 进 ROM 已核

## 工程改动 (已进 build.sh / rtl)
`LINES` 钩子 (BUILD_LINES, 45/60/30/48) · `PATT=5` · `MEMFILE` 的 TAG 按文件名 (`_ext60`/`_s30`) · `TGTDEV/CTLDEV ≥ CASCADE` 直接 die · 删掉 build.sh 里误入的孤行 `X`。
`rtl/icnd2260_regs_ext60.mem` (0x04=1E1E 0x08=5105) · `rtl/icnd2260_regs_s30.mem` (0x04=1E00), 都由供应商表派生, 只改这几个字。

**How to apply:** 台架顺序 P0→P1→P3→P2, 每版 ≥5 次下载 + 降曝光照片, 报列表不报单次; 结果回来更新 §6.54、`改板结论_验证板_2026-09-18.html` §3 与 SDO→SDI 0Ω 定案。
