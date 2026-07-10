---
name: icnd2047-p3-bring-up-worktree-build
description: 第二块鹿小班+第二下载器+ICND2047屏 bring-up 测真实fps; 跟第一块板(FM6124)严格区分; worktree/分支/cable SN/寄存器/build坑全表
metadata: 
  node_type: memory
  type: project
  created_at: 2026-06-16
  updated_at: 2026-06-17
  originSessionId: 8499b7fd-f014-43d7-a23c-f4f4b77598b8
---

# 🔴 两套板子严格区分 (别搞混)

| | **板 1 (勿动)** | **板 2 (ICND2047 bring-up)** |
|---|---|---|
| panel | FM6124 双屏 (转接板) | **ICND2047 128×64 32扫 HUB75E** |
| 接口 | — | MTR 转接板 **P3 (=panel2)** |
| 仓/工作区 | 主仓 `D:\...\zynq_pov` | **worktree `D:\...\zynq_pov_icnd2047`** |
| 分支 | `debug/fm6124-v29` (HLS点云 **WIP 未提交, 勿切勿动**) | `debug/icnd2047-mtr-p3` (基于 feature/hub75e-fm6124-12864) |
| 下载器 cable SN | **210251A08870** (memory 记录) | 第二个下载器 (SN 未记, jtag targets 看) |

## 🔴🔴🔴 烧棋盘格反复挂死根因 (2026-06-29, 耗数小时查清, 最后收工未烧成)
**症状**: `xsct _flash_icnd.tcl` 烧 ICND2047 棋盘格, `fpga -file` 反复挂死 / `fpga initialization failed` / 后续连 `stop`/`jtag frequency` 都挂, 多次冷循环无效, 最终确诊 DAP 锁 `0x30000021`.
**真根因**: 当时 JTAG 上的鹿小班(SN 210251A08870)**从 QSPI/SD 脱机自启动** FM6124 globe BOOT.bin → FSBL 用 **PCAP 把 PL 配好 + ARM 跑 globe + panel IP HP-DMA 在飞**. JTAG `fpga -file` 重配 PL ↔ PCAP配置/在飞DMA 冲突 → **DAP sticky 0x30000021**(A9 核全消失). 冷循环又自启又锁=死循环. 跟棋盘格代码无关(bit 3.9M header正确, 06-17验证版, 代码最新).
**⚠ 还有板身份疑点 (下次先查清)**: `210251A08870 = 板1 FM6124`(本 memory 顶部), 而**板2 ICND2047 = 第二块鹿小班+第二下载器**(本 memory description). 这次自启的是 FM6124 globe → **当时连的很可能是板1, 不是 ICND2047 板2**. 下次先 `jtag targets` 核对 SN + 确认 ICND2047 panel 到底接哪块, 别又对着板1 烧 ICND bit.
**✅✅ 最终烧成 (2026-06-30) — 能用配方**: 跑 `_flash_icnd_log.tcl` STEP8 DONE, CTRL=0x507/PARAM=127/STATUS run+frame_count在涨, 棋盘格点亮. 关键两步:
1. **拔掉 SD 卡 + 冷循环** → 板子不自启 globe → PL 空/ARM idle = 冷板 (比拨 SW3 更省事, SD 就是自启 globe 的来源).
2. **冷板烧录脚本流程**: connect → 降频5MHz → stop ARM两核 → **直接 fpga(不写CTRL=0!)** → ps7_init → FCLK1=0x00600600(50M) → CTRL=0x507. fpga 冷板 try1 即过.
   - 🔴 **冷板绝不能先 CTRL=0**: PL空时 `mwr 0x40020000 0` 往空AXI slave写 → 锁DAP 0xF0000021. (热板才先停DMA). 这是我这次踩的最后一坑.
**(旧备选)** 或拨 SW3 到 JTAG boot mode (见 [[feedback_lxb_boot_mode_sw3]]) 也能得冷板, 但拔SD最省事.

