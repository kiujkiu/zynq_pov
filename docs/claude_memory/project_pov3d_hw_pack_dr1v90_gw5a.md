---
name: project_pov3d_hw_pack_dr1v90_gw5a
description: 2026-09-15 给硬件的第二个资料包 — DR1V90 主控资料 + GW5A(ACG525-CORE-V2)模块资料 + 两模组对接关系 Excel; 位置/结构/生成脚本; 核查挖出的硬事实(核心板 VCCIO45 锁 3.3V、VCCIO67 核心板供 2.5V、FS03 每根 CEP 线有 33Ω 串阻、CEP2.7 原理图坐实 Y9)
metadata:
  type: project
---

# 硬件资料包: DR1V90 主控 + GW5A 桥接模块 (2026-09-15)

**位置**: `pov3d/POV3D_硬件资料包_DR1V90主控与GW5A桥接模块_2026-09-15/` + 同名 `.zip`(工作区根目录, 约 62 MB)。
与 [[project_pov3d_hw_delivery_package]](任务/背景交付包 rev.4)是两个包: 那个讲"做什么", 这个是"原始资料"。
- 01_DR1V90主控SoC_安路: 原厂手册(DS1200 V1.0 正式版 0 TBD; **UG1201/1202/1204/1206/1210/1212 都是 v0.1 草稿**, UG1214 v1.4)、FS03 参考设计、自研核心板设计要点、484 球 CSV、外围器件手册(**YT8531 那份是厂家 DRAFT_05 草稿**)
- 02_GW5A桥接FPGA模块_小梅哥ACG525-CORE-V2: DS1103-1.0.9 + 5 份高云 UG(**取自 `D:\BaiduNetdiskDownload\小梅哥ACG525…\09_高云厂家手册\`, 工作区外**)、核心板原理图、官方底板 CB-V2 工程源文件、环回自测位流
- 03_两模组对接关系: Excel, 生成脚本 `zynq_pov/docs/DR1V90_GW5A对接关系表_mkxlsx.py`(纯标准库手写 OOXML, 自带与 pinmap/adc/UBGA324.json/pins_v2.tsv 的数据自检)
- 发票目录只取了 `ACG525-CB-V2-260316-工程源文件/`; "安路手册（大全）.pdf"是米联客选型册不是 DR1 手册, 未放。
- 🔄 09-15 下午用户定"接口按目标板 24 颗做"⇒ Excel 正改为 **20 对/面契约** 口径并重打包(workflow `icd-20pair-target-rework`), 同时补进新版封装库 zip 与 DDR3 约束 md。

## 核查挖出的硬事实(画板会用到)
- **ACG525-CORE-V2 核心板: VCCIO45 必须 3.3V**(GD25Q128E 启动 flash、MODE/READY/DONE/RECONFIG_N 上拉、50M 时钟 T9 都在 bank4/5, 原理图 p4); **VCCIO67 = VCC2P5 由核心板供(FB3)固定 2.5V**; VCCIO01 = VCC1P5(DDR3)。**只有 VCCIO23 由底板供** ⇒ [[project_gw5a_bridge_verification]] 里"VCCIO 四组都由底板供"不对。首版表曾建议 VCCIO45 设 2.5V(critical, 已改)。
- ⇒ 验证板 GW5A 规划应为**上行放 VCCIO45(3.3V, Bottom 有 ODT)、下行放 VCCIO23@2.5V + VCCIO67**(26+21=47 対), 仍受 B2/B6 左右 bank 速率未证项约束。
- **FS03 每根 CEP 线都有 33Ω 串阻**(R187~R210, RA4_0402×24, 原理图 P17 + BOM) ⇒ [[project_pov3d_fs03_cep_ground_and_third_row]] §5 把它判成"幻觉"是错的(当时只 grep 了手册文本)。对 800 Mbps LVDS 的影响、要不要换 0Ω 待定。
- **CEP2.7 = Y9 已由 FS03 原理图 p17 坐实**(CEP2_3P → R200 → BK11_L12P → Y9, GCLKIOT2), 手册 Y19 是笔误; 仍需 toggle 位流确认才当转发时钟。
- 核心板上 IOB87A/IOR24A 等 6 个"半対"在 UG324 封装里根本没有配对脚; UG985 V1.7.2 已删除 MCKTEST/ADCINCLK/ADCOTEST 复用, IDE 的 UBGA324.json 还留着。
- 现役上行探针 `uplink_tx_top.v` 转发时钟发 200 MHz(4'b1100), 400 MHz 只在未接入顶层的 `uplink_tx_frame.v`。

## 🔴 09-15 用户定: 验证期 FS03 必须同时驱动 2 块屏 + 光电开关
- 用户原话"一定需要驱动2个屏幕和光电开关" ⇒ 此前"FS03 只带一面、双面放自研 SoC 板"的建议作废。
- LVDS 40 対: 面 A = bank33/CEP1 的 20 个非劈开対(时钟 R12_33 GCLKIOT2, 零余量), 面 B = bank11/CEP2 避开 CEP2.7/8 的 23 対里用 20(时钟 L14_11 GCLKIOT0, 余 3)——两种单面方案都已被对接表 v2 挑错代理核过。
- CEP 余下 IO 只有 16 个(bank33 四个劈开対 8 + bank11 余 3 対 6 + CEP2.7/8 2), 要装: 两面边带 8(ALIGNED/RSTN/UART×2)+ 光电 1 + JTAG 加载(两面各 4 = 8, 共用 TCK/TMS 则 6) ⇒ 共用 TCK/TMS 时 15/16, 否则 17 超 1; 且 CEP bank 为 LVDS 必须 1.8V(或改板 2.5V), 单端要电平处理 ⇒ FS03 CEP 以外的 3.3V IO 是否可用决定余量(workflow dr1-jtag-load-bench 任务 A 在查)。
- 对接表 v2 的 SoC 侧是单面 A/B 二选一口径 ⇒ 要改成双面 + 光电后再发; 2.5V 改板方案(workflow fs03-bank-vccio-2v5-mod)也要按两个 bank 都改来定。
- 包内 xlsx 仍是 fix 前版本(用户 14:10 起在 Excel 里开着, 写入被锁); 修正版在会话 scratchpad `fix4/out.xlsx`, 收尾脚本 `rev2/finish_rev2.py`(关 Excel 后跑, 会校验 md5 防覆盖)。

## FS03 bank 改 2.5V 后的电平账 (09-15, DS1200 V1.0 原文)
- DR1 PL 差分**输出**只有 LVDS25(2.5V)/LVDS18(1.8V) 1250 Mbps, 3.3V bank 只有 LVDS33_E/LVPECL33_E(LVCMOS+电阻网络) **300 Mbps**; 差分**输入**只支持 LVDS25/LVDS18(§2.7 注 1/2, 表 3-21/3-22) ⇒ 800M 上行发端 bank 只能 1.8 或 2.5V, **3.3V 不行**。
- 改 2.5V 后 LVDS25(VOCM 0.9/1.25/1.4)→ GW5A TLVDS_IBUF(VICM 0.3~2.35)直流直连成立; 通路上仍有 FS03 33Ω 串阻与排针地线问题(与电平无关)。
- 单端: DR1 LVCMOS25 **VIH max = VCCIO+0.3 = 2.8V**、VOH ≥ VCCIO−0.4 = 2.1V(表 3-11) ⇒ **桥→SoC 的 3.3V 线(ALIGNED/UART_B2S/TDO)必须转换**; SoC→桥 2.5V 驱 GW5A LVCMOS33(VIH 2.0)按规格最坏只余 0.1V, 建议也转换。省转换的做法: 桥侧边带改放 GW5A 2.5V 组(VCCIO23/67), 只剩 JTAG(bank10 固定 3.3V)要转 ⇒ ✅ **09-15 用户定: 桥侧边带放 GW5A 2.5V 组(VCCIO23/67), 接口所有单端(边带 4 + JTAG 4)统一 2.5V LVCMOS; 程序加载 = JTAG 4 根取代 7 位 SSPI 预留; GW5A JTAG(bank10 3.3V)的转换放 LED 模组(V2)侧**。接口规格书 v3(HTML, ICD-POV3D-001)+ 对接表 v3 由 workflow `icd-v3-spec-for-hw` 生成, 产物先在会话 scratchpad `icd_v3/`。转换器要固定方向 + Ioff(两模组分开上电)。

## FS03 CEP bank 改 2.5V 的改法 (09-15 workflow fs03-bank-vccio-2v5-mod, 双读者对账; 产物 dr1v90/fs03_mod/README.md + img/)
- 🔴 **改 DCDC 分压不行**: VCC_1V8(U8 ES5030, R45 200K/R47 100K)是公用轨, 挂 QSPI 启动 flash GD25LB256E 与 USB3320(绝对最大都 2.5V)、PS bank200/201 strap、YT8531 strap、1.8V 有源晶振; VCC_3V3(U6)更不能动; 板上无空贴位/2.5V 网络。
- ✅ **可行: 跳线口插 LDO 小模块, FS03 零焊接** —— J1/J2(1=VCC_3V3 / 2=ADJ_BANKxx 平面岛唯一入口 / 3=VCC_1V8)拔帽, 1×3 母座扣上: pin1 取 3.3V → 2.5V LDO(≥300mA, 压差 ≤400mV, 带主动放电; TLV75525P/RT9013-25/AP2112K-2.5 类, 下单前核手册)→ pin2, pin3 悬空, 另拉短地线(先量通)。上电序天然晚于 VCC_AUX; TVCCIO 0.2~100ms 要示波器实测; 🔴 J2 空着绝不上电(VCCIO_33 必须供电)。回退 = 拔模块插回帽。
- 丝印: 两个竖 3 针座在 CEP 排针下方中间, 上 "3V3" 下 "1V8", 左 "BK35" = J2(bank33/CEP1), 右 "BK13" = J1(bank11/CEP2)(Zynq 版 bank 名沿用; DXF 平面岛推断, **改前用中间脚↔C69/C56 通断实物确认**)。
- 冲突: ① 现役屏链在 CEP2/bank11 用 LVCMOS33 驱 3.8V 屏(VIH 2.66V) ⇒ **双面方案两个 bank 都改 2.5V 就意味着旧屏链下线**; ② 现役光电 `spin_sync_i` = **W6 = IO_L24P_11 = CEP2.23** LVCMOS33, bank11 改 2.5V 后必须挪; ③ JTAG 台架选脚在 bank33 按 3.3V(J2=1-2), 与 J2 插 2.5V 模块互斥 ⇒ 先做加载测试再改板。
- FS03 CEP 外 IO: PS MIO 全 1.8V 已占满; HDMI TMDS 串 0.1µF 只能 AC 输出; MIPI 座 J4 只有 9 根 CAM_* 单端直连(1.8V, bank31); KEY2/KEY3 = K18/J18(3.3V, 2.2K 上拉 + 0.1µF ≈ 220µs RC, 光电可借但 RC 在 15 rps 下≈1.2° 延迟, 可拆电容); LED 只能输出。⇒ CEP 外没有干净的 3.3V 口给 JTAG。
- CEP pin1: 原理图 VCC_3V3 经 L18/L19(L16/L17 接 5V 为 NC)⇒ 出厂 3.3V; 但 PANEL_BRINGUP_CHECKLIST 要求过"5V 灌入改法", 这块板改没改无记录 ⇒ **实测**, 无论如何不接。`PANEL_BRINGUP_CHECKLIST.md:304` 把 J12 pin2 写成 VCC 是错的(原理图 pin2 = GND)。
- 33Ω 串阻下 LVDS25 在 FPGA 焊盘 VOH 估 ≈1.54V 擦表 3-14 上限 1.5V(估算, 待测, 可换 0Ω)。
- ✅ **改板方案 v2(两个 bank 都改, `dr1v90/fs03_mod/README.md`, v1 备份 README_v1_单bank.md)**: J1、J2 各插一个独立 LDO 模块 = 肖特基(反向阻断)→ **TPS73625DBVR**(400mA, 带反向电流保护; v1 候选 TLV755P 手册明写反向电流走体二极管已弃)→ 0.2Ω 采样 → 10µF + 1kΩ 泄放; 胶壳 + 引线、模块放板外; SW1 拨 JTAG + 拔 TF 卡做前几阶段; 带电认座(两列插不同电压帽看 CEP1.4/CEP2.4 跟谁变)。第二轮复核**无 critical**, 3 条 major: M1 带电表笔点 CEP pin1/CEP2.3 滑针会烧 IO ⇒ 改预插测试线; M2 插上 V3 后加载前闸门测点被占 ⇒ V3 要留测试焊盘; M3 两壳并排 0.46mm 易虚插/失地, 岛掉电时对端单端线向岛注入 ⇒ 小 PCB 插座 + 双地线 + V3 上对端→DR1 单端线串限流电阻(🔴 SB_ALIGNED 有 2.2k 下拉, 串 1k 高电平只剩 ≈1.72V 贴 VIH 1.7V, 阻值与位置要算)。v2.1 修订 + `V3_design_inputs.md` 由 workflow `fs03-mod-v21-and-v3-inputs` 生成。
- 🔴 **风险复核(09-15)挑出的烧板点, 改板前必须遵守**: ① 认 J1/J2 的通断测量**必须先拔掉两个跳线帽**, 且做正反两向(BK35 中脚↔C69 通/↔C56 断, BK13 反之), 帽插着时两中脚都经帽接 3V3, 怎么量都"通"; 且"量 J2.2 = 2.5V"是循环验证 ⇒ 改为 **SW1 拨 JTAG(ON/ON)上电、量 CEP1.4(H20, 加载前被上拉到 VCCIO)≈2.5V、CEP1.39(A21 固定下拉)≈0V** 通过后才许加载 LVDS25 位流。② 出厂 SD 启动会自动加载卡里未知位流(bank33 LVCMOS33 或 LVDS18 都与 2.5V 错配) ⇒ 第 0~2 阶段 SW1 拨 JTAG 或拔 TF 卡; 改板前**物理拆掉 CEP1 上的 CB-V2 JTAG 线**(GW5A TDO 3.3V > DR1 2.5V bank 绝对最大 VCCIO+0.3 = 2.8V)。③ PANEL_BRINGUP_CHECKLIST "5V 灌入改法"是贴 L16/L17、拆 L18/L19 ⇒ **做过的话 CEP1 与 CEP2 的 pin1 都是 5V**, 不许从 CEP pin1 取电/做参考, 先实测。④ J1/J2 两列焊盘中心距仅 3.00 mm、J2 顶脚距 CEP1 奇数排 3.97 mm、旁边安装孔焊盘直径 4.37 mm(半径 2.186 被读成直径)⇒ 模块用单针杜邦壳 + 引线外伸、底面贴 Kapton、**安装孔不加焊片**, 地线接 J5.1(先量通)。⑤ 对端先上电会经钳位二极管 → ADJ 岛(仅 0.7µF)→ LDO 体二极管把 VCC_3V3 抬成半上电(每 IO 直流上限 350µA, 表 3-8)⇒ 规定 **FS03 先上电、最后断电**, LDO 选带反向电流阻断的。⑥ 测电流别串万用表(压降使 VCCIO 出窗), 用 0.1~0.5Ω 采样电阻 + 10µF。

## 验证板能否由 SoC 加载桥片位流 (09-15 用户问)
- **能, 走 JTAG**: 核心板连接器 **P1.94/96/98/100 = TDO/TDI/TMS/TCK**(原理图 p1), 在 GW5A **bank10**(A17 TCK / B18 TMS / D15 TDI / D16 TDO, UBGA324.json), UG324 上 **VCCIO10 与 VCCX 同接 3.3V** ⇒ JTAG 是 3.3V, FS03 侧要用设成 3.3V 的那个 CEP bank(另一个 bank 跑 LVDS18@1.8V)或 V3 加电平转换。
- **SSPI 走不通**: RECONFIG_N(V2)/READY(U3)/DONE(V17)/MODE0·1 都不在连接器上; UG714 表 3-1 注[4] MSPI 失败会回落 SSPI, 但 SSPI 脚在 VCCIO45 与上行规划撞脚, 且无法重触发配置 ⇒ 不推荐。
- 位流 `.fs` 约 615 万 bit(0.77 MB)。工具: openFPGALoader 支持 Gowin Arora V 的 JTAG SRAM 加载(release 里有 "fix SRAM erase/load for Arora V when flash is blank")。SoC 侧 GPIO 位敲的速度与 RISC-V 交叉编译(要 musl, 见 [[feedback_riscv_glibc_ifunc_sigill]])未验证。
- JTAG 同时是调试口 ⇒ V2 上要 0Ω/跳线在「SoC 驱动」与「下载器插座」之间二选一。
- **CB-V2 官方底板下载器座 P5(2×5)**: 1 TCK / 2 GND / 3 TDO / 4 VCC3P3(参考电压, 别驱动) / 5 TMS / 6~8 空 / 9 TDI / 10 GND(schnet.py 解 ACG525-CORE-V2.SchDoc 得出, 接线前对丝印)。
- 现在就能台架验证: FS03 某个 3.3V CEP bank 出 4 根 GPIO + GND 飞线接 P5; openFPGALoader 有 remote-bitbang / XVC 客户端(非 Windows, WSL 可跑)与 libgpiod 驱动 ⇒ 最快路径 = DR1 上跑百来行 /dev/mem 的 remote-bitbang 服务端, WSL 里 openFPGALoader 连过去; 判据 = IDCODE 连读 5 次一致 + 加载 gw5a_loop 位流后串口出横幅。
- 目标板形态讨论(用户问"20 对 + 下载 4 IO 还要别的吗"): JTAG 4 根做加载在所有候选桥片上脚名一致(SSPI/从串各家不同), 适合写进永久契约; 仍需回读(至少 st_all_aligned + UART TX)、复位、上电顺序规则; 选 JTAG 加载则桥片不能把 JTAG 脚回收成 GPIO。

## 🔴 09-15 18:05 对接表 v3 ↔ FS03 改板 v2.2 统一口径 (一致性审计 + v2.1 复核后拍板, 以此为准)
- 起因: 一致性脚本 `scratchpad/icd_v3/consistency_check.py` 查出 14 FAIL, 其中 3 critical: V3 §0 仍是旧脚位(串阻会落到 SB_RSTN 上 ⇒ 0.44V 桥片永远复位); kΩ 串阻 × DR1 PULLUP ⇒ 低电平 >VIL(UART/IDCODE 读不出, PULLUP 与 DC 350µA 保护无交集)。复核全文 `scratchpad/fs03mod_v21_recheck.md`(4 major / 11 minor)。
- **球位不再动**(以对接表 v3 17:55 为准): 共用 TCK A21 / TMS E20; TDI A16/E19; TDO A17(CEP1.20)/A22(CEP1.40); SB_RSTN W11/W10; ALIGNED U10/U9; B2S U12/U11; S2B D22/C22。
- **桥→SoC**: SB_ALIGNED、SB_UART_B2S 在 V3 紧贴 CEP 母座串 **8.2kΩ**, DR1 **PULLTYPE=NONE**; ALIGNED 的 2.2kΩ 下拉在串阻**连接器侧**(桥未配置 0.643V, 余 57mV)。"≤330Ω"备选删(只满足 AC 15mA)。**JTAG_TDO 不串阻**(留 ADC 球; bank33 非 ADC 单端球只有 C22/D22 无处可挪), DR1 PULLUP, V2 B 口 10kΩ 下拉**必须**; DS1200 §4.2 注 3"对端驱动 FAST 或 >3.3V/ns"按驱动器设置理解(焊盘处 33Ω×20pF 已只有 ~1.4V/ns), 待安路确认(D27)。不加缓冲器, V3 保持无源。
- **JTAG 上下拉**: TCK 静止低(A21 表 2-6 强制下拉 + V2 A 口 2.2kΩ 下拉 + DR1 PULLDOWN); **TMS/TDI 静止高**(V2 A 口 **22kΩ** 上拉到 V2 本地 2.5V + DR1 PULLUP; E20 表 2-6 强制上拉、A16/E19 HSWAPEN=0 弱上拉, 与配置期一致; 原定 10kΩ 在共用 TMS 两只并联时岛掉电反灌 422µA > 350µA, 22kΩ 并联 11kΩ = 193µA)。在位判据 = IDCODE 精确 0x0001281B。SoC 每次 JTAG 访问结束发 ≥5 个 TMS=1 回 TLR(静止时 TDO 高阻); 目标板 TDO 转换器 OE 门控待定 D29。
- 用户要"这些文件打个包" ⇒ 另出小交付包 `pov3d/POV3D_接口交付包_v3_2026-09-15.zip`(16.7 MB, 121 文件): 01 规格书 html / 02 对接表 xlsx / 03 FS03 改板 README v2.2 + V3_design_inputs + img/ref + 三轮审查记录 / 读我.txt(要点与待定)。改了 fs03_mod 或对接表要同步重打这个包。规格书 Artifact: https://claude.ai/artifact/Jzbn9QLZzuEKaGNxXAGTC1
- 19:00 前后落地并打包(rev.3): 包内 `03_两模组对接关系/` = 对接表 v3 xlsx(md5 6ac81e83…, 146987 B) + `POV3D_模组间接口规格书_v3_2026-09-15.html`(离线完整版, 仓库副本 `zynq_pov/docs/` 同名); 读我.txt/资料清单.csv 已同步, zip 84 文件 64854254 B testzip OK。规格书 HTML 由 `scratchpad/icd_v3/render_spec.py` 从 xlsx 渲染(Artifact 发布用片段版, `wrap_standalone.py` 包成离线版); 打包用 `finish_pack_v3.py`(先 --dry-run)。对接表生成器已改, `dr1v90/fs03_mod/README.md` 与 `V3_design_inputs.md` 升 **v2.2**(v2.1 备份 `*_v2.1_before_consistency.md`), 一致性脚本 C01~C28 0 FAIL(C11 WARN = D27 待安路)。
- **SoC→桥**(SB_RSTN/S2B/TCK/TMS/TDI)V3 不串阻不加上下拉: 直连 GW5A 靠 DS1103 表 3-8 IHS ≤150µA; JTAG 进 V2 转换器靠 Ioff。
- **闸门测点**: J_TP11 = CEP2.7/2.8 各串 10kΩ; bank33 = SENSE33(10kΩ) 主 + TP_TDO_A(47kΩ 隔离, 桩 ≤1mm) 辅; 无 TP_TDO_B。JTAG 分配不得占 CEP2.7/8。
- 上电: FS03 → 闸门 → 加载 LVDS25 位流(LVDS/SB_RSTN/S2B 不使能) → LED 模组上电 → SoC 轮询 IDCODE(无失败超时) → 使能该面; 断电 LED 模组先断。SW1 拨 JTAG **并**拔 TF 卡(上面②的"或"已作废)。核心板 flash 接 V2 前擦除或烧安全镜像。焊后/插后先做断电阻值检查。

**How to apply:** 再改对接表就改生成脚本重跑; 改包要同步 读我.txt(UTF-8 BOM+CRLF)、资料清单.csv 的 md5, 再重打 zip 并 testzip。
