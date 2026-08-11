---
name: reference_dr1_cache_and_frame_memory
description: DR1 上 pgprot_writecombine/noncached 全是空操作(CPU 无 Svpbmt) 且 HP0 与 cache 不一致 ⇒ 照搬 Zynq 的帧区做法会静默错帧; 正解是 CMA 带 cache + 显式回写
metadata:
  type: reference
---

# DR1 的帧区内存: 照搬 Zynq 会**静默错帧**, 不是变慢 (2026-08-07 查实)

## 结论链 (每一环都查过出处)

**① `pgprot_writecombine()` 在这块板上是彻底的空操作**

| 环节 | 事实 |
|---|---|
| CPU 有没有 Svpbmt | **没有** —— 运行中 dtb 写的是 `riscv,isa = "rv64imafdc"` |
| 内核编了吗 | 编了 (`CONFIG_RISCV_ISA_SVPBMT=y`) 但**是运行时探测**的特性 |
| 探测不到会怎样 | ALTERNATIVE 停在默认分支 ⇒ `_PAGE_NOCACHE = _PAGE_IO = _PAGE_MTMASK = 0` |
| 于是 | `pgprot_writecombine()` 展开成 `prot &= ~0; prot |= 0;` = **原样返回** |
| `pgprot_noncached()` | **同样是空操作** |
| T-Head 的替代分支 | 没编 (`# CONFIG_ERRATA_THEAD is not set`) |

⇒ **Zynq 版 `povmem.ko` 的全部存在理由(把 SO 换成 write-combine)在 DR1 上不成立。**

**② `/dev/mem` 给的也是可缓存映射**
`drivers/char/mem.c` 的 `uncached_access()` 判据是 `addr >= __pa(high_memory)`;
DR1 没有 `mem=`, 512 MB **全在 lowmem** ⇒ mmap `/dev/mem` 拿到的是**普通可缓存**内存。

**③ HP0 与 CPU cache 不一致** —— 四条独立证据:
1. 厂商 **PL-AXI-DMA HAL(正是走 HP 口的)每次传输前强制 flush/invalidate**;
   描述符必须放 `.noncacheable` 段
2. HP0 只有两个可配项(使能 + 位宽 64), PS IP 对外**无 ACP/ACE/ACE-Lite 端口**;
   全 `soc_prj` grep `ACP|coherent` 零命中
3. 内核配置明写: `CONFIG_ERRATA_ANLOGIC_CCM=y` + `CONFIG_RISCV_DMA_NONCOHERENT=y`;
   SDK dtsi 每个 DMA master 都标 `dma-noncoherent`, 运行中 dtb 里 `dma-coherent` 零命中
4. NMSIS 只有 Cacheable / Device-Non-Cacheable 两态, **没有 coherent 态**

## 🔴 合起来的后果

①+②+③ ⇒ **"照搬 Zynq 只改 `--base`"的结果是 PL 读到陈旧数据 = 静默错帧。**
不是慢, 是错。而且错得没有任何报错信息。

## 两个还会咬人的坑

**`dma_alloc_coherent` 在这块板上默认拿不到 CMA。**
`CONFIG_DMA_GLOBAL_POOL=y` ⇒ 非一致性 device 的 `dma_alloc_coherent`
**一律落进 16 MB 的 `linux,dma` 池**。那个池全系统共用、按 buddy order 分配,
一块 8.85 MB 的 bank 会吃掉 order-12 = **整整 16 MB**
⇒ 之后 USB/WiFi/MMC 的 coherent 分配全部失败。
解法: 把分配用的 `struct device` 标 `dma_coherent = true`, 才会走
`dma_alloc_contiguous → CMA`, 拿到**带 cache** 的连续内存。

**🔴 这颗核只有一个硬件非缓存窗口, 而且已经被占了。**
机制不是页表也不是标准 PMA, 是 Nuclei 的一对 CSR `MNOCB(0x7F5)/MNOCM(0x7F6)`
(NAPOT、最小 4 KB、只保留 bit[31:2], **全 SDK 只有一处写它**)。
内核在 `core_initcall` 已经把它指给了 `linux,dma`。
⇒ **不要试图从 S-mode 再发一次 SBI ncache 把它挪给自己的帧区** ——
那只会把唯一的窗口挪走, 16 MB DMA 池悄悄变回可缓存,
**USB/WiFi/MMC/网口的 DMA 全部静默出错**。(这个选项写出来过, 查清后删掉了。)