## ✅ fb 数字棋盘 + 真6bit + overlap + 时序收紧 (2026-06-30~07-02)
**fb 路径显真内容**: CTRL bits `[0]=en [3:1]=mode [5]=use_fb [6]=overlap [15:13]=planes(6=6bit,0=默认6)`. fb BRAM AXI @ **0x40028000**(addr[15]=1, 8192像素). 灌帧 `tools/_fb_load.tcl`(16条bulk mwr, gen_chess32.py 生成128×64数字棋盘=32格HSV唯一色+白数字). **CTRL 0xC521=fb+6bit+overlapOFF / 0xC561=+overlap**. PARAM=127(W128全屏)/15(W16). TUNIT=亮度/t_unit.
- **🔴 fb build 坑**: runs/impl_1 的 06-17 bit 是 **stub(fb_dout=0)**; fb代码在 imports/hdl .v(分支535a862). 重build时 **reset_run hello_zynq_synth_1+synth_1 → synth 会重读fb .v**(runme.log见"fb line369"+"fb_we_count Unused removed"). **headless build 现在能成**(之前18次失败是fresh-checkout无.gen; 有.gen后 reset_run+launch_runs impl→bitstream 直接过, SmartConnect不黑盒 — 推翻"必须GUI"结论!). **fb_we(0x40020018)读0不可靠** — 那计数器被优化删了, 但fb_top BRAM显示路径保留 → **看屏判断别看fb_we**.
- **🔴🔴 overlap ↔ 真6bit 矛盾 (核心, 用户scope实证)**: overlap显示窗口=`max(shift, disp_target)`(S_OV_RUN sh_done门控). W=16 shift≈16拍 → 小plane(disp_target<16)全被撑成16 → **OE宽度都一样=假6bit**(低5个plane同宽只MSB不同). 真6bit(OE=1:2:4:8:16:32)**必须 overlap OFF**(S_DISPLAY disp_count>=disp_target精确). 实测fps: overlap ON t_unit=1=**11,098**(假6bit)/t_unit=2=**8,265**(假); **overlap OFF t_unit=1=7,551(真6bit)**. **单latch上"快"与"真6bit"不可兼得** — 这是[[project_pov3d_panel_fps_roadmap]]"单缓冲藏不住小plane"的视觉铁证.
- **时序收紧 (非-overlap路径 S_LATCH/GAP/ADDR/DISPLAY)**: LE宽度 `latch_edges_target` 5/4/3→**1拍(~20ns)**(外部ABCDE行选+LE期DCLK停低=纯脉冲, 不需命令编码, 注释自己说"不需3/4/5"); LATCH_GAP **硬编码1拍**(S_LATCH_GAP `ctrl_count==0`). clk→le/oe→clk各1拍已最小(S_DISPLAY_END推进plane去不掉). ⚠LE=20ns若<chip twLE屏锁不住则bump 2拍.
- **🔴 BD param 覆盖坑**: BD wrapper(.gen synth .v) **硬传 `.LATCH_GAP_CYC(2)` 等 module params 覆盖 .v default**(且BD缓存module_ref params). 改内部FSM逻辑(硬编码常量)绕开, **别指望改 .v parameter default 传播到BD**. (同 [[feedback_vivado_bd_addr_width_cache]])
**途中查清真相 (已固化进 tools/_flash_icnd_log.tcl)**:
- ① **stop-DMA 先于 fpga**: live 板烧前 `mwr 0x40020000 0`+300ms 停 DMA, 否则在飞 AXI 掐死锁 DAP. 解了"挂死"(之后变 clean exit + 清晰报错), 但自启板还不够.
- ② **双 JTAG fpga 报 `Multiple FPGA devices(4,8)`** → 按 SN 选 **xc7z020 器件**(非 APU): `targets -filter "jtag_cable_name=~{*210251A08870*} && name=~{*xc7z020*}"`.
- ③ **`jtag_cable_name` 过滤只对 `jtag targets`(链)有效, 对 debug `targets`(A9核)无效会报错中断** → debug 靶子单板用简单 `name=~{*Cortex-A9*#0*}` + catch 包.
- ④ **别 churn**: 孤儿 `rdi_xsct` 不停重启 hw_server 毒化后续; `timeout` 杀 xsct 留孤儿. 清: PowerShell `Get-Process rdi_xsct,hw_server | Stop-Process -Force`(taskkill 有时杀不动). 一个 session 干完, 0 探测重连.
- ⑤ 脚本: `_flash_icnd_log.tcl`(每步flush→flash_progress.txt, 挂住也看卡点) + `_finish_icnd.tcl`(不烧bit只ps7_init+CTRL, 验bit是否还在PL).

