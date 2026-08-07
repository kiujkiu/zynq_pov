---
name: PL lz4 解码器 v1 — 16/16 向量通过, DR1 上 100MHz 收敛
description: 字节串行 + 64KB 片上历史; 实测 0.93-0.96 B/clk; eram 10%/slice 0.83%; Fmax 113MHz; 两个引擎即可过 143 MB/s 门槛
type: project
---

2026-08-06。[[project_dr1_sku_decision]] 锁 DR1V90 后，PL 解码是**必做项**。
代码在 **`D:\claude_workspace\pov3d\dr1v90\lz4hw\`**，设计文档 `DESIGN.md`。

## 🔴 最重要的两个设计决策

**① 64 KB 片上历史窗口 ⇒ 全程不回读 DDR**
LZ4 的 offset 是 uint16 (≤65535)，所以片上 64 KB 环形缓冲覆盖**全部** match，
输出变成纯顺序流。这直接绕开了 CPU 侧那个已知的坑
（[[feedback_lz4_onboard_reality_check]]：「不能直接解压进 bank，WC 内存读极慢，
而 LZ77 回溯要读输出缓冲」）—— CPU 受制是因为输出缓冲在 WC 内存里，PL 放片上就没这问题。

**② 字节串行，不做 8 B/clk 宽通道**
重算需求后发现宽通道是过度设计：PL 解码后 CPU 不参与 ⇒ 整个 62 ms/圈都可用 ⇒
门槛是 **8.85 MB / 62 ms = 143 MB/s**，不是我一开始按"30 ms 解完"拍的 295 MB/s。
**而且字节串行把重叠拷贝(offset<match_len)那个最易错的模块直接消掉了** ——
逐字节"读历史→写历史"天然等价于软件的 `while(n--) *d++ = d[-off];`，
不需要模式复制单元、不需要 8×8 字节 mux。少一个最易错的模块 = 少一周调试。
不够就多例化几个：`PVS_FLAG_MSTREAM` 本来就把载荷切成多条独立流（原为双核并行切的），
**多引擎零协议改动**。

## 实测结果

**功能: 16/16 向量通过**（`cd lz4hw/sim && make`）
向量由 `tools/gen_vectors.c` 生成 —— **压缩流是真 liblz4 1.10.0 `LZ4_compress_HC(9)` 压的**
（与生产链路同一个编码器），参考输出是压缩前原始字节，且生成时已用
`LZ4_decompress_safe` 回解自检过。真实数据 5 例（frames_robot 切片 / 64 KB / 552 KB）
+ 边界 11 例（overlap off1..7 / 长 literal / 长 match / 混合收尾 / 仅 literal）。

**吞吐: 0.93-0.96 B/clk**（真实数据），设计文档估的是"~90 MB/s @100MHz"，
实测 93-96 MB/s ⇒ **估算这次是准的（略保守）**，没重演
[[feedback_hls_cycle_estimate_optimistic]] 那种乐观 14×。

**DR1V90 综合实测**:
```
#eram 28/280 = 10.0%   (64KB 历史; 预估 26 块, 实际 28, 差 8%)
#lut 507   #reg 188   #slice 436/52480 = 0.83%   #dsp 0
100 MHz: SWNS +1.179ns / HWNS +0.018ns 全过, Fmax 113.4 MHz
```

⇒ **2 个引擎 @100MHz = 186-192 MB/s > 143 门槛(30% 余量)**，
代价 slice 1.7% / eram 20%。器件富余极大。

⚠ **Fmax 113 MHz 只有 13% 余量**，且这是**核单独综合**的数 ——
和 panel core + AXI 包装集成后会退化。集成后必须重测，别拿这个数当承诺。

## 🎯 Zynq XC7Z020 综合实测 (2026-08-07, OOC @ xc7z020clg484-1)

源码**一个字没改**直接综合 (`_lz4_synth.tcl` → `dr1v90/lz4hw/synth_zynq.tcl`)：

| | `lz4_decode_core` | **`lz4_axi_top`**(含 AXI master+Lite) |
|---|---|---|
| Slice LUT | 293 (0.55%) | **749 (1.41%)** |
| Slice Reg | 198 (0.19%) | **843 (0.79%)** |
| BRAM | 16 RAMB36 (11.43%) | **16 RAMB36 (11.43%)** |
| DSP | 0 | **0** |
| WNS @100MHz | +3.174 ns | **+2.688 ns** |
| **Fmax** | 146.5 MHz | **136.8 MHz** |

**64 KB 历史推成 16 个 RAMB36E1**（Xilinx 侧 4Kx9 配置 ⇒ 65536/4096 = 16），
与 DR1 的 28 eram 是同一份存储的不同切法。

🔴 **Zynq 比 DR1 宽松**: Fmax **136.8 vs 113.4 = +21%**，余量从 13% 变 **37%**。

### 引擎数: 必须 2 个, 1 个不够 (按 900 RPM / 66.7 ms 一圈算)

| 载荷 | 每帧 raw | 需求 | 1 引擎 @125MHz (116-120 MB/s) |
|---|---|---|---|
| 720 片双面 | 8.85 MB | 132.7 MB/s | ❌ 差 |
| 632 片 (316×2) | 7.77 MB | 116.5 MB/s | ⚠ 正好压线, 零余量 |
| 540 片 fold | 6.64 MB | 99.6 MB/s | ✅ 但只剩 17% |

⇒ **2 引擎**。代价 LUT 1,498 (2.8%) / BRAM 32 tile (**22.9%**) / DSP 0。
叠加现有设计 (LUT 2,701 / BRAM 9 tile) 后全片 **LUT 7.9% / BRAM 29.3% / DSP 0%**。
`PVS_FLAG_MSTREAM` 本来就把载荷切成多条独立流，**多引擎零协议改动**。

### ⚠ 这组数的效力边界
OOC 综合、**没跑 place&route**，也**没和 panel core 集成**。集成后要面对：
现设计是 50 MHz 单时钟域 (WNS +6.888ns)，加 100 MHz 域是**新的跨时钟域问题**。
路由后 Fmax 必降。**别拿 136.8 当承诺**，集成后重测——这条警告对 Zynq 同样成立。

### 🔴 Zynq 可以当这个核的首次上板平台
DR1 那边卡在**下载器没到手**，核至今没上过真硬件。**Zynq 有 JTAG，这个阻塞不存在**，
且 Zynq 有 **4 个 HP slave**(DR1 只有 2)，读压缩流/写解压结果各占一个也不与
`ddr_slice_fetch` 抢。⇒ 在 Zynq 上先除险，对 DR1 那条线是纯赚。

## 三个调试踩坑（都是流水线差一拍，值得记）

同步 RAM(ERAM) 读写各差一拍，三处独立的 off-by-one，症状各不相同：

1. **读地址没领先一拍**：写成 `rd_addr <= wr_ptr + 1 - offset`，但那时 `wr_ptr`
   尚未自增 ⇒ 算出的正是当前字节地址，同一字节读两遍且首字节读在写入之前 ⇒ 输出全 `x`。
   正解: 读地址每拍 `+1`（写指针也每拍 +1，差值恒为 offset），并在 `S_MPREP` 里先推一格。
2. **写地址没跟着数据打拍**：`hist_we/hist_wd` 是寄存器（下一拍生效），
   而 `hist[wr_ptr]` 里的 `wr_ptr` 同一拍已自增 ⇒ 字节写进 `W+1` ⇒ **整表错位一格**。
   正解: 加 `hist_wa`，与数据同源同龄一起打拍。
3. **offset==2 需要第二级旁路**：offset==1 早知道要旁路（要的是上一拍才写的字节）；
   但 **offset==2 时那个字节的写入与本次 RAM 读落在同一个时钟沿**，
   非阻塞语义下读到旧值(read-before-write) ⇒ 只有 off2 单独挂。
   正解: `last_wr_byte2`。offset>=3 才能直接吃 RAM 输出。

🔴 **这三个坑的共同教训**: `offset==1` 因为走旁路不读 RAM，是唯一"碰巧对"的用例。
如果测试向量只有 off1 和真实数据（真实数据里小 offset 很少），前两个 bug 会**全部漏网**。
**专门构造 offset=1..7 的向量是抓到它们的唯一原因** —— 边界用例不是走过场。

## 下一步
1. AXI 包装（读压缩流 / 写解压结果；DR1 PS 只有 **2 个 HP slave**，Zynq 有 4 个）
2. 多引擎例化 + 流表解析（吃 `PVS_FLAG_MSTREAM`）
3. 与 panel core 集成后重测 Fmax
4. 上板 —— ⚠ 仍卡在**安路下载器没到手**