## 最终方案

**CMA 分配 48 MB + 带 cache 映射 + 显式 D-cache 回写 ioctl。**
- ⚠ **2026-08-10 更正**: 原写"64 MB ⇒ `get_order`=14 ⇒ 天然 64 MB 对齐"**是假的** ——
  `kernel/dma/contiguous.c:284` `align = min(get_order(size), CONFIG_CMA_ALIGNMENT)`,
  本板 `.config:3704` **`CONFIG_CMA_ALIGNMENT=8` ⇒ 对齐被钳在 1 MB 封顶**。
  真正需要的对齐只有页对齐(mmap)和 8 字节(`rtl/axi4_to_axi3_hp.v:177`)。
  对齐理由既然不成立, size 已从 64 MB 收到 **48 MB**(=3×16 MB bank)。
  🔴 **任何写死 bank 地址的东西都是错的** —— 以 `/sys/class/misc/povmem/phys_base` 为准
- 回写靠 `dma_sync_single_for_device()` 打到 `arch_sync_dma_for_device → ccm_dcache_op(CCM_DC_WB)`
  (用户态碰不到: 无 Zicbom, CCM 在 CSR 0x5cb/0x5cc 只有 S-mode 能写)
- 🔴 `pov_rxd` 里 **`/dev/povmem` 打不开就直接拒绝启动, 不再静默回落 `/dev/mem`** ——
  在 Zynq 上回落只是慢 5-10 倍, 在 DR1 上回落是**画面必错**
- 🔴 回写的 ioctl **放在 `t_cpy` 计时区间内**, 所以 DIAG 的 `cpy` 就是
  "让 PL 看见这一帧"的全部代价, 不拆成两个数骗自己

## 🔴 CMA 实际只有 16 MB, 因为 dtb 要的 256 MB **静默失败**了

dtb 里 `linux,cma` 写的是 `size = <0x00 0x10000000>` (256 MB), 但实测
`CmaTotal: 16384 kB`。dmesg 说明了原因:

```
OF: reserved mem: failed to allocate memory for node 'linux,cma': size 256 MiB
Reserved memory: created DMA memory pool at 0x0000000010000000, size 16 MiB
cma: Reserved 16 MiB at 0x000000001f000000        <- 退回 CONFIG_CMA_SIZE_MBYTES=16
```

**根因**: `linux,dma` 那个 **no-map** 空洞在 `0x1000_0000`, 把 512 MB 劈成
`0x40_0000..0x0fff_ffff` (252 MB) 和 `0x1100_0000..0x1fff_ffff` (240 MB) 两段,
**哪一段都放不下 256 MB** ⇒ 预留失败, 内核退回编译期默认值。
⚠ 只看 dtb 会以为有 256 MB。**以 `/proc/meminfo` 的 `CmaTotal` 为准。**

**解法 (已做, 2026-08-07)**: `fdtput` 把 `size` 改成 `0x6000000` (96 MB),
反编译对比**只有 2 行变化**。实测 `CmaTotal: 98304 kB` = 96 MB,
dmesg 变成 `OF: reserved mem: initialized node linux,cma`, 失败信息消失。
产物 `dr1v90/boot/dtb_cma96.bin`, 卡上留了 `dtb.orig`。

🔴 **为什么这个改动低风险**: 现状本来就是"预留失败但内核照常启动",
所以改小要么成功、要么和原来一样失败, **两种都能引导**。
(相比之下改 `memory@0` 或加新的 no-map 节点, 失败就是不引导, 必须拔卡。)

## 🔴 2026-08-10: 「加 no-map reserved-memory 节点当帧区」这条路被证伪, 别再想它

曾经的建议(写在 [[project_dr1_parity_plan]] §5 Step 0b)是: 在 DTB 加一个 `no-map` 的
reserved-memory 节点, 把 3 个 bank 放到 DDR 顶部 `0x1D00_0000`–`0x1FFF_FFFF`。
**三条理由否掉它, 第二条是决定性的**:

1. **它根本不让内存变成非缓存的。** 无 Svpbmt ⇒ PTE 里没有内存属性位, 缓存性只由
   `MNOCB/MNOCM` 那个唯一物理窗口决定, 而它已归 `linux,dma`。更坏: no-map 会把
   `high_memory` 拉到 `0x1D000000`, 于是 `drivers/char/mem.c:301` 的
   `addr >= __pa(high_memory)` 变真、`/dev/mem` 去调 `pgprot_noncached()` ——
   **而那是空操作**。代码路径装得像申请了非缓存, 硬件一个字节没变。
