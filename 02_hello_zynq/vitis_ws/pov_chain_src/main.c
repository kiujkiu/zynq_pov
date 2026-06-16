/* pov_chain/main.c — 全芯片链: 点云 → ARM 体素化 → pov_proj 切片 → 显示.
 * "发点云, 体素化+切片+显示全在芯片" (路线 A). 着色 = 点云自带 RGB (不算光照).
 *
 * DDR 布局 (JTAG 注入):
 *   0x16000000  点云: [magic 'PPC0'(0x30435050), count(u32), point_t[count]]
 *   0x1B000000  transform_lut.bin (64KB)
 *   0x1C000000  voxel_t 网格 (128^3 x 4B = 8MB), ARM 写, pov_proj 读
 *   0x18000000  compact ring (720 x 8KB), pov_proj 写, 显示 IP 读
 */
#include "xil_io.h"
#include "xil_cache.h"

#define PTS_ADDR   0x16000000U
#define LUT_ADDR   0x1B000000U
#define VOX_ADDR   0x1C000000U
#define RING_ADDR  0x18000000U
#define PPC0_MAGIC 0x30435050U

#define GRID       128
#define VOX_BYTES  (GRID*GRID*GRID*4)   /* 8 MB voxel_t */
#define MAX_PTS    400000               /* invalidate 上限 */

/* pov_proj AXI-Lite (base 0x43C20000) */
#define PB         0x43C20000U
#define PB_AP      (PB+0x00U)
#define PB_VOX     (PB+0x10U)
#define PB_LUT     (PB+0x1CU)
#define PB_SB      (PB+0x28U)
#define PB_NT      (PB+0x34U)
#define PB_SS      (PB+0x3CU)
#define PB_NS      (PB+0x44U)

/* 显示 IP HUB75E (0x40020000) */
#define HUB        0x40020000U
#define SLCR_UNLK  0xF8000008U
#define SLCR_LK    0xF8000004U
#define FCLK1      0xF8000180U

static inline int clip127(int v){ return v<0?0:(v>127?127:v); }

int main(void)
{
    /* 1) 读点云头 (JTAG 写的 DDR, 先 invalidate 拿新鲜数据) */
    Xil_DCacheInvalidateRange(PTS_ADDR, 8U + (u32)MAX_PTS*16U);
    u32 magic = Xil_In32(PTS_ADDR);
    int n     = (int)Xil_In32(PTS_ADDR + 4);
    if (magic != PPC0_MAGIC) { n = 0; }   /* 头不对 → 不体素化 (grid 留空) */
    if (n > MAX_PTS) n = MAX_PTS;
    const u8 *pts = (const u8 *)(UINTPTR)(PTS_ADDR + 8);

    /* 2) 清网格 + 体素化 (voxel_t 4B: r,g,b,pad; idx ((vx*128+vy)*128+vz)*4) */
    u8 *vox = (u8 *)(UINTPTR)VOX_ADDR;
    for (u32 i = 0; i < VOX_BYTES; i++) vox[i] = 0;
    for (int i = 0; i < n; i++) {
        const u8 *p = pts + (u32)i*16;
        s16 x = (s16)(p[0] | (p[1]<<8));
        s16 y = (s16)(p[2] | (p[3]<<8));
        s16 z = (s16)(p[4] | (p[5]<<8));
        u8 r = p[8], g = p[9], b = p[10];          /* point_t: r,g,b @ off 8,9,10 */
        int vx = clip127((int)x+64), vy = clip127((int)y+64), vz = clip127((int)z+64);
        u8 *c = vox + (((u32)((vx*GRID+vy)*GRID+vz))*4U);
        c[0]=r; c[1]=g; c[2]=b; c[3]=0;            /* last-write */
    }
    /* pov_proj 经 HP1 读 DDR → flush 让网格落 DDR */
    Xil_DCacheFlushRange(VOX_ADDR, VOX_BYTES);

    /* 3) 触发 pov_proj 切片 720 片 → RING */
    Xil_Out32(PB_VOX, VOX_ADDR);
    Xil_Out32(PB_LUT, LUT_ADDR);
    Xil_Out32(PB_SB,  RING_ADDR);
    Xil_Out32(PB_NT,  720);
    Xil_Out32(PB_SS,  0);
    Xil_Out32(PB_NS,  720);
    Xil_Out32(PB_AP,  0x1);                        /* ap_start */
    while (!(Xil_In32(PB_AP) & 0x2)) { ; }         /* 等 ap_done */

    /* 4) 配显示 IP (sensor 模式, 读 pov_proj 写的 ring) */
    Xil_Out32(SLCR_UNLK, 0x0000DF0DU);
    Xil_Out32(FCLK1,     0x00300700U);             /* FCLK1 85.7M */
    Xil_Out32(SLCR_LK,   0x0000767BU);
    Xil_Out32(HUB+0x14, 0x000001FFU);              /* TUNIT 1-bit 满亮 */
    Xil_Out32(HUB+0x08, 127U);
    Xil_Out32(HUB+0x18, RING_ADDR);                /* SLICE_BASE */
    Xil_Out32(HUB+0x1C, 14577U);                   /* ANGLE_PERIOD fallback */
    Xil_Out32(HUB+0x20, 720U);                     /* N_SLICES */
    Xil_Out32(HUB+0x00, 0x0000C5E1U);              /* CTRL sensor_en */

    for (;;) { ; }
    return 0;
}
