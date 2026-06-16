/* pov_platform.h — 平台层抽象。Linux 移植只需重写这一个文件。
 *
 * 收口三类平台相关项:
 *   1) DDR 物理地址 (点云输入 / LUT / vox scratch / slice 输出)
 *   2) 这些地址的可用指针 (裸机=物理地址直接当指针; Linux=mmap 返回)
 *   3) cache flush (裸机=Xil_DCacheFlushRange; Linux=msync/无操作)
 *   4) HUB75E IP 寄存器写 + FCLK1 配置
 *
 * ── 裸机内存图 (DDR) ──────────────────────────────────────────────────────
 *   0x16000000  点云输入: 头 [int32 magic='PPC0', int32 count] + count×16B 点
 *   0x16400000  transform_lut.bin (64 KB)
 *   0x16800000  vox scratch (128^3×3 = 6 MB)
 *   0x18000000  slice 输出 (n_slices × 8 KB, 同 HUB_SLICEBASE)
 *
 * Linux 移植: 把 DDR 区改成 reserved-memory, 用 /dev/mem mmap 拿指针,
 *   POV_CACHE_FLUSH 改 msync(MS_SYNC) 或留空 (若 reserved-memory 标 no-map
 *   非 cacheable)。pov_render.c / main_render.c 计算逻辑零改动。
 */
#ifndef POV_PLATFORM_H
#define POV_PLATFORM_H

#include <stdint.h>
#include "pov_render.h"

/* ── DDR 物理地址 (裸机) ── */
#define POV_PTS_PHYS    0x16000000U   /* 点云输入 (头 + 点) */
#define POV_LUT_PHYS    0x16400000U   /* transform_lut.bin */
#define POV_VOX_PHYS    0x16800000U   /* vox scratch 6 MB */
#define POV_SLICE_PHYS  0x18000000U   /* slice 输出 = HUB_SLICEBASE */

/* 点云头 magic ("PPC0" 小端 = 0x30435050)。 */
#define POV_PTS_MAGIC   0x30435050U

/* ── HUB75E panel_seq IP 寄存器 (见 pov_boot_src/main.c) ── */
#define HUB_BASE        0x40020000U
#define HUB_CTRL        (HUB_BASE + 0x00U)
#define HUB_PARAM       (HUB_BASE + 0x08U)
#define HUB_TUNIT       (HUB_BASE + 0x14U)
#define HUB_SLICEBASE   (HUB_BASE + 0x18U)
#define HUB_ANGPER      (HUB_BASE + 0x1CU)
#define HUB_NSLICES     (HUB_BASE + 0x20U)

#define SLCR_UNLOCK     0xF8000008U
#define SLCR_LOCK       0xF8000004U
#define FCLK1_CTRL      0xF8000180U

/* ── 平台原语 (裸机实现) ── */
#ifndef POV_PLATFORM_LINUX

#include "xil_io.h"
#include "xil_cache.h"

/* 物理地址 → 可用指针 (裸机恒等映射, DDR 低区 0:1 映射)。 */
static inline void *pov_map(uint32_t phys, uint32_t bytes)
{
    (void)bytes;
    return (void *)(uintptr_t)phys;
}
static inline void  pov_unmap(void *p, uint32_t bytes) { (void)p; (void)bytes; }

/* 寄存器读写。 */
static inline void     pov_reg_wr(uint32_t a, uint32_t v) { Xil_Out32(a, v); }
static inline uint32_t pov_reg_rd(uint32_t a)             { return Xil_In32(a); }

/* slice 数据写 DDR 后必须 flush 到内存, PL DMA 才看得到 (cache 一致性)。 */
static inline void pov_cache_flush(void *p, uint32_t bytes)
{
    Xil_DCacheFlushRange((INTPTR)p, bytes);
}

#else  /* ── Linux stub: 占位, 移植时填 /dev/mem mmap + msync ── */

#include <sys/mman.h>
#include <fcntl.h>
#include <unistd.h>
extern int  pov_devmem_fd;               /* open("/dev/mem", O_RDWR|O_SYNC) */
static inline void *pov_map(uint32_t phys, uint32_t bytes) {
    return mmap(0, bytes, PROT_READ|PROT_WRITE, MAP_SHARED, pov_devmem_fd, phys);
}
static inline void  pov_unmap(void *p, uint32_t bytes) { munmap(p, bytes); }
static inline void  pov_cache_flush(void *p, uint32_t bytes) {
    msync(p, bytes, MS_SYNC);            /* 或 no-op (reserved-memory no-map) */
}
/* 寄存器: 单独 mmap HUB_BASE 一页, 这里略 (移植时补)。 */
void     pov_reg_wr(uint32_t a, uint32_t v);
uint32_t pov_reg_rd(uint32_t a);

#endif

/* ── HUB75E + FCLK1 配置 (sensor 模式, 等效 _run_720_sensor.tcl) ── */
static inline void pov_hub_start(uint32_t slice_phys, int n_slices)
{
    /* FCLK1 = 85.7 MHz */
    pov_reg_wr(SLCR_UNLOCK, 0x0000DF0DU);
    pov_reg_wr(FCLK1_CTRL,  0x00300700U);
    pov_reg_wr(SLCR_LOCK,   0x0000767BU);
    /* panel_seq 寄存器 */
    pov_reg_wr(HUB_TUNIT,     0x000001FFU);   /* 1-bit BCM, t_unit=255 */
    pov_reg_wr(HUB_PARAM,     127U);
    pov_reg_wr(HUB_SLICEBASE, slice_phys);
    pov_reg_wr(HUB_ANGPER,    14577U);        /* fallback period */
    pov_reg_wr(HUB_NSLICES,   (uint32_t)n_slices);
    pov_reg_wr(HUB_CTRL,      0x0000C5E1U);   /* sensor_en|compact|dma_en|overlap|use_fb|en */
}

#endif /* POV_PLATFORM_H */
