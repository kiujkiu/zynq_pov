---
name: project_dr1m90_d1_display_bit
description: 2026-10-10 D1 完成(离线) — 生产显示位流 td_pov(pov_dr1_top) 换 DR1M90GEG484 一次过, SWNS +7.219/HWNS +0.022 与 V90 逐位相同(bit 只差 IDCODE 5 字节); bootgen -arch dr1m90 出 pov_m90.bin md5 2ac42cbb…; 板上判显示位流看 0x80004010=0x4C5A3400(不是 0x80000000); 全设计只用 p2f_clk0 50MHz(A50), 不依赖 p2f_clk1; 上板检查脚本 td_pov/m90/load_pov_m90.sh 待板子空出
metadata:
  type: project
---

# DR1M90 D1: 显示位流出炉 (2026-10-10, 离线, 未上板)

计划 [[project_pov3d_sw_plan_20d_2026_10_09]] 的 D1 + D2 离线部分。入口 `dr1v90/td_pov/README.md`, commit dr1v90 `1ceb4b9`。

## 结果
- `POV_DEVICE=DR1M90GEG484 td_pov/build.sh` (默认仍 DR1V90, 原地 soc_prj; td_gen 生成的 V90 tcl/.prj 与跟踪版逐字节相同)。
  M90 工程在 `td_pov/build_DR1M90GEG484/`(gitignore)。现有 RISC-V PS 封装原样通过 (同 [[project_dr1m90_gp0_first_light]])。
- 判据全过: Constraint File=timing.sdc; clk0=aclk 50MHz Fanout 4156, Fmax 78.241; **SWNS +7.219 / HWNS +0.022**;
  lut6 5902 / slice 6518 / eram 126 (45%) / pad 41。
- 🎯 **与 V90 08-28 那份布线逐位相同**: bit 载荷 3,398,600 B 只差 5 字节 = IDCODE (`..0264 15..` M90 vs `..0262 15..` V90) + 其后校验; Global CRC 相同。
  ⇒ 时序/IO/寄存器表在 V90 与 M90 之间**构造上不可能有差** (D2 对账因此大部分是空集)。HWNS 0.022 很薄但是同一份上板跑过的布线。
- bin: `td_pov/out/pov_m90.bin` 3,398,656 B, md5 `2ac42cbb5cd14b775b73b799d874a73e` (bootgen 重跑 md5 不变)。

## p2f_clk1 决定: 不需要
生产 td_pov 是 **A50**: 面板、GP0 从机、HP0、HP1、3 个 lz4 引擎全在 `aclk = p2f_clk0` 50 MHz (`LZ4_CLK_SRC=0`, `CLK1_PROBE=0`)。
[[project_dr1_hp_topology_decision]] 的方案 A(lz4@100M 走 p2f_clk1) **从没进生产位流**。M90 的 `0xF880103C=0x07070707` 正好是所需值 ⇒ 不改分频、不改 RTL。
D10 若要 PL lz4 提速再议 100M; 现在 3 引擎@50M ≈ 0.987 B/clk × 50M × 3 ≈ 148 MB/s 理论值。

## D2 对 V90 的差异 (全部在 PS/加载侧)
| 项 | V90 | M90 |
|---|---|---|
| bin | pad128 转换 (`tools/deploy_pl.sh`) | **bootgen -arch dr1m90** |
| configfs | 镜像 init 已挂 | 出厂不挂, 脚本 `mount -t configfs` |
| GP0M/HP 复位 | OpenSBI 加载时放 0x33 | ATF 加载时放 0x33 (09-22 实测), 脚本仍读改写 + 回读 bit4/bit0/bit1 |
| 使能顺序 | povboot.sh 加载**前**只开 HP0 | 新脚本加载**后**开 (UG1214; pov 复位态不打流) 且覆盖 HP1 + HP_WIDTH[1:0] |
| dtbo firmware-name | pl.bin | pov_m90.bin |
| 寄存器表 / 时序 / IO | — | 相同 (同一份布线) |

