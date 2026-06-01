/* hub75e_bringup.c - HUB75E FM6124 panel bring-up demo (Phase 1)
 *
 * 用法: 在 helloworld.c main() 早期 (init_platform 之后) 调:
 *     hub75e_bringup_main();   // 不返回
 *
 * 行为: 自动循环 8 个 PL 内置 test pattern, 每个停 3 秒, 串口播报状态.
 *       前置假设: ADDR mode 默认 ABCDE (CTRL[4]=0); panel = shift register
 *       时调 hub75e_set_addr_mode(1) 切.
 */

#include <stdio.h>
#include "xil_printf.h"
#include "sleep.h"
#include "panel_hub75e.h"

/* 编译期可改: 默认 ABCDE; 跑 multivox 同款 panel 时设 1. */
#ifndef HUB75E_USE_SHIFT_REG_ADDR
#define HUB75E_USE_SHIFT_REG_ADDR 0
#endif

/* mode 0/1 单色显示用的颜色 (R1G1B1R2G2B2, 1-bit per channel). */
static const u32 g_solid_colors[] = {
    HUB75E_COLOR_BOTH(1,0,0),   /* 红 */
    HUB75E_COLOR_BOTH(0,1,0),   /* 绿 */
    HUB75E_COLOR_BOTH(0,0,1),   /* 蓝 */
    HUB75E_COLOR_BOTH(1,1,1),   /* 白 */
    HUB75E_COLOR(1,0,0,0,0,1),  /* 顶红 底蓝 (验证 RGB1 vs RGB2 分得开) */
    HUB75E_COLOR(0,1,0,1,0,0),  /* 顶绿 底红 */
};
#define N_SOLID_COLORS (sizeof(g_solid_colors)/sizeof(g_solid_colors[0]))

static const char *mode_name(u32 m) {
    switch (m) {
        case HUB75E_MODE_SOLID:      return "SOLID";
        case HUB75E_MODE_HSTRIPE:    return "HSTRIPE 8 color";
        case HUB75E_MODE_VSTRIPE:    return "VSTRIPE 8 color";
        case HUB75E_MODE_CHECKER:    return "CHECKER";
        case HUB75E_MODE_ROW_WALK:   return "ROW WALK (verify ADDR)";
        case HUB75E_MODE_COL_WALK:   return "COL WALK (verify shift)";
        case HUB75E_MODE_GRADIENT:   return "GRADIENT 8 color";
        case HUB75E_MODE_FULL_WHITE: return "FULL WHITE";
        default:                     return "?";
    }
}

void hub75e_bringup_main(void) {
    xil_printf("\r\n[hub75e] === Phase 1 bring-up @ 0x%08x ===\r\n",
               (unsigned)HUB75E_BASE);
    xil_printf("[hub75e] target: FM6124 128x64 1/32 scan, DCLK=30 MHz\r\n");
    xil_printf("[hub75e] ADDR mode: %s\r\n",
               HUB75E_USE_SHIFT_REG_ADDR ? "shift-register (multivox)" : "ABCDE 5-bit");

    /* 1. 初始化 + 关 enable */
    hub75e_init();
    hub75e_set_addr_mode(HUB75E_USE_SHIFT_REG_ADDR);
    hub75e_set_scan(5);   /* 1/32 */
    hub75e_set_param(128, 8, 10);

    /* 2. 跑单色循环 (mode 0) 6 种, 验证 RGB1/RGB2 单独点亮 */
    xil_printf("[hub75e] phase A: solid colors\r\n");
    hub75e_set_mode(HUB75E_MODE_SOLID);
    hub75e_enable(1);
    for (u32 i = 0; i < N_SOLID_COLORS; i++) {
        hub75e_set_color(g_solid_colors[i]);
        u32 c = g_solid_colors[i];
        xil_printf("[hub75e]  solid %d: COLOR=0x%02x (R1G1B1=%d%d%d R2G2B2=%d%d%d) frame=%u\r\n",
                   (int)i, (unsigned)c,
                   (int)((c>>0)&1), (int)((c>>1)&1), (int)((c>>2)&1),
                   (int)((c>>3)&1), (int)((c>>4)&1), (int)((c>>5)&1),
                   (unsigned)hub75e_frame_count());
        sleep(3);
    }

    /* 3. 跑剩余 7 个内置 pattern */
    xil_printf("[hub75e] phase B: built-in patterns\r\n");
    for (u32 m = HUB75E_MODE_HSTRIPE; m <= HUB75E_MODE_FULL_WHITE; m++) {
        hub75e_set_mode(m);
        xil_printf("[hub75e]  mode %u (%s) frame=%u\r\n",
                   (unsigned)m, mode_name(m), (unsigned)hub75e_frame_count());
        sleep(3);
    }

    /* 4. Framebuffer demo (use_fb mode) */
    xil_printf("[hub75e] phase C: framebuffer demo\r\n");

    xil_printf("[hub75e]  fb fill 100%% RED\r\n");
    hub75e_fb_fill(0x0000FF);
    hub75e_set_mode(HUB75E_MODE_SOLID);   /* mode 不变, use_fb 接管 */
    hub75e_use_fb(1);
    sleep(3);

    xil_printf("[hub75e]  fb fill 50%% GREEN\r\n");
    hub75e_fb_fill(0x008000);
    sleep(3);

    xil_printf("[hub75e]  fb fill 25%% BLUE\r\n");
    hub75e_fb_fill(0x400000);
    sleep(3);

    xil_printf("[hub75e]  fb vstripe 8 颜色 (BCM 真彩)\r\n");
    hub75e_fb_demo_vstripe();
    sleep(5);

    xil_printf("[hub75e]  fb 渐变 R/G/B 三色横分 (每 21 行一色, 灰阶横向)\r\n");
    for (u32 y = 0; y < 64; y++) {
        u32 chan = (y / 22) & 3;   /* 0=R, 1=G, 2=B */
        for (u32 x = 0; x < 128; x++) {
            u32 grad = (x * 255) / 127;
            u32 rgb = (chan == 0) ? grad
                    : (chan == 1) ? (grad << 8)
                    : (grad << 16);
            hub75e_fb_set(x, y, rgb);
        }
    }
    sleep(5);

    /* 切回 LUT mode 显示 full white 烤机 */
    hub75e_use_fb(0);
    hub75e_set_mode(HUB75E_MODE_FULL_WHITE);

    /* 5. 死循环停在 FULL WHITE 烤机模式 */
    xil_printf("[hub75e] done. holding FULL WHITE. STATUS poll every 5s.\r\n");
    while (1) {
        sleep(5);
        u32 st = hub75e_status();
        xil_printf("[hub75e] STATUS=0x%08x running=%d cur_addr=%d frames=%u\r\n",
                   (unsigned)st, (int)(st & 1),
                   (int)((st >> 8) & 0x1F),
                   (unsigned)((st >> 16) & 0xFFFF));
    }
}
