---
name: project_dr1m90_jtag_port_checklist
description: 2026-09-17 只读核查 (审计 + 挑错) — JTAG 加载线换 DR1M90GEG484 的移植清单: GP0 基址 0x80000000 / POVJ 窗口 / PS 控制寄存器地址与位 / 身份检查 (子串 anlogic|dr1) / fpga_manager+configfs 都不用改; 要改的是 aarch64 重编 + ELF 机器类型判据 + _riscv64 文件名与 pidof + TD 器件串 + bootgen -arch dr1m90 (4 处) + 挂钩补丁重生; 🔴 头号风险: GP0 主口复位 SRST_CTRL2 bit4 在 DR1V90 上是 OpenSBI 加载 PL 时放开的, DR1M90 靠 ATF, 代码从没检查过这一位; 上板 bin 是 pad128 不是 bootgen 输出, ATF 收不收未知; obs 量具构造上是 DR1V90 专属
metadata:
  type: project
---

# 换 DR1M90 时 JTAG 加载线的移植清单 (2026-09-17)

workflow `wf_1169c978-a59` (只读审计 + 挑错)。背景: 用户 09-17 "下一步大概率换 DR1M90"。DR1M90GEG484 = Cortex-A35 双核 (出处 UG1214 PDF p37 §3.1, 不是 DS1200 表1-1), 与 DR1V90 共用 PINLIST 与 TD 器件库 `dr1_90.db` (device_resource.csv 资源逐列相同)。

## 不用改 (有出处)
- **GP0 基址 0x80000000、POVJ 窗口 0x8001_xxxx**: DR1M90 GP0 同样从 0x80000000 开始 (连续 512MB, UG1214 表5-1/5-2); 集成版顶层按 lite_araddr[28:16]==1 选窗口, 绝对地址或偏移两种理解都命中 (推断)。🔴 之前写"GP0 基址要适配"是错的。
- **PS 控制寄存器地址与位**: PLS_PROT 0xF8800080、HP_WIDTH 0xF8800084、SRST_CTRL2 0xF8801078、FCLK_CNT_DIV 0xF880103C 在 FD 2025.1 addrmap 的 dr1m90/dr1v90 页逐项相同; TOP_CFG_NS/CRP 在 DR1M90 上非 Secure (UG1214 表5-4)。
- **板子身份检查**: 代码是在 compatible / model / fpga0 name 里找子串 anlogic 或 dr1 (pj_gpio.c 等 5 处), 没有写死 anlogic,dr1v90; DR1M90 dtsi model "Anlogic, DR1M90 FPSoc" 与驱动名 "Anlogic dr1m90 FPGA Manager" 都能命中。🔴 之前 HANDOFF/记忆里"身份检查写死 dr1v90"是错的。
- **内核接口**: 厂商 SDK linux 6.1.111 arm64 dtsi 与 riscv dtsi 的 fpga_mgr (anlogic,dr1m90-pcap-fpga @0xF8801000) 与 base_fpga_region 节点相同, 同驱动同打印 "fpga prog successfully"; arm64 defconfig 开 OF_CONFIGFS、未开 STRICT_DEVMEM (前提: 米联客沿用)。
- **PL**: pj_regs.v 与 AXI3→Lite 桥只依赖 GP0 端口集合 (ARM/RISC-V 两个 PS IP 的 gp0/hp0/hp1/p2f/f2p 端口表 md5 相同), 管脚/约束/上电强制 IO 表 (DS1200 表2-6 两颗共用) 不变。
- **GW5A 侧全部** (协议、白名单、判据、.gws、SVF 路线、pj_sram 逻辑): 无架构相关代码; 等待时间同时卡墙钟与 TCK 数 (gw5a_tap.c gw_idle_for), A35 更快不会压短等待。单实例锁 flock 双核有效。

## 要改 (JTAG 线自己约 2~3 人日)
1. **aarch64 重编**: 4 个 Makefile (sw, sw_pinfind, sw_sramload, sw_bridgeload; sw_svf 建好后也要) 加 aarch64 目标 (musl 纯静态非 PIE; 工具链 `~/toolchains/aarch64-linux-musl-cross`、`qemu-aarch64` 已在)。🔴 **产物判据必须断言 ELF 机器类型** (file 含 "ARM aarch64"): 现在 check_riscv.sh 数 R_RISCV, 换 aarch64 永远数出 0 会空过 (PREP §1.3 出过 ARCH=aarch64 编出 RISC-V 的事故)。
2. **文件名**: 板端脚本/打包写死 `*_riscv64` (bridge_load.sh 拷贝与 BL_NEED、mk_stage.sh、install 测试环境); **load_pov_jtag.sh 的 pidof 忙检查按带 _riscv64 的进程名拦截, 改名不同步会漏检**。建议去掉架构后缀或加 uname -m 校验; 重生 MANIFEST。
3. **TD 器件与位流头**: build.sh 器件断言 (pl, pl_pinfind, pl_pov_jtag)、check_build.py Package 断言 3 处、td_gen.py (TD_DEVICE 可覆盖) → DR1M90GEG484; -speed 2 能否接受以试跑为准。
4. **bootgen -arch dr1m90**: 4 处 (三个 build.sh + pl_pov_jtag/tools/gauge_obs.sh:90)。albg1 支持 DR1M90。
5. 🔴 **新增 GP0 主口复位判据 (头号漏项)**: SRST_CTRL2 bit4 nic_gp0m_srst_n 复位值 0; 冷启动实测 SRST_CTRL2=0x1100、PLS_PROT=0x3。DR1V90 上是 **OpenSBI 的 fpga_prog_start/done 在加载 PL 时**置 PLS_PROT、放开 SRST_CTRL2 0x33 (GP0M/GP1M/HP0/HP1), 不是 BOOT.bin (之前记忆说 BOOT.bin 预配是错的)。p2f_clk0 50MHz 靠 FCLK_CNT_DIV 复位值 0x07070707 (前提 FSBL 配 IO PLL)。DR1M90 由 ATF 负责, 会不会照做未查到。⇒ PL 加载后、第一次碰 GP0 前回读 bit4 (显示再看 bit1), 为 0 则读改写只置该位; 涉及 load_pl.sh×2、load_pov_jtag.sh、bridge_load.sh pl 段、pj_gpio.c (注意 PJ_ADDITION 标记外要与 jtag_gpio.c 逐 token 相同的测试约束)。**DR1V90 上也值得补上 (目前靠 OpenSBI 顺手)**。
6. **挂钩补丁重生**: hook/povboot_bridge.sums 按 md5 钉 DR1V90 版 povboot.sh (BASE_MD5 21933ad7), install 脚本不符拒绝 ⇒ DR1M90 版 povboot.sh 定稿后用 tools/mk_hook_patch.py 重生。
7. **离线测试环境**: bridge_env.sh / install_env.sh 用 DR1V90 rootfs 的 riscv64 busybox 跑 qemu ⇒ 换米联客 DR1M90 rootfs 的 busybox (applet 集合未查到), 约半天。
8. SD 卡挂载路径 /mnt/mmcblk0p1 写死或作默认值 (load_pov_jtag.sh、bridge_load.sh、install 脚本、povboot.sh), 米联客 DR1M90 出厂镜像挂在哪未查到。