测试纪律: **一次只插一块板 JTAG** (2026-06-16 用户已拔第二个) → 原始 name-based 选靶即可; 两块都插才用 SN 脚本. **绝不 taskkill hw_server** (会掐断对方 active 会话). build 是纯 PC 综合, 不碰板子, 跟对方调板互不干扰.

# ICND2047 IP 复用 (v30, 来自 feature/hub75e-fm6124-12864 commit 79d4932)

- IP: `02_hello_zynq.srcs/sources_1/imports/hdl/icnd2047_panel_seq.v`, 模块名 `hub75e_panel_seq_v2` (FM6124 drop-in 同端口)
- IP **驱动外部 ABCDE** (`output reg [4:0] hub75e_addr_out`, S_ADDR_ABCDE 态), 配合连接器 A-E → 行管. 用户确认 panel 走 HUB75E A-E (不是纯内置行扫).
- 寄存器基址 **0x40020000**: 0x00 CTRL(0=off, 0x501=en|mode0|addr_bits=5) / 0x04 COLOR_T / 0x08 PARAM(15→16col) / **0x0C STATUS [0]run [12:8]cur_addr [15:13]cur_plane [31:16]frame_count** / 0x10 COLOR_B / 0x14 TUNIT
- FCLK1 via SLCR **0xF8000180**: `0x00600600`=50M(DCLK25M spec内) / `0x00500500`=72M(DCLK36M 超频44%)
- fps 测法: 读 0x4002000C[31:16] frame_count, 2s 差 /2. v30 直连实测 7540@50M / 10919@72M (但行扫视觉**从没物理验证过**, 这次 P3 一起验)

# bring-up 三件套 (在 worktree, 未 commit)

- `constrs_1/new/icnd2047_p3.xdc` — IP顶层端口→P3/panel2脚 (照 [[reference_mtr_board_v01]]): DCLK=AB16 LAT=AA18 OE=Y18 ADDR[0..4]=AB19/Y19/AA19/AA16/AB20 RGB=Y20/Y21/AA22/AB22/AA21/AB21. **V15 不约束(高阻,安全红线)**
- `tools/build_icnd_p3.tcl` — 加IP + 加P3 XDC + disable hub75e_pins.xdc & led_pins.xdc + build + 校验 dclk 落 AB16
- `tools/v30_test_p3.tcl` — SN 过滤版 fps 测试 (SECOND_SN 留空则自动排除板1 210251A08870)
- `tools/v30_test.tcl` — 原始 name-based (单板时用)

# 🔴 build 坑: worktree fresh checkout BD 加载失败 (2026-06-16)

症状: `open_bd_design` 报 `CRITICAL WARNING [BD 41-2160] Unable to find cell <sc_pov_axilite>` → `ERROR [BD 41-425] Failed to read Diagram`.
根因: `.gen/` 和 `.runs/` 被 **gitignore** → worktree 缺 BD 生成产物; sc_pov_axilite 的 .xci **在 .srcs (可重生成)** 但产物在 .gen (没了).
修复: build 脚本去掉 `open_bd_design`+`make_wrapper` (wrapper 已提交 imports/hdl/, BD 未改), 改 **`generate_target all [get_files hello_zynq.bd]`** 先重生成产物 (jesd204c bd_rule 报错是无关spurious error, catch 掉, 用"synth/hello_zynq.v 是否生成"判成败).

