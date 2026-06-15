/* pov_boot/main.c — QSPI 自启动: 配置 FCLK1 + HUB75E panel_seq IP 寄存器, 进 sensor 模式跑 720 片 anime.
 * anime 720 片 compact 数据 (5.76MB) 由 FSBL 按 BIF 数据分区 [load=0x18000000] 预加载到 DDR.
 * 等效 tools/_run_720_sensor.tcl 的寄存器写序列. */
#include "xil_io.h"

#define SLCR_UNLOCK   0xF8000008U   /* 写 0xDF0D 解锁 SLCR */
#define SLCR_LOCK     0xF8000004U   /* 写 0x767B 重锁 */
#define FCLK1_CTRL    0xF8000180U   /* FCLK1 分频 -> 85.7 MHz (DCLK 42.9M) */

#define HUB_BASE      0x40020000U
#define HUB_CTRL      (HUB_BASE + 0x00U)
#define HUB_PARAM     (HUB_BASE + 0x08U)
#define HUB_TUNIT     (HUB_BASE + 0x14U)
#define HUB_SLICEBASE (HUB_BASE + 0x18U)
#define HUB_ANGPER    (HUB_BASE + 0x1CU)
#define HUB_NSLICES   (HUB_BASE + 0x20U)

#define SLICE_DDR     0x18000000U

int main(void)
{
    /* FCLK1 = 85.7 MHz: panel DCLK 时基 (超频过 FM6124 30M spec, 720片@490RPM 需要) */
    Xil_Out32(SLCR_UNLOCK, 0x0000DF0DU);
    Xil_Out32(FCLK1_CTRL,  0x00300700U);
    Xil_Out32(SLCR_LOCK,   0x0000767BU);

    /* HUB75E panel_seq 寄存器 (anime 数据已在 DDR 0x18000000) */
    Xil_Out32(HUB_TUNIT,     0x000001FFU);  /* 1-bit BCM, t_unit=255 满亮 */
    Xil_Out32(HUB_PARAM,     127U);
    Xil_Out32(HUB_SLICEBASE, SLICE_DDR);
    Xil_Out32(HUB_ANGPER,    14577U);       /* fake fallback 周期: 490RPM=8.16Hz*720 (丢脉冲兜底) */
    Xil_Out32(HUB_NSLICES,   720U);
    /* CTRL: sensor_en[15]|compact[14]|dma_en[7]|overlap[6]|use_fb[5]|en[0] = 0xC5E1 */
    Xil_Out32(HUB_CTRL,      0x0000C5E1U);

    for (;;) { /* PL DMA + angle_tracker 自主跑, ARM 空转 */ }
    return 0;
}