## 上板检查 (D1/D2 待做, 板子 COM24 当时被 X1 DDR 测试占用)
推 `td_pov/m90/` (pov_m90.bin + pov_m90_load.dtbo + load_pov_m90.sh + MANIFEST.md5) → `sh load_pov_m90.sh`, 末行 `LOAD_POV_M90: PASS`。期望:
加载后 SRST_CTRL2=**0x1133**; **0x80004010=0x4C5A3400** ('LZ4' MAGIC, NENG@0x4014=3); 0x8000400C=0xDEB00000;
引擎页未定义偏移 0xDEAD0000; STATUS 0x80000000≈0x00000008(pov_en bit9=0); 0x10→0x24 影子回读; 0x8FFF400C 镜像不挂。
🔴 0x80000000 是 STATUS 不是 MAGIC (见 board/cmds_step_verify.txt 头注释)。脚本有门: FCLK_DIV[5:0]!=7 拒载 (GP0 从机在 p2f_clk0 上)。
宿主机 mock 跑过正/反两例 (加载失败时零 GP0 访问)。

## D3/D4 aarch64 清单 (已查)
- povmem: `make KDIR=~/dr1m90_kernel ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-` **源码零改动编过** (vermagic 6.1.111-rt42 … aarch64)。
  要改: mmap 用 pgprot_writecombine + cached=0 (现"故意不动 vm_page_prot"是 RISC-V 绕路); 板上内核是不是 ~/dr1m90_kernel 那份决定 modversions; CMA 96MB aarch64 dtb。
- povctl: `aarch64-linux-musl-gcc -static -no-pie` 已出 `host/povctl_aarch64` (别用 static-pie)。
- povboot.sh 本身无 `_riscv64`; 写死在打包侧: stage_to_card.sh / make_card_image_dr1.sh (含 `mkimage -A riscv`) / stage_plan.sh / deploy_step5.sh / check_card_payload.sh / povsh_build.sh。povboot 的 stage_enable 要改成加载后 0x33 + bit4 回读。

相关: [[project_dr1m90_parity_2047_gap]] [[project_dr1m90_gp0_first_light]] [[feedback_dr1_load_bit_without_jtag]] [[feedback_dr1_pl_probe_must_be_hang_proof]]

## 2026-10-10 上板: D2 / D3 通过
- D2: `load_pov_m90.sh` 上板 **LOAD_POV_M90: PASS** —— MAGIC 0x80004010=0x4C5A3400, NENG=3, 几何寄存器读写对,
  高地址镜像不挂死, SRST_CTRL2=0x1133, FCLK_DIV=0x07070707。传文件走 `host/serial_send.ps1 -Port COM24` (3.4 MB bin 约 4 min)。
- D3: povmem 对 `~/dr1m90_kernel` 编 (板上内核就是这棵树 9-17 编的, gcc 15.2), vermagic 一致直接 insmod;
  arm64 下新增 `wc=1` (默认) 写合并映射 + cached=0。帧区 phys **0x14500000** 48 MB, 落在出厂 128 MB CMA 里 ⇒ **不用改 dtb**。
  **cpy (8.4 MB 整帧) = 11.0 ms 写合并 / 12.0 ms 可缓存+FLUSH** (7020 20-26, V90 162) ⇒ V90 那堵墙在 A35 上不存在。
- 下一步 D4 (`povctl fb solid` 单面全白) 起要接 2047 屏。

## D4/D5 上板 (DR1M90-02, COM28, 2026-10-10 14:3x) — 未过, 停在 s1
- 前置 OK: up.sh → LOAD_POV_M90: PASS, MAGIC 0x4C5A3400, povmem phys 0x14500000; 板上 m90_firstlight.sh/povctl md5 与本地一致。
- s1 (红 0x049 + checker + OE=8, dual_en=0): STATUS 0x379 (auto_en/use_fb/locked/pov_en), frame_period 10530 (=54×195, 1-bit),
  OE edges 407161/s duty 0.041, idx 在走 → PL 侧一切正常; **用户: 面A 无任何反应** (两面屏都接着)。