## 🔴🔴 batch 搞不定 fresh-checkout BD 的 OOC IP → 必须 GUI (2026-06-16, 6 次 build 实锤)
generate_target 修好后, **impl opt_design 反复 `ERROR [DRC INBB-3] Black Box: axi_smc_hp/axi_smc_pov_hp/sc_pov_axilite (bd_f697/82d5/1b9c) undefined contents`**. 根因: SmartConnect 是 OOC 综合, 需各自 .dcp; fresh checkout (.runs gitignore) 缺这些 .dcp.
- batch 试了全部无效: ① synth_ip [get_ips] (没作用, BD子IP不吃) ② set synth_checkpoint_mode None on top .bd (不传播到嵌套SmartConnect BD) ③ launch_runs OOC IP runs (**2024.2 这BD根本没独立OOC synth run, runs目录只有 synth_1**, get_runs filter 返回空) ④ set generate_synth_checkpoint false on FILE_TYPE==IP + reset_target (只内联了 axi_smc 1个, 其余3个仍黑盒; synth 每次1.7min跑完=没真内联). 全失败.
- **正解 = GUI**: 开 worktree `02_hello_zynq.xpr` → Tcl Console `source ../tools/setup_icnd_p3.tcl` (只加IP+P3 XDC+disable冲突+generate_target, 不launch) → Flow Navigator **Generate Bitstream** (弹窗选Yes). GUI 的 Generate Bitstream **自动创建并跑各 IP 的 OOC synth run**, 这正是 batch launch_runs 一直没做的. bit→runs/impl_1/hello_zynq_wrapper.bit.
- 通用教训: **worktree/fresh-checkout 的带 SmartConnect 的 BD 工程, 直接 GUI Generate Bitstream, 别 batch launch_runs** (batch 不会自动跑 OOC IP 综合 → 永远 black box). 印证 [[feedback_vivado_batch_needs_settings64]] / [[feedback_refresh_bit_stale_xsa]] 的 GUI-最稳 结论.
- 脚本: `tools/setup_icnd_p3.tcl` (GUI setup), `tools/build_icnd_p3.tcl` (batch 全套, 已知会黑盒, 留作 IP/XDC 管理参考).

## 🔴🔴🔴 18 次 build 后的最终根因 (2026-06-16, 必须 GUI 交互式)
**根因链 (彻底查清)**:
1. 这个 BD 提交时 `synth_checkpoint_mode = None` (全局综合). 用 `[get_property synth_checkpoint_mode [get_files hello_zynq.bd]]` 确认.
2. **AXI SmartConnect (axi_smc/axi_smc_hp/axi_smc_pov_hp/sc_pov_axilite, 类型 bd_edd3/f697/82d5/1b9c) 在 2024.2 强制 OOC 综合, 全局模式下永远 black box** (opt_design DRC INBB-3).
3. fresh checkout worktree 的 `.runs/.gen` 被 gitignore → 缺这些 SmartConnect 的 OOC `.dcp`.
**试过且全失败的脚本招数 (别再重试)**:
- synth_ip [get_ips] — BD 子IP 不吃, 无效
- set GENERATE_SYNTH_CHECKPOINT=0 全局综合 — SmartConnect 强制OOC, 只内联了1个其余黑盒
- in-memory synth_design — SmartConnect "Could not resolve non-primitive black box"
- batch / GUI-mode (-source) launch_runs impl_1 — synth_1 run 固化在 None模式, 不切OOC链接
- **synth_checkpoint_mode Singular + create_ip_run** — 能创建 `hello_zynq_synth_1` BD OOC run + 跑出 3.18MB `hello_zynq.dcp`, 但**Singular 没把 SmartConnect 压平**, .dcp 里它们仍是嵌套OOC黑盒
- synth_checkpoint_mode **Hierarchical 非法**: `ERROR [filemgmt 56-24] ... already part of block fileset`
- 非工程 read_verilog wrapper+stub + `read_checkpoint -cell hello_zynq_i hello_zynq.dcp` — 链了但 SmartConnect 核仍黑盒 (证明 .dcp 内部就是黑盒)
**唯一出路 = 交互式 GUI**: GUI 打开工程 → Generate Output Products(Synthesis) 会**正确创建 SmartConnect 的 per-IP OOC run** (block-fileset 的嵌套情况 GUI 能处理, 脚本的 Hierarchical 不行) → Generate Bitstream.
工程已用 `tools/prep_save.tcl` 预配置 (Singular + P3 XDC 已存). 用户开 GUI: `02_hello_zynq.xpr` → Flow Navigator 'Generate Bitstream' → 弹窗选 Yes.
**通用教训**: 带 SmartConnect 的 BD, fresh-checkout worktree (无.runs/.gen) **只能 GUI 交互式 build**, 任何 headless 脚本 (batch / -source GUI-mode / 非工程) 都生成不出 SmartConnect 的 OOC .dcp. 下次直接 GUI, 别试脚本 (省 18 次 build 的命).
log: build_*.log 在 worktree tools/, 全是黑盒失败记录.

