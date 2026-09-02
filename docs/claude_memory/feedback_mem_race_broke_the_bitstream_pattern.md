---
name: feedback_mem_race_broke_the_bitstream_pattern
description: 编译进行中重新生成 .mem 会让编出来的 bit 图案对不上(BRAM 初值在综合时读文件); 现已让每次构建落盘 PATTERN.txt 指纹
metadata:
  type: feedback
---

# 编译中途改 .mem, 编出来的 bit 图案对不上 (2026-09-02)

## 发生了什么

帧缓存是 `$readmemh("icnd2260_fb_lvds.mem", fb)` 的 BRAM 初值 ⇒ **图案在综合时被读进 bit**。
我在一次构建还在跑的时候, 又跑了一次图案生成器覆盖同一个 `.mem`,
结果**编出来的 bit 里是后来那张图**, 而我跟用户描述的是前一张。

用户拍照说"你是不是没写对" —— 是的。我从 `.mem` 把数据读回来才发现:
```
hw第 0行 R值: 65535 37856 20036 ...   ← 指数 4.0
hw第22行 R值: 65535 48460 34151 ...   ← 指数 2.2
hw第44行 R值: 65535 57133 48731 ...   ← 指数 1.0
```
三行三条不同曲线 = `curvetest`, 而我说的是"8 级台阶"。**而且我自己早先还警告过这个竞态。**

## 修了什么

`tools/build_bit_dbg.tcl` 在拷 `.mem` 之后把**图案文件首行注释抄进 `$build/PATTERN.txt`**,
并打印 `=== 图案指纹: ... ===`。⇒ 事后任何时候都能确认某个 bit 里到底是哪张图。

## 可推广的

**凡是"构建时读取、事后不可见"的输入, 都要在产物里留指纹。**
同类的还有: `-generic` 被静默忽略(见 [[reference_icnd2260_startup_writes_table_66_times]] 事实五)、
`reg_rom` 是 RAM 导致 poke 跨 soft_rst 残留。
**共同特征: 输入变了但产物看起来一样, 于是你在错误的前提上继续推理。**

⚠ 还有一条同源的坑: 后台任务里用 `sleep` 想让烧录和编译错开 —— **前台 sleep 在本环境被禁**,
脚本直接退出并把后台的 vivado 一起带走, 日志全空, 看起来像"跑完了"。**别用 sleep 排并发。**

相关: [[feedback_wns_was_a_mirror_of_my_own_margin_knob]] [[feedback_only_synthesis_catches_it]]