## 必须等显示 PL 移植
- PS 封装: TD 的 ARM_Processor_System_F9F0D0P0 IP 只允许 DR1M90 器件 (Component.xml deviceRegexp), 与 RISC-V IP 底层同一原语 DR1_PHY_PROCESSOR_SYSTEM; ARM 版多 ACP/PPI/trace、少 FAHB (工程没用); ARM 版 plugin 注释掉了 RPU_FREQ 而现封装传 .RPU_FREQ(766)。先把器件换 DR1M90 原封装试跑 TD (~10 分钟), 拒收再生成 ARM 封装并同步例化名、sdc 层次路径 (u_ps/..._Inst/DR1_PHY_PROCESSOR_SYSTEM_Inst.p2f_clk0)、仿真 stub、md5 钉。
- **零回归基线与量具整体重立**: obs 谱系 (BASE=obs) 与 tools/gauge_obs.sh 构造上是 DR1V90 专属 —— 工程文件与 git 745b66d 逐字节比较 (里面写着 DR1V90GEG484)、要求 pad128 结果等于现役 DR1V90 pl.bin 62431443、rtl/base_obs 含 RISC-V 封装按 git blob 钉死。DR1M90 必须先有正式显示位流再立量具。PREP 对显示 RTL 重过 TD 的估计是几周。

## 上板才能定
- ATF 放不放开 GP0M/HP 复位、清不清 PLS_PROT; TOP_CFG_LOCK 0xF8807000 是否上锁 (靠写后回读发现)。
- **上板 .bin 是 bitconv pad128(bit) (数据补 0xFF 到 128 字节整数倍), 不是 bootgen 输出**; ATF 的 PCAP 加载器收不收未查到 ⇒ 台架位流 pl/ 用 bootgen 输出, 可两种各试一次区分。
- busybox applet、挂载路径、页大小 (大概率 4K)。
- 🎯 **最便宜的去风险办法: 下载米联客 ARM 版 SDK `uisrc-lab-anlogicM`** (reference_dr1_factory_linux_boot 记的网盘表里), 大概率带 ATF 源码 ⇒ 不上板就能查 SiP FPGA_PROG 的 prog_start/prog_done 对 PLS_PROT、SRST_CTRL2 0x33、fclk 复位的处理和接受的 bin 格式。

## 到手当天顺序 (挑错后修正版)
1. 认板: 型号/丝印; 记 BOARD_ID、PnP 实例 (🔴 **PnP 实例跟 USB 口走不跟板走**, 同一口换板实例不变 ⇒ 只认 BOARD_ID + uname -m)、uname -m=aarch64、processor 数 2、getconf PAGESIZE。
2. 只读核内核接口: device-tree model/compatible、fpga0 name/state、soc/base_fpga_region、/proc/config.gz (STRICT_DEVMEM / OF_CONFIGFS / FPGA_MGR)、busybox --list。
3. PL 加载**之前**读一次 0xF8800080 / 0xF8801078 / 0xF8800084 / 0xF880103C (DR1V90 上也只会是 0x3/0x1100/0x0, 只作对照)。
4. 用 DR1M90 器件 + bootgen -arch dr1m90 重出台架位流 pl/ jtag_gpio (只用板载 L18 25M, 不依赖 p2f_clk0), aarch64 版 load_pl.sh 加载; 判据新出现 "fpga prog successfully" 且 operating; **加载后再读上面几个寄存器对比** (看 ATF 的 prog_done 放没放 GP0M/HP 复位)。
5. **确认 SRST_CTRL2 bit4=1 之后**才读 GP0: 0x80000000 期望 MAGIC 0x4A544147; 然后 jtag_idcode (默认 + -d 200) 期望 0x0001281B。
6. 复跑 S2/S3 (jtag_pinfind --apply → status → load --negative → load → reload), 判据同 DR1V90。
7. 显示位流 DR1M90 版就绪后才上 pl_pov_jtag / bridge_load / 挂钩。

相关: [[project_pov3d_jtag_load_bench]] [[project_dr1m90_wifi_retest]] [[feedback_dr1_load_bit_without_jtag]] [[project_pov3d_dr1v90_board_inventory]]