# 已知坑复用
- led_pins.xdc 的 panel_spi_miso@AB16 会抢 P3 的 DCLK → 必 disable ([[reference_mtr_board_v01]] 踩过 2h)
- 双下载器 targets 空 → 不是 driver 问题, 杀 hw_server (但对方调板时别杀) ([[feedback_xilinx_cable_needs_adept_runtime]])

相关: [[reference_mtr_board_v01]] [[project_pov3d_panel_chip_pivot_2026-06-04]] [[project_pov3d_rotor_chip_arch.md]]

## ✅✅✅ 2026-06-17 HEADLESS BUILD 彻底攻破 (推翻"只能GUI"结论, v11 出 bit)
**前面所有"只能GUI"的结论全是误判**。真因根本不是 SmartConnect 黑盒, 而是 **fresh-checkout worktree 的 IP 处于 stale/locked 状态**:
- `report_ip_status` 实锤: `sc_pov_axilite_0` **IS_LOCKED=1** + 3个SmartConnect "Stale IP file" + **panel `hub75e_panel_seq_0_3` "Module reference is unresolved"**。
- 后果链: 锁定/未解析 → `generate_target` **不把 BD 顶层 `hello_zynq.v` 注册进综合编译集** → synth 只读 `hello_zynq_wrapper.v`+IOBUF → `ERROR [Synth 8-439] module 'hello_zynq' not found`。这才是 18 次失败的真症状(不是黑盒!黑盒是更早一版的假象)。

**正解配方 (build_icnd_v11.tcl, 已出 4.05MB bit, 时序met WNS=+0.052ns)**:
1. `open_project` + `set_property source_mgmt_mode All`
2. **`upgrade_ip [get_ips -filter {IS_LOCKED==1 || UPGRADE_VERSIONS!=""}]`** ← 关键!一步解锁全部IP + 解析 panel module_ref(log见 `Adding block hub75e_panel_seq_v2:1.0` + `Generation completed`)+ BD顶层进编译集。**upgrade_ip 改 .xci 写盘持久化**, 跑一次后下次 open 就不再 stale。
3. `set_property synth_checkpoint_mode Singular [get_files hello_zynq.bd]` (顺GUI纹理: BD顶层OOC综合成 hello_zynq.dcp, synth_1读它)
4. 对 axi_smc/axi_smc_hp/axi_smc_pov_hp/sc_pov_axilite 的 .xci `set_property generate_synth_checkpoint false` ← SmartConnect 在 BD OOC 综合内**内联**, 不出独立OOC dcp → 解掉嵌套黑盒
5. `generate_target all` + **`create_ip_run [get_files hello_zynq.bd]`** (建 `hello_zynq_synth_1` BD OOC run, =GUI 'Generate Output Products')
6. `reset_run synth_1; reset_run impl_1; launch_runs impl_1 -to_step write_bitstream -jobs 8` (级联: BD OOC→synth_1→impl)
7. **必须 `call C:\Xilinx\Vivado\2024.2\settings64.bat &&` 包裹** vivado batch, 否则 launch_runs "Spawn failed"([[feedback_vivado_batch_needs_settings64]])

**死路(别再试)**: ① None模式 + in-memory `synth_design` — 即使 BD顶层在 get_files compile_order 里, synth_design 也**不内联展开 None-mode BD** → 永远 module not found. ② None + launch_runs — synth_1 run 读取脚本只含 wrapper(脏Singular残留期待OOC dcp). 正解必须 Singular + create_ip_run 走 BD OOC run。
log: tools/ 下 build_icnd_v11.tcl 是 the one。bit→`02_hello_zynq.runs/impl_1/hello_zynq_wrapper.bit`。
**通用教训**: worktree/fresh-checkout 带 module_ref IP + SmartConnect 的 BD, headless build 第一步永远先 `upgrade_ip` 把 stale/locked 清掉, 再 Singular+create_ip_run+SmartConnect inline。GUI 不是必须的。

