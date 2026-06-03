---
name: HUB75E v28 改动后 HDMI 渲染管道死, ELF 卡早期 init
description: v28 bit (PS7 FCLK1 75M→60M + hub75e IP rename 0_1→0_3 + 一系列 BD propagation) 跟原 anime ELF 不兼容, VDMA 全 0 没 init, HDMI 黑屏
type: feedback
originSessionId: cddd55be-5600-43d2-9b26-a291ffc28846
---
2026-06-02 想用 HDMI anime 渲染作 LED panel 颜色参考时发现:
- 原 ELF 重 build (`ENABLE_HUB75E_TEST=0`) + dl_helloworld_with_anime.tcl 喂 anime_points.bin (30803 points) + ANIME_MAGIC 触发
- ELF 加载 + ARM con 后, UART 全静 (probe COM10 921600/460800/115200/9600 都 0 bytes)
- xsdb stop 看 ARM PC = 0x00106458 (ELF 代码段早期), 没跑到 main 循环
- xsdb 直接读 VDMA (0x43C10000) CR/SR/Park/Vsize/Hsize/Stride/StartAddr 全 0 → **VDMA 完全没 init**
- HDMI 输出黑 (USB HDMI 采集卡 idx 0 = icspring camera, capture mean=0)

**根因猜测**: v28 BD 改动太多, ELF 内 hardcoded register address / IP-specific config 跟 v28 PL 对不上:
- PS7 FCLK1 75M → 60M (UART/AXI clock derivation 可能改, baud_div 都变)
- hub75e_panel_seq_0_1 → 0_3 rename + xci JSON 重写, BD 地址 map 可能 shift
- xparameters.h 重生成, ELF 用的是旧 xparameters.h

**复活 HDMI 失败 (2026-06-02 实测)**:
- 回滚 PS7 FCLK1 60M→75M (commit `ba34f62`) → ARM 仍 crash 在 Xil_DataAbortHandler
- 重 build ELF 也没救 (xparameters.h 跟当前 v28 BD 不一致)
- ARM PC=0x106458 = `Xil_DataAbortHandler: b 0x106458` (死循环)
- 根因: ELF 早期初始化访问某个 v28 后不存在/改名的 IP 触发 data abort, 没追 LR_abt

**修复路径 (剩下没试的)**:
1. **回滚到 v28 之前的 commit (~adfafa5 grid demo)**: 完整恢复原始 bit + 原始 ELF 兼容性
2. **重写 minimal HDMI demo ELF**: 只 init VDMA+v_tc 显示静态 fb_a, 砍掉 SDIO/dual_core/pov_project/hub75e_bringup 这些可能 crash 的 init
3. **追 LR_abt 找具体 crash 地址**: xsdb 读 banked register 看 ELF 在哪个 IP 访问挂

**当前状态**: HDMI 黑 (放弃修, 用源图 anime_crop.png 当颜色参考), LED panel 走 xsdb mwr -bin -file 路径 (tools/anime_load.tcl) 能显示 anime, panel R>>G>>B + 6-bit BCM 让颜色对比偏弱, 黄色出不来.

**How to apply**: 想在 v28 bit 上跑 HDMI 必须先 regenerate xparameters.h + rebuild ELF. 别盲目 dl 老 ELF.
