---
name: DR1V90 RISC-V 上板实测判决 — 单核比 A9 慢 2.15×, 顶不住现架构
description: 同一二进制同一帧同一 libc 对照; lz4_dec 104.5 vs 217.8 MB/s; 整帧 115.5 ms vs 一圈 62 ms 预算 ⇒ CPU 变瓶颈
type: project
---

2026-08-05 DR1V90GEG484 (米联客 MLKPAI-FS03-DR1) 到货当天上板测出来的。
方法与工具见 [[reference_bench_codec_kit]]；踩的坑见 [[feedback_riscv_glibc_ifunc_sigill]]。

## 实测对照 (都是**空载单核**, 同一份 `bench_codec.c`, 同一帧 `frames_robot/frame_0000.bin`, 同为 **musl** 静态链)

| | DR1 RISC-V @800MHz | Zynq A9 @667MHz | 比值 |
|---|---|---|---|
| memcpy | 122.2 MB/s | 265.6 | **0.46×** |
| crc32 | 107.8 MB/s | 78.3 | **1.38×**(更快) |
| zlib_dec | 54.8 MB/s | 80.9 | 0.68× |
| **lz4_dec** | **104.5 MB/s** | **217.8** | **0.48×** |
| **dec×2 + cpy** | **115.5 ms** | **53.7 ms** | **慢 2.15×** |

对照严谨性:
1. ARM 侧 musl(gcc 11) 与 glibc(gcc 15) 两版实测 `lz4_dec` 217.8 vs 217.7、
   整帧 53.7 vs 55.2 ⇒ **libc 与编译器都不是混淆因素**。
2. DR1 侧**三次独立运行**(10/10/20 轮, 负载从刚开机到完全空闲 load 0.04):
   `lz4_dec` 104.3/104.5/104.5、`memcpy` 122.2/122.2/122.0、整帧 115.6/115.5/115.5
   ⇒ **离散度 < 0.2%**，不是噪声。

## 判决

**翻页天花板 = 转速 16.1 fps ⇒ 一圈 62 ms。**
- A9 = **53.7 ms** ⇒ 压得进，余量 13%（很窄但过线）
- DR1 = **115.5 ms** ⇒ **超预算 86%，CPU 成为新瓶颈**，端到端预测 6.8 fps
  （现役 Zynq 实测 10-11.4 fps）

⇒ **DR1V90 直接平移过去会掉性能一半。不能当 drop-in。**

## 但结论不是"安路不行", 三条修正

1. **不是全面慢**: crc32 反而快 1.38×（64 位寄存器利好 zlib slice-by-8 查表）。
   慢的是**内存带宽型**负载 —— memcpy 0.46× 正好对应"无 L2 + DDR3L 只有 16 bit"。
   [[reference_anlogic_dr1_fs03_eval]] 里预判的风险点被证实了，且**就是唯一的风险点**。
2. **主频是 800 MHz 不是 600**（实板 dtb 实测），即 800 MHz 都只有 A9@667 的一半 ——
   差距来自访存子系统，不是主频。
3. 🔴 **bench 里的 `xor` 项(20.9 vs 119-182 MB/s)不能当硬件指标读** ——
   我那个循环是逐字节 `dst[k]=a[k]^b[k]`，A9 上 gcc 用 NEON 自动向量化，
   RISC-V 无 V 扩展只能逐字节。改 uint64 循环能快 8 倍。是测法artifact。

## 要让 DR1V90 成立需要什么 (按性价比)

差 115.5 → ≤62 ms，即需砍掉 1.86×：
- **PL 做 lz4 解码** (80.8 ms 里的大头)。🔴 注意这比原评估第 7 节scope 的
  **DEFLATE inflate IP 便宜得多** —— lz4 **没有 Huffman**，只有 literal/match 拷贝，
  RTL 约 200-300 行、1-2 周，而不是 500-800 行 2-4 周。当初"选 V 的净成本 ≈ 把
  inflate IP 提前做"这笔账，因为编码换成 lz4 已经大幅缩水。
- **PL330 DMA 替 CPU memcpy**：实板 dtb 里有 `arm,pl330`，能省掉 34.5 ms → 81 ms（仍不够，但配合上一条就够了）
- **A 面 only**：数据减半（亮度也减半），见 [[project_pov3d_offset_axis_geometry]]
- 换 **DR1M90 (双核 A35)**：但注意 [[feedback_lz4_onboard_reality_check]] 实测双核并行只值 1.06×，
  指望第二个核救场是不成立的 —— A35 的价值在单核更强，不在核多。

## 仍未测的 (下次上板补)

- **带载**数字（屏跑起来抢 DDR）。A9 实测带载比空载差约 2×
  （[[feedback_decode_bandwidth_halves_under_display_load]]），DR1 大概率同样甚至更差
  （16-bit DDR 更容易被抢）。**跨平台对比必须同工况**。
- 网络吞吐（板子千兆网口当时没插线）、PL 侧 oDDRx1 时序、CEP2 屏点亮。
