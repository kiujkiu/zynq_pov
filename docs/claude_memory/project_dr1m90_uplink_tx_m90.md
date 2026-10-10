---
name: project_dr1m90_uplink_tx_m90
description: 2026-10-10 任务 1.2.3 (离线) — DR1M90 上行真帧发送位流 dr1v90/uplink_tx/m90 出炉, 800M/1.0G 两档 DDRX2 14/14、HWNS 正、pclk 真余量 +46%/+26%; 位级对拍 GW5A rtl_x8 收端全对; X2 接线表 FS03 CEP1→ACG525 P6/P11; 任务 1.1.6 打包脚本按 riscv64/aarch64 选 (tools/pov_arch.sh), povsh_aarch64 编出
metadata:
  type: project
---

# DR1M90 上行发送 (1.2.3) + aarch64 打包 (1.1.6), 2026-10-10, 未上板

dr1v90 commit `c73a5a7` (feature/lvds-b2b)。入口 `dr1v90/uplink_tx/m90/README.md`。

## 1.2.3 结果
- 结构: PS(RISC-V 封装)+GP0(p2f_clk0 50M) + `lvds_b2b/rtl/b2b_pll.v` + `tx_pattern_gen`→`uplink_tx_frame` (原样) + 14×ODDRx2, CEP1 bank33 LVDS18。
- 800M: SWNS -0.201 (过严口径) / HWNS +0.038 / pclk Min Period 2.701 vs 5.0 ⇒ **+46%** / DDRX2 14/14; `out/ul_m90_l800.bin` md5 `8063bda9…`
- 1.0G: SWNS -0.953 (过严) / HWNS +0.050 / 2.953 vs 4.0 ⇒ **+26%**; `out/ul_m90_l1000.bin` md5 `cf27ab49…`。最差 setup 在图案源均匀档 credit 计数 (与链路无关)。
- 仿真 `sim/run_sim.sh [full]`: nib 位串化 (每 lane 任意 bitslip + 0~2 字 skew) → **GW5A `uplink_rx/rtl_x8`** → 公式复算; 逐字节/CRC/beat_phase/帧长/帧号全对, 三种握手 + stop/run + fwd 四档 + 计数/测频; `+inject` 翻 1 bit 抓到。
- GP0: 0x00 MAGIC `0x55545831`; 0x08 CTRL [0]run [2]al_auto [3]al_sw [6:5]fwd_sel; 0x0C TRAIN_US; 0x14 帧数 0x18 beat/16 0x20 pclk kHz。板端 `host/load_ul_m90.sh 800|1000 / run / train / go / stop / fwd N / stat`。

## 踩到并修掉的三个坑
1. **首帧截断**: 图案源帧计时器自由跑, 训练期就放它 ⇒ 帧发生器放行时已在帧中间 (仿真 192/1296 beat)。图案源改随 aligned 一起出复位。
2. **ODDRx2 rst 假 hold -1.6 ns**: 从 pclk 寄存器出 rst, TD 按 IOL removal (对 osclk, 偏斜 2.5 ns) 查。改直接 ~pll_lock (同 lvds_b2b)。
3. **fabric→IOL d 端 hold -0.035~-0.070 (800M, fast 角)**: pclk 到 IOL opclk 比到 fabric 晚 0.4~0.95 ns, fix_hold 已开也修不掉; 加上升沿 dont_touch 寄存器无效 (测试图案 base^常数使不同 lane 同 bit 等价, TD 仍合并)。**出线寄存器改 pclk 下降沿** 后两档 HWNS 转正。

## X2 接线 (gen_ul_m90_adc.py --map)
时钟 CEP1.5/6 (G15, R187) → ACG525 **P11-20/19 (L15 GCLKT_6A)**; lane0~5 = CEP1.35~46 (lvds_b2b 1.0G 满眼那 6 対) → P6-1/2,3/4,5/6,7/8,9/10,13/14; lane6~12 = CEP1.3,13,15,17,19,21,23 → P6-15..28 (lane12 校验 = P6-27/28)。
- 换 0Ω: 全 14 対 8 只 (R187/189/190/191/192/195/196/197); clk+lane0~5 只要 4 只 (R187/195/196/197)。
- 电平: DR1 LVDS18 VOCM 0.6 在 GW5A VICM 0.3~2.35 内, 直连; J2 必须 1.8V。伪地 20 脚只许接 ACG525 GND。
- 🔴 GW5A 收端 (rtl_x8 / gw5a_bridge) FCLK 现在是**本地 PLL**, 跨板必须改成转发时钟派生, 否则两晶振滑位。rx 要 13 lane 全齐才出帧; 只接 6 lane 时只能扫眼/训练码误码。
- 无回读线: 握手由 GP0 合成 (al_auto 训练 TRAIN_US 后放行 / al_sw 软件放行); 收端掉锁要 stop+run。

## 1.1.6
- `tools/pov_arch.sh` = 唯一架构表 (POV_ARCH / --arch / POV_DEVICE=*M90*)。aarch64: povctl_aarch64, povmem `board/povmem/a64/povmem_dr1_a64.ko`, pov_rxd_aarch64, pl.bin=`td_pov/m90/pov_m90.bin`, iperf3_aarch64, `boot/dr1m90_wifi/*_aarch64.tar.gz`, 无 dtb_cma96; 启动链取 `boot/factory_card_dr1m90`, boot.scr initrd 0x15000000 / dtb 0x14000000, `mkimage -A arm64`。
- 改: stage_to_card / make_card_image_dr1 (+--dry-run) / stage_plan / deploy_step5 (+--dry-run) / povsh_build / check_card_payload (两架构都比 + 核 riscv64 与改前一致)。riscv64 dry-run 输出与旧版逐行相同 (只多一行架构头)。
- `board/povsh/povsh_aarch64` 新编 (static-pie, 无 SVE, qemu -V 通过)。pov_rxd/ksink/povctl aarch64 已有。
- 剩 D18: aarch64 没有带 S95pov 的 rootfs (make_card_image 默认被 assert_rootfs 拦, ALLOW_NO_S95POV=1 才出); povboot.sh 的 stage_enable 还没改成"加载后 0x33 + bit4 回读"。

相关: [[project_dr1_uplink_tx_probe]] [[project_pov3d_lvds_b2b_bench]] [[project_dr1m90_d1_display_bit]] [[project_gw5a_bench_1009]] [[reference_fs03_cep_connector_pinout]]