2. 🔴 **它把唯一能用的回写通路弄坏。** `arch/riscv/mm/dma-noncoherent.c:96`:
   ```c
   void arch_sync_dma_for_device(phys_addr_t paddr, ...) {
       void *vaddr = phys_to_virt(paddr);        // <-- 线性映射虚拟地址
       ccm_dcache_op(CCM_DC_WB, vaddr, size, riscv_cbom_block_size);
   ```
   `no-map` 的定义就是从 memblock 移走、**不进线性映射** ⇒ 那个 VA 根本没有映射。
   CMA 是 `reusable`、留在线性映射里, 所以现在这条路才成立。
3. 96 MB 的 CMA 本来就自动放 DDR 顶部, 与 `0x1D000000-0x1FFF_FFFF` **正面重叠**;
   而且加静态 no-map 是"写错就不引导、必须拔卡"的改动(对比上一节改 cma size 的低风险)。

⇒ **帧区继续走 CMA + 显式回写。改动量 = 0, 这条路早就实现好了。**

顺带查实: `riscv_cbom_block_size` 会被填成 **64**(`setup.c:296` 无条件调
`riscv_init_cbom_blocksize()`, 运行中 dtb 有 `riscv,cbom-block-size = <0x40>`) ——
若为 0, `ccm_dcache_op` 的 `start &= ~(0-1)` 会**死循环**。

## 🎯 2026-08-10 上板实测: `cpy` = **158-175 ms (中位 ~162)** —— 比预想坏得多

DR1 板上实测 (zlib, 空载不接屏, 假转 15 rev/s, 双面):
```
DIAG rx=3.53/s flip=3.53/s drop=0 | dec 262.3ms | cpy 162.1ms | wait 45.5ms
```

| | Zynq | DR1 | |
|---|---|---|---|
| CPU 解码 | 217.8 MB/s | 104.5 MB/s | 2.15× 慢 |
| **`cpy`** | **~20-26 ms** | **~162 ms** | **约 6-8× 慢** |

折算 **约 55 MB/s** 有效带宽, 与"16-bit DDR + 无 L2"自洽。
**一圈只有 66.7 ms, 光 `cpy` 就吃掉 2.4 圈。**

🔴 **这是一堵此前没人算到的第二堵墙, 而且比解码那堵更高。**
根因就是本文上半部分那条链: Zynq 帧区是 write-combine, memcpy 完就完了;
DR1 无 Svpbmt ⇒ 帧区**必须带 cache** ⇒ 每帧显式回写 8.85 MB。

**两个结论**:
1. **Step 5 的"预期 6-7 fps"口径要改** —— 那是按解码 115.5 ms 当墙算的。
   即使 Step 6 把 lz4 搬进 PL 让 `dec` 降到 ~85 ms, `cpy+wait ≈ 197 ms` 会接管成为
   新墙 ⇒ 约 **5 fps**。
2. 🔴 **Step 6 的 PL 解码器必须直接写进帧 bank, 不能只是"解码快"。**
   "PL 片上历史 ⇒ 顺带消掉 memcpy"从附带好处**升级为主要收益** ——
   它一次干掉 `dec` 和 `cpy` 两堵墙。见 [[project_pov3d_cpu_to_pl_offload]]。

⚠ 口径: zlib + **空载**。`cpy` 与编解码无关可直接用; 但带载(屏刷新抢 DDR)会更差
(A9 上带载比空载差约 2×), 见 [[feedback_decode_bandwidth_halves_under_display_load]]。
⚠ **尚未拆分** `cpy` 里 memcpy 与 cache 回写各占多少 —— 要拆得改代码加计时。

## 还没有数的地方

🔴 **内核的 `ccm_dcache_op()`(`arch/riscv/mm/dma-noncoherent.c:44-54`) 没有写厂商
baremetal 版结尾那句 `CSR_CCM_FPIPE = 1`**(`nuclei_ccm_cache.c:48-57` 每个 range op
都写)。厂商自己的 MMC/USB/网口 DMA 也走这条内核路径且正常, 所以大概率无所谓;
但"回写返回时是否保证已落 DDR"无文档。**出现"偶发旧帧"时这里是第一嫌疑。**

相关：[[project_dr1_parity_plan]] [[project_dr1_soc_step1_done]] [[feedback_riscv_glibc_ifunc_sigill]]