## ✅✅✅ 2026-06-17 ICND2047 驱动实物验证通过 (色序/偏移/几何全对)
板2 ICND2047 128×64 实拍验证: 8色竖条(R/G/B/W/Y/M/C/黑 顺序正确) + 红绿棋盘格(8列×4行, 上下半相位反, 几何齐) + 上下半一致。三个根因全解 (commit 62031f3):
1. **色序错位** (命令纯蓝→显绿): panel 内部循环置换 **IP_r lane→蓝LED / g→红 / b→绿**。修: bit 提取重映射 `r1_bit=pattern[B] / g1_bit=pattern[R] / b1_bit=pattern[G]` (即 rgb[0]喂B, rgb[1]喂R, rgb[2]喂G)。8色全自洽确诊。新装 panel 必先 mode0 纯R/G/B 验色序 ([[feedback_panel_brg_vs_grb]])。
2. **整体左移像素** (先3后2): **S_LATCH 在 LE 高电平期间打 CLK 边沿 → DDR 每边沿=1bit → 多移数据**。逻辑分析仪(DSView .dsl, 500MHz)实测每行 66 上升沿=64数据(128列DDR)+2命令边沿, 那2~3个命令边沿就是偏移源。修(用户诊断对): **纯 LE 脉冲** — S_LATCH 里 `hub75e_dclk_out<=0` CLK 停低, LE 只拉 latch_edges_target 拍脉宽、无边沿。**外部 ABCDE 行选 → 不用片内行计数器 → 不需要 datasheet 的 3/4/5 边沿命令**。datasheet line78 "ICND2047 与普通双锁存芯片时序基本相同" 成立, **LE 0-edge 没触发 Reset** (实测面板正常)。DCLK 128次翻转偶数→入S_LATCH时已=0, 无毛刺边沿。
3. **改 panel RTL 不生效** (反复 build 旧逻辑): panel **module_ref 复用 OOC synth 缓存 .dcp**。修: build 脚本对 panel IP `set_property generate_synth_checkpoint false` (inline) + `delete_runs *hub75e_panel_seq*` 删 OOC run。⚠ 以后改 panel RTL 必用 `build_icnd_p1b.tcl` (含此 inline 强制), 否则改了不生效白烧。
- 运行时旋钮: `reg_param[15:12]=col_shift` (pattern 取 col_idx-shift, 兜底残留偏移; 纯LE后=0 不需要)。`reg_param` bit分配: [11:0]=width-1, [15:12]=col_shift, [23:16]=stripe, [31:24]=walk_speed。
- **冷循环后烧必须跑 ps7_init** (配 FCLK/AXI/DDR), 否则写 0x40020000/0xF8000180 必 AP transaction timeout。脚本 `tools/_flash_icnd.tcl` 已含。run时调寄存器不重烧: `_setcolor.tcl <mode> <color>` / `_setparam.tcl <w> <shift>`。
- **DAP 又锁** (一session烧6+次 fpga -file): `DAP status 0xF0000021` ps7_init/FCLK 写全 fail → 必须用户物理冷循环 ([[feedback_jtag_dl_reflash_loop_dead]])。"PL控制的LED亮" = fpga -file 成功载入PL(即使后续PS配置fail), 可当快速"bit载入"指示。
- 当前用 **P1 连接器** (icnd2047_p1.xdc, MTR Panel1 引脚 R1=AB15..B2=V13/CLK=W16/LAT=AA14/OE=Y14); P3 也试过同样现象(证明 B2 缺失是 panel 内部色序非接线)。
- **下一步**: fb 路径 (BRAM/DMA 显示真实内容) 当前 STUBBED (fb_*_dout=0); 要显示图片/数字棋盘格需实现 framebuffer。然后转电机看 POV / 6-bit。
