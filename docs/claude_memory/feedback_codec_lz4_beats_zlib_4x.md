---
name: 解码瓶颈的解法是 lz4-HC 不是 FPGA — A9 上实测快 4×, 压缩比几乎不变
description: A9 实测 zlib 51.6 / zstd 53.6 / lz4-HC9 204.6 MB/s; lz4-HC9 压缩比 22.8× 对 zlib 23.5×; 双核 30fps 达标, 不用 FPGA inflate
type: feedback
---

2026-08-04 用板上真实内容 `anime_dual720.bin` (8,847,360 B = 720 片偏心双面) 实测。

## 🔴 结论: 换 **lz4-HC** 就能 30 fps, **不要做 FPGA inflate**

A9 单核解压 (取 5 次最快, `povrxd` 已停, ctypes 直调 so):

| 编解码 | 压缩后 | 压缩比 | 解压耗时 | 吞吐 | 单核 fps |
|---|---|---|---|---|---|
| zlib-6 (现用) | 376,780 B | 23.5× | 163.5 ms | 51.6 MB/s | 6.1 |
| zstd-9 | 282,002 B | 31.4× | 157.4 ms | 53.6 MB/s | 6.4 |
| zstd-19 | 208,310 B | **42.5×** | 160.8 ms | 52.5 MB/s | 6.2 |
| **lz4-HC9** | **388,166 B** | **22.8×** | **41.2 ms** | **204.6 MB/s** | **24.2** |
| lz4-fast | 714,137 B | 12.4× | 51.6 ms | 163.6 MB/s | 19.4 |

⇒ **lz4-HC9 压缩比与 zlib 几乎相同 (22.8 vs 23.5), 解压快 4 倍。**

### 双核并行 (双面 = 两条独立流, 一核一面)
| | zlib 现状 | **lz4-HC9** |
|---|---|---|
| 每帧 | 377 KB | 388 KB |
| 解码 | 82 ms ⇒ **12 fps** | **20.6 ms ⇒ 48 fps** |
| 30fps 需链路 | 90.4 Mbps | **93.4 Mbps** (实测有 **125** ✓ 余量 33%) |

⇒ **30 fps 达标, 解码侧还剩 60% 余量。**

## 🔴 两个反直觉的实测结果 (都别再凭常识猜)

**① zstd 在这颗 A9 上不比 zlib 快** (157 vs 163 ms, 差 4%)。
常识说 zstd 解压快 3×, 这里不成立。原因大概率是 libzstd 1.3.8 (2018) 且 ARM 上没优化路径。
⇒ **zstd 的价值只在压缩比 (42.5× @level19), 不在速度。**

**② RLE 更差, 不是答案**。协议里的 `PVS_FLAG_RLE` 是零游程
(`0x00 → [0x00][run:u16le]`, 非零字节字面直传)。实测 **7.1× (1.24 MB/帧)**,
比 zlib 大 3.3 倍 ⇒ 1.24 MB ÷ 15.6 MB/s = **12.6 fps, 与现状持平**。
**把瓶颈从解码搬到链路, 净收益接近零。**
(有趣的旁支: **RLE 再 zlib** = 28.3×, 比纯 zlib 的 20.9× 好 26% —— 但仍要 inflate, 对速度无益。)

## 落地要点
- 板上**已有 `/usr/lib/arm-linux-gnueabihf/liblz4.so.1.8.3`**, 不用装
- 协议 flag 位: RLE=0 / ZLIB=1 / DELTA=2 / DUAL_FACE=3 / FOLD_A=4 ⇒ **bit 5 给 LZ4**
- ⚠ CLI 的 `.lz4` 是**帧格式**(带魔数/校验), `LZ4_decompress_safe` 只吃 **raw block**。
  两端必须都用 raw block API (`LZ4_compress_HC` / `LZ4_decompress_safe`), 别混。
- lz4-HC 压缩慢, 但那是 PC 侧, 且 povstream 本来就预压缩缓存

## 测量方法备忘
- 板上没有 `zstd`/`lz4` CLI 且 **apt 装不到** (`Unable to locate package`),
  但 `libzstd.so.1` / `liblz4.so.1` 都在 ⇒ **用 python ctypes 直调 so**, 绕开一切安装。
- `pscp` 是 Windows 程序, **读不了 `/mnt/d/...` WSL 路径**, 必须给 `D:\...` 反斜杠路径。
- 测之前 `systemctl stop povrxd` —— 空闲动画吃 92% CPU, 不停测不准。
- 单核 51.6 MB/s × 2 = 110 MB/s, 与记忆里生产环境 `dec_avg 78-88ms/帧` 吻合 ⇒ 测量可信。

## 关联
- 解码曾是链路修好后的新瓶颈, 见 [[feedback_wifi_throughput_bottleneck_isolated]] (链路已到 ~125 Mbps)
- ⚠ 这条只救**现平台 (PVS1 切片流)**。ICND2260 目标架构根本不传切片
  (见 [[project_pov3d_icnd2260_datapath]]), 解压量降 25 倍, 那边本来就没这个瓶颈。
