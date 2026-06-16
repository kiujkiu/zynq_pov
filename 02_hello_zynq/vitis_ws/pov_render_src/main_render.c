/* main_render.c — 裸机入口: 点云 → 720 切片板端渲染。
 *
 * 流程:
 *   1) 从 DDR 0x16000000 读点云头 [magic, count] + count×point_t
 *   2) 从 DDR 0x16400000 读 transform_lut.bin (16384×2 int16)
 *   3) vox scratch @ 0x16800000 清零 + 体素化
 *   4) pov_gen_all → slice 输出 @ 0x18000000 (720×8KB), flush cache
 *   5) 配 FCLK1 + HUB75E 寄存器 (sensor 模式), PL DMA 自主刷屏
 *
 * 点云 + LUT 由主进程用 xsdb dow -data 注入 DDR (见 RUNME_arm.md)。
 * 全部平台相关项在 pov_platform.h; Linux 版只换那个文件。
 */
#include "pov_render.h"
#include "pov_platform.h"
#include "xil_printf.h"

#define N_SLICES   720

int main(void)
{
    /* ── 1) 点云 ── */
    volatile uint32_t *pts_hdr = (volatile uint32_t *)pov_map(POV_PTS_PHYS, 8);
    uint32_t magic = pts_hdr[0];
    int      count = (int)pts_hdr[1];
    const pov_point_t *pts =
        (const pov_point_t *)pov_map(POV_PTS_PHYS + 8, (uint32_t)count * 16U);

    if (magic != POV_PTS_MAGIC) {
        xil_printf("BAD point magic 0x%08x (want 0x%08x)\r\n",
                   (unsigned)magic, (unsigned)POV_PTS_MAGIC);
        for (;;) {}
    }
    xil_printf("point cloud: %d points\r\n", count);

    /* ── 2) LUT ── */
    const int16_t *lut = (const int16_t *)pov_map(POV_LUT_PHYS, POV_NFWI * 4U);

    /* ── 3) 体素化 ── */
    uint8_t *vox = (uint8_t *)pov_map(POV_VOX_PHYS, POV_VOX_BYTES);
    {
        /* 清零 vox (last-write 语义要求未命中格 = 0)。memset 6MB。 */
        uint32_t *p = (uint32_t *)vox;
        uint32_t  n = POV_VOX_BYTES / 4, i;
        for (i = 0; i < n; i++) p[i] = 0;
    }
    pov_voxelize(pts, count, vox);
    xil_printf("voxelized.\r\n");

    /* ── 4) 切片 ── */
    uint32_t *slices = (uint32_t *)pov_map(POV_SLICE_PHYS,
                                           (uint32_t)N_SLICES * POV_SLICE_BYTES);
    pov_gen_all(vox, lut, N_SLICES, slices);
    pov_cache_flush(slices, (uint32_t)N_SLICES * POV_SLICE_BYTES);
    xil_printf("generated %d slices @ 0x%08x\r\n",
               N_SLICES, (unsigned)POV_SLICE_PHYS);

    /* ── 5) 起 panel ── */
    pov_hub_start(POV_SLICE_PHYS, N_SLICES);
    xil_printf("HUB started, CTRL=0x%08x\r\n", (unsigned)pov_reg_rd(HUB_CTRL));

    for (;;) { /* PL DMA + angle_tracker 自主跑 */ }
    return 0;
}