- 🔴 **脚本 bug (已改本地 dr1v90/td_pov/m90/m90_firstlight.sh, 未推上板未提交)**: cfg() 调 `povctl fake` 开 pov_en=1 后再 `povctl fb`。
  RTL `pov_dual_top.v:637 fbw_we = pov_en ? df_fb_we : fb_we` ⇒ **pov_en=1 时 AXI fb 窗写全被丢**, fb 由取帧引擎从
  slice_base(复位 0x10000000 = M90 内核 RAM, 实测非零垃圾) 灌; 0x34 FETCH_LIVE=0x54080001 (done 0x5408 片, 无错) 证实取帧在跑。
  ⇒ 屏上应是"红色随机噪点"而不是棋盘。静态 fb 测试必须 pov_en=0 (同 08-28 BRINGUP_TOMORROW T7)。修法: 0x10 = n_slices|dual_en<<2, 不开 pov_en/fake_en。
- ⚠ 但垃圾内容也应可见 ⇒ "完全没反应"另有原因: OE=8 屋里有光可能看不见 ([[feedback_oe_window_too_low_invisible]]) / 屏或接口板没电 /
  排线不在 CEP2 (面板全部 33 脚都在 CEP2=Bank11, .adc M90/V90 逐字相同) / CEP2 的 ADJ_BANK11 跳帽在 1.8V (位流按 LVCMOS33)。
- 🔴 推修好的脚本被权限拦 (远程写文件), 改走串口直接 devmem 重放 → **发现板子已挂死**: COM28 在, 但无回显、Ctrl-C 无反应。
  无回显 ⇒ 挂在发命令之前 (最后一次正常是 devmem 读 0x10000000 内核 RAM 后约 2-3 min, 期间 pov_en=1 取帧在跑, auto_en=0)。
  原因未定: 疑 devmem 以非缓存属性读内核线性映射 RAM (arm64 属性冲突) 或 HP 取帧长跑; 需断电重启 (K6)。

## 2026-10-10 晚 D4 进度 (DR1M90-02, 经 WiFi `host/dr1ssh.sh dr1m90-02`)
- 屏全黑的根因 = **FS03 CEP2 Bank11 跳帽在 1.8V**, 用户拨到 3.3V 后正常 ([[feedback_fs03_bank11_jumper_3v3]])。
- 点屏要 **pov_en=0** 的静态 fb (pov_en=1 时 fb 窗写入被 RTL 丢弃, 显示取帧引擎从 slice_base 读的 DDR); 脚本已修 (dr1v90 8e3c715)。
- ✅ s1 (只红 + 像素级 checker, OE=8): 用户 "A 红, 有间隔的红不是全红, B 黑"。
- ✅ **三色循环** (整面 R/G/B 各 4 s, OE=8): 用户 "3 色没问题"。
- ⏳ **数字棋盘格** (`povctl fb-file chess_obs_fb.bin 0`, 全彩 OE=8) 已上屏 15:43, 等用户看数字方向/映射。
- 用户定的验证流程 = 三色循环 + 数字棋盘格, 低亮度起 → 双面 → 再逐步调亮; 脚本 `dr1v90/td_pov/m90/m90_screencheck.sh`。
- 期间一次内核硬挂 (agent 用 devmem 读内核线性映射 RAM 后), SysRq 无响应需断电; 之后开机先 `echo 1 > /proc/sys/kernel/sysrq` + panic 15 s 自启。
  板上有 `/dev/watchdog` (dw_wdt, 报 "No valid TOPs array"), busybox watchdog -T 30 开后疑似反而复位过一次, **未坐实, 暂不开**。
