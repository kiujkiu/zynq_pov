---
name: project_pov3d_jtag_load_bench
description: 🔴 09-15 交接: DR1V90(FS03) 经 JTAG 给 GW5A(ACG525-CORE-V2 + CB-V2 底板) 加载位流的台架 —— 接线、DR1 PL/软件、PC 端 openFPGALoader、判据; 🔴 25A 版芯片 JTAG 配置要求 TCK ≥15 MHz, GPIO 位敲大概率加载不了, 先看芯片丝印定 A/B
metadata:
  type: project
---

# JTAG 加载台架交接 (2026-09-15, 用户要在新窗口继续)

## ▶ 2026-09-20 15:3x 用户"按计划继续" —— wf_e15ee81a-dbe 已恢复 (task wzdm8pvav); 🔴 当晚卡死未完成
- 恢复方式: 把脚本拷到 `dr1v90/jtag_load/_wf_obs_svf.js` 再 `Workflow({scriptPath, resumeFromRunId:"wf_e15ee81a-dbe"})` (工具不收 ~/.claude 下的路径)。**3 路构建 + review:pl 全部从缓存复用, 只重跑 review:sw-svf**, 之后是 fix → 上板。
- 恢复前实测板子 (只读, COM5, BOARD_ID 核对通过 = DR1V90-1): **09-20 板子重启过** (uptime 781 s), 现在跑的是**开机自动加载的正式显示位流** (fpga prog successfully ×2, state operating), 上一轮的 hp1_v33 PL 与 ROLE 映射随重启丢失 (设计如此); SD 卡 `pov_jtag_stage/` 仍在且文件齐全; 无进程占 /dev/mem; SD 卡上多了别的会话建的 `lvds_b2b/`。
- 🔴 **COM22 (GW5A 串口 CH9102) 在 09-20 已不存在** ⇒ CB-V2 的 J5 USB 被拔或整板断电; GW5A 是否上电未知。上板那一步需要: ① CB-V2 接 12V DC 且 D1 亮; ② J5 USB 接回 PC (横幅判据与 SVF 板上验证都要)。**已请用户恢复**。
- 串口现状 (09-20 15:29 只读枚举): COM4/COM5 = DR1V90-1 (PnP 7&2D66278), COM12/COM18 = 另一块 (PnP 6&88CF9E7, 归属仍待用户确认: DR1V90-2 或 dr1m90_1), COM22 消失, COM20 (CH340) 也不在。
- 🔴 **09-20 傍晚**: 恢复已开跑并"已存盘", 但 Claude Code 订阅被组织关掉 ⇒ 会话中断; **review:sw-svf / fix / 上板都没做完**。构建缓存仍在, 下次接着: ① 先确认 CB-V2 供电+J5; ② 重开 review→fix→上板 (构建可继续缓存复用)。

## (暂停记录) 2026-09-17 13:24 用户要求"先保存, 然后暂停" —— workflow wf_e15ee81a-dbe 停在审查阶段
- **构建 3 路全部 PASS (已缓存, 恢复时直接复用)**:
  - PL `pl_pov_jtag/out/obs_v33/` (bin 4d4f05e7, dtbo 41ef6a7e, load_pov_jtag.sh 88587e91, BUILD_REG 0x504A2702): **量具 EXACT —— 不加 JTAG 的 obs 重建与 SD 卡现役 pl.bin 62431443 逐字节一致**; 加 JTAG 后 8 个种子取 seed 7: **SWNS 8.54 / HWNS 0.208 (正式 obs 5.921 / 0.076, 比正式还好)**; S-TCKOE 逐拍证明开 OE 时 TCK 无上升沿 (目标 A21 下拉/台架 H20 上拉); obs_v25 (目标板, seed 3, 7.317/0.201) 只构建。hp1 旧产物未动。
  - SW `sw_bridgeload/` 原地更新 (bridge_load.sh 6bf9db57, pj_sram.c ce5f7f50, install_pov_jtag.sh 3721fcc4, uninstall_pov_jtag.sh dee8f6f8): --if-already erase (DONE 1→0→1)、严格模式、flash DNP 场景、看门狗、可逆安装、已同步 RTL 0x02 (v2 空闲 0x6, 台架 0x7); make test PASS。
  - SVF `sw_svf/` (svf_play_riscv64 994b5a72, 高云 programmer_cli 生成的 `svf/gw5a_loop_n4_l800_verB_uc4A544742_sram.svf(.gz)`): run_tests 135/135, 预扫描 256 个 IR 码、插 0x16 在第一拍前拒绝。**两个要用户定的残余风险**: ① 高云 SVF 必须发 0x0A (与 OTP 0x2A 差 1 位, 后跟 32 位 DR), 只能靠链路测试给统计上界 (pj_sram 从不发 0x0A); ② GW5A-25B 在 0x3B 裸帧模式能否发现坏帧未知, 板上负向对照要写坏设计可能让 CB-V2 IO 误驱动, 需用户在场 ⇒ 结果出来前 SVF 路线只作调试/交叉验证。
- **未做**: 两路审查 (被停时进行中)、修复、上板 (bringup_20260917 未开始)。**板子这一轮没动过**: DR1V90-1 仍是 pov_jtag_hp1_v33 PL (引脚高阻), GW5A 在 flash 镜像。
- **恢复**: `Workflow({scriptPath: "/home/wanqi/.claude/projects/-mnt-d-claude-workspace-pov3d-dr1v90/094a5ce8-4f03-42de-85df-948fa3e31785/workflows/scripts/jtag-production-obs-and-svf-wf_e15ee81a-dbe.js", resumeFromRunId: "wf_e15ee81a-dbe"})` (脚本路径若被工具拒收, 先拷到 dr1v90/jtag_load/ 下再用); 新会话无法 resume 时, 按本节与 HANDOFF 手工接着做审查→上板。
- 同时待办: COM18 归属 (DR1V90-2 还是 dr1m90_1) 待用户确认; DR1M90 移植清单见 [[project_dr1m90_jtag_port_checklist]] (头号风险 SRST_CTRL2 bit4; 建议先下米联客 ARM SDK uisrc-lab-anlogicM 查 ATF)。

## (历史) ⏳ 2026-09-17 进行中 + 🔴 用户: "下一步大概率换 DR1M90"
- 用户 09-17 授权"按推荐来": workflow `wf_e15ee81a-dbe` (脚本 ~/.claude/projects/-mnt-d-claude-workspace-pov3d-dr1v90/094a5ce8-4f03-42de-85df-948fa3e31785/workflows/scripts/jtag-production-obs-and-svf-wf_e15ee81a-dbe.js) 正在跑: ① PL 以现役 obs (git 745b66d) 为底重建 JTAG 集成版 + 扫种子补 hold 余量 + 修 OE 打开当拍 TCK 上升沿 + 构建 v25; ② sw_bridgeload: IF_ALREADY=erase_then_load (DONE 1→0→1 + 错误位 0 + USERCODE=包值)、硬看门狗、可逆 install/uninstall 脚本 (只 dry-run); ③ 新建 sw_svf/ 通用 SVF 播放器 (预扫描 SIR 白名单) + 高云 programmer_cli 生成 SVF; 审查→修→上板 (只 DR1V90-1, 新暂存 pov_jtag_stage2/, 不写 pov/、不重启, 日志 bringup_20260917/)。挂进开机启动 + 重启测试要用户在场。
- 🔴 09-17 用户: **下一步大概率换 DR1M90GEG484 (ARM A35 双核, 与 DR1V90 同 PINLIST pin2pin)**。JTAG 这条线的可移植性判断:
  - **不用重做**: GW5A 侧全部 (协议/白名单/判据/.gws 包/SVF 路线/丝印 25B/JTAG 电压普查/电平转换清点/桥片选型与资源需求); 找脚/负载图方法; 全部 C 源码与 busybox 脚本 (重编 aarch64 musl 即可, 工具链已备); PL 侧 Verilog (pj_regs.v 等) 与引脚约束 (同 PINLIST 同球位)。
  - **要重跑/适配** (09-17 只读核查后修正, 详见 [[project_dr1m90_jtag_port_checklist]]): aarch64 重编 + ELF 机器类型判据、_riscv64 文件名与 pidof、TD 器件串、bootgen -arch dr1m90 (4 处)、挂钩补丁重生; 🔴 **新增 GP0 主口复位 SRST_CTRL2 bit4 回读 (DR1V90 上靠 OpenSBI 加载 PL 时放开, DR1M90 靠 ATF 未知)**; PS 封装与零回归量具要等显示 PL 移植。~~GP0 基址要改~~ / ~~身份检查写死 dr1v90~~ 都不成立。

## ✅ 2026-09-17 01:05 JTAG 并进正式位流 + 板上验证 PASS (workflow wf_dc2e0d2e-7b8, 7 代理, 上板代理 30 次核 PnP 实例 + BOARD_ID 全对)
- **PL**: `dr1v90/jtag_load/pl_pov_jtag/` → `out/hp1_v33/pov_jtag_hp1_v33.bin` (a17554e0) + dtbo (5bc7746c) + `load_pov_jtag.sh` (bd621195)。= td_pov 工作树 (HP1, ad6e3d9) 正式显示位流 + JTAG 块 `pj_regs.v` (GP0 窗口 0x8001_xxxx, 身份 "POVJ"), 正式 RTL 标记块外逐 token 相同; 面 A/B 两条链 (TCK/TMS 共用, CHAIN_SEL), ROLE_A/ROLE_B 可映射目标 6 球或台架 4 球, OE 默认高阻, ARM 互锁。BUILD PASS (498 s), **HWNS 0.000 ns (正式 0.022, 最差路径在 lz4 引擎 2 内部) —— 不能拿它下 lz4 压测结论, 进生产前扫 seed 或打拍**。
- **SW**: `dr1v90/jtag_load/sw_bridgeload/` —— `pj_sram` (gw5a_sram 的 POVJ 版, --chain A|B, --role bench|target|hex) + `bridge_load.sh` (boot/rollback, 配置文件, 日志 + 退出码, 总时间预算软限) + `hook/povboot_bridge.patch` (未应用)。审查 1 个阻塞项 (补丁 stage_files 对整目录 md5 会误拒不回退) 已修。
- **上板 (DR1V90-1)**: 暂存 `/mnt/mmcblk0p1/pov_jtag_stage/` (pov/ 逐字节未动); LOAD_POV_JTAG PASS; 显示部分寄存器表与正式 HP1 位流逐项相同, 大量 JTAG 流量后复查仍相同; 链选择真机 (台架芯片映到面 B) PASS; 负向对照 crc_error_r=1; **load/reload 8/8 PASS (uc42/43/44), COM22 横幅 14 次**; `bridge_load.sh boot` 3 次 rc=0 每次 8.7~9.8 s; 面 B 不在位 rc=4 不影响面 A; 加载中 SIGINT 后 rollback 正常; 正式 PL ↔ 新 PL 来回切换 GW5A 不受扰动。位敲速率有单核调度抖动 (204k~920k TCK/s, 0 误码)。
- **终态**: DR1V90-1 未重启, 当前 PL = pov_jtag_hp1_v33 (引脚高阻, 未点屏), GW5A RELOAD 回 flash 镜像 B3A5。
- **待用户决定/动手**: ① 谱系: 新位流基于 HP1, 卡上现役 pl.bin 是 obs (62431443), HP1 lz4 引擎 09-15 推流卡死未结案 ⇒ 挂进启动 = 换生产谱系 (或改用 obs 为底重建); ② 是否应用 povboot 补丁、改 pov/povboot.env 并重生 MANIFEST; ③ 暖重启/断电后开机自动加载验证要人值守 (u-boot 热重启认不到 SD 未结案, S00sdoff 会写 pov/sdoff.log); ④ R7 CB-V2 断电判 ABSENT 要人拔 DC; ⑤ 两片 GW5A 共用 TCK/TMS 时未选中面 TDI 驱 1 只能靠仿真, 要第二块板实测; ⑥ 目标板 v25 (2.5V) 变体未构建, OUT 复位 TCK=1 与目标板 TCK 静止低矛盾要先解决; ⑦ 目标板 flash DNP 时 DR1 重启后 GW5A SRAM 仍保留设计 (USERCODE = 包值) 的 IF_ALREADY 策略。
- 工具坑: `host/serial_recv.ps1` 在板端回显打开时取文件失败 (匹配到回显的命令行); busybox `tar czf` 静默失败要用 `tar cf - | gzip`。
- P6 环回线 (Bank2 速率测试) 到 01:05 仍未接 (扫眼全 X, A=0000)。

## 🔴 2026-09-16 修正: 台架板 = DR1V90-1, 就是原来叫 "dr1a" 的那块
用户 09-16 定名 **DR1V90-1 = 接在 COM5 上的那块**, 核出 BOARD_ID `pov-5d23750da9c1d32a`、eth0 `e0:78:a3:00:00:08`、卡 CID `ad4c…8800` ⇒ **与 "dr1a" 同一块板**(详见 [[project_pov3d_dr1v90_board_inventory]])。
⇒ 下面"误推到 dr1a、台架板要重新推包"作废: **推对了板, 只是版本旧**。09-16 15:0x 已用 `host/serial_send.ps1` 经串口把新版 4 个文件补齐, 板上 `/mnt/mmcblk0p1/jtag_load/` 6 个文件 md5 全部等于本地(idcode `4f6632e5`, rbb `0b7a9f77`, load_pl `1a111607`, MANIFEST `3246d41f`, bin `5a279bc4`, dtbo `b9c4e027`)。
`jtag_load/README.md` §S1 第 1 步判据"ID **不是** pov-5d23750da9c1d32a" 反向: **必须等于**。
🔴 板上当前**没有网**(eth0 NO-CARRIER, 无 wlan0) ⇒ S1/S2 可以全走串口, **S3 要 PC↔板 TCP, 先插网线或 WiFi dongle**。重启后 `/lib/firmware` 与 `/tmp` 清空、PL 回生产位流, 每次开机重跑 `load_pl.sh`。

## ✅ 2026-09-16 晚 S3 PASS: DR1V90 经 JTAG 把位流写进 GW5A-25B 的 SRAM (板上程序, 不经 PC/网络)
- 程序 `dr1v90/jtag_load/sw_sramload/out/gw5a_sram_riscv64` (md5 08beb0a1…), 板上 `/mnt/mmcblk0p1/jtag_sramload/` (+ uc42/43/44.gws 判据位流, 日志 `logs_20260916/`)。构建流程审查出 4 个阻塞项已修 (擦后写前复查状态 / 负向对照只翻存储 CRC / IR 锁存份随机错靠 26 万位 0 误码链路测试兜 / 防线不可关)。
- 实测 (TCK≈1.55 MHz 位敲, 615 万位 ≈4.0 s; 有一轮 CPU 忙降到 0.55 Mbit/s 11 s 仍 PASS):
  - 基线 STATUS 0x70026020 (done_final/init_r/wakeup), **flash 镜像 USERCODE = 0x0000B3A5** (不是出厂 usb.fs 的 0xC8C4, 也不是任何 loop 位流的 CheckSum, 来源未知); IR capture = 0x19。
  - 负向对照 (翻帧 100 的存储 CRC): 擦后 STATUS 0x30020020 (done_final 清 0) → 写后 **0x10024021 crc_error_r=1 done=0** ⇒ 芯片确实对 JTAG 数据做了 CRC; USERCODE 擦除后保留旧值。
  - RELOAD (0x3C): 从未配置回到 0x70026020。
  - 正式加载 3 轮 uc4A544742/43/44: 每轮 擦后 done=0 → 写后 STATUS 0x70026020 无任何错误位 (= 高云 SVF 掩码 0x602F 判据) → USERCODE = 包值 ≠ 基线 → 加载后链路 0 误码; 每轮 RELOAD 后 USERCODE 回到 0x0000B3A5。
- ✅ **21:25 串口横幅判据也 PASS (设计真在跑)**: CB-V2 **J5 = PC 上 COM22 "USB-Enhanced-SERIAL CH9102" (VID_1A86 PID_55D4)**, 115200, DTR/RTS 不用拉。flash 镜像 (USERCODE B3A5) **不往串口打任何东西** (26 s 静默) → JTAG load uc42 PASS 的同一秒 (21:25:43.73) 出 `GW5A-LOOP N=04 L=0800 ST=04` + 扫眼行 `T=xx XXXX` (P6 没接环回, 全 X 正常) + 每秒状态行 `S K=0 ...` (**K=0, KEY0 没有恒按下**) → `reload` 后输出在 21:26:01.7 停止, 之后 106 s 静默。日志 `sw_sramload/logs/20260916_2125_com22_banner_capture.log`, 抓取脚本 `sw_sramload/tools/com_capture.ps1`。
- 🔴 用户第一次插的是 **J4** (FPGA 软核 USB2.0), Windows 显示"未知 USB 设备 (端口重置失败) VID_0000 PID_0001 错误 43", 每次 JTAG 重配 GW5A 都会重新出现 —— 不是坏线, 换 J5 就好。俯视 P5 在上沿时 **J5 在 P5 左边, J4 在右边**。
- 未证: openFPGALoader+rbb_server 路线 (板上无网, 已有板上程序替代); 断电冷启动重复性; flash 擦空时加载; DR1 开机自动加载; 验证板 2.5V 接法。
## (历史) ⏳ 2026-09-16 晚 S3 进行中: 板上 GW5A SRAM 加载器 (dr1v90/jtag_load/sw_sramload/)
- 用户选: 先全自动 (DR1 板上直接加载, 判据只用 JTAG 读 STATUS/USERCODE), 网线 + CB-V2 J5 横幅判据以后补。**芯片 25B ⇒ 位敲够用, 不做 PL 硬件移位器。**
- 进度与恢复入口写在 `dr1v90/jtag_load/HANDOFF.md` 的 "S3 进行中" 一节 (workflow wf_ab5b01ea-b72, 研究原文 `sw_sramload/RESEARCH_R1_protocol.md` / `RESEARCH_R2_bitstream_criteria.md`)。
- 研究挖出的硬事实: ① 整流写法 0x15→0x12→0x17→单次 Shift-DR 全部数据行→0x3A→0x02, 擦 SRAM 后 RTI 空等 ≥1 s (高云 SVF); ② **禁发 0x16 / 0x71 / 0x75 / 0x3D / 0x7A (flash) 与 0x2A (OTP 不可逆)**, 0x17↔0x16、0x0A/0x3A↔0x2A 只差 1 位; ③ openFPGALoader 在 GW5A 上额外发 0x0A+DR32+0x08 写 USERCODE 且值算错, 不能照抄; ④ USERCODE 就在 .fs 尾部 `0A 000000 UUUUUUUU` 一行, 不受 CRC 覆盖, 默认 = CheckSum 高 16 位补 0 ⇒ 判据位流用自定义 0x4A5447xx (`bits/…verB_uc4A544742.fs`); ⑤ 小梅哥出厂 .fs 是 Device Version A / ES 片, 与实物 25B 不符, flash 内容待上板读; ⑥ 所有候选 .fs SecurityBit ON ⇒ 不能回读 SRAM 校验, 只能靠 STATUS/USERCODE。
- 🔴 FS03 重启后先恢复 JTAG: `cd /mnt/mmcblk0p1/jtag_pinfind && sh load_pl.sh && ./jtag_pinfind_riscv64 --apply`。

## ✅ 2026-09-16 S2 PASS: JTAG 链路通了, 根因 = TDO/TDI 两根飞线没插在规程脚上
- 现象: 按规程脚 (CEP1.4/5/15/18) 读 IDCODE 恒 0xFFFFFFFF, 1.5MHz / 2.5kHz / ~100Hz、两写/三写时钟、IR capture、显式 IR=0x11 全是 1, 写后球上回读 0 不一致 ⇒ 排除双拍/串扰/时序/指令; PINTEST PASS ⇒ DR1 球能驱动。
- 定位工具 (不用人动线): **找脚位流 `jtag_load/pl_pinfind/`** (48 个 CEP1 IO 全做成可独立驱动的探测脚 + ROLE 角色映射寄存器 0x44 + 原始模式 0x48~0x60, 0x00~0x0C 与现役完全兼容, PF_ID 0x40="PINF") + **`jtag_load/sw_pinfind/jtag_pinfind_riscv64`** (`--scan-only` 只读 / 默认暴力搜 2256 对 TCK/TMS 同时读全部脚找 TDO, 再用 32 位延迟图样找 TDI / `--apply` 写 ROLE) + 我写的 **`pf_rise_riscv64` 48 脚负载图** (逐脚单独驱 0 再放开, 数几次读到 1: 空脚 = 2, 插了飞线 ≥3)。板上目录 `/mnt/mmcblk0p1/jtag_pinfind/`。
- 负载图结果: 插线的脚 = **CEP1.3/4/5/9**, 规程的 .15/.18 是空的 ⇒ jtag_pinfind 确认 **TCK=CEP1.4(H20) TMS=CEP1.5(G15) TDO=CEP1.3(H19) TDI=CEP1.9(D18)**, IDCODE 0x0001281B 唯一命中 3/3。
- `--apply` (ROLE=0x00060201) 后**原封不动的 jtag_idcode**: 默认 & `-d 200` 均 5/5 0x0001281B、chain_A=1 chain_B=1、PASS; `-e 0x0001281A` 判 FAIL rc=1。⇒ **GW5A 在 ~1.5MHz 位敲下 TAP 正常响应 (读 IDCODE 不受 A 版 15MHz 注限制); A/B 版对 SRAM 配置的影响仍未验证。**
- 🔴 ROLE 在每次 load_pl.sh / 重启后回复位值 ⇒ 用找脚位流时每次开机: `cd /mnt/mmcblk0p1/jtag_pinfind && sh load_pl.sh && ./jtag_pinfind_riscv64 --apply`, 之后 jtag_idcode/rbb_server 照常用。或者断电后把两根线挪回 CEP1.15/.18 再用现役 `jtag_load/` 包。
- 审查留的操作注意: jtag_pinfind 被 kill -9 / Ctrl-Z 后 PL 可能停在 MODE=1 有脚在驱动 ⇒ 先跑 `--scan-only` (会清 RAW_OE/MODE) 或重跑 load_pl.sh, 再断 GW5A 电或用 jtag_idcode; 接线不确定时 load_pl.sh 别带 PINTEST (会盲驱 H20)。
- 这台板上测上升时间的量化: 读速 ~3.5M 次/s ≈0.29µs/格, 空脚 2 格、飞线+对端 3~5 格, 3000 次重复分布极窄, 可当可靠判据。

## ✅ 2026-09-16 核查: P5 只接 4 根 + 地, NCE/NCS/DAOUT 不存在 (workflow wf_3f5c8f8c-ed7, 3 路反驳 0 推翻)
- 用户问"NCE/NCS/DAOUT 不需要吧": 这三个是 Altera/安路 2×5 座 AS 模式脚名, **高云 21 本手册 + 安路手册 + 两块板原理图全文 0 命中**。CB-V2 P5.6/7/8 三重实证是死焊盘: IPC-356 `N/C` / SchDoc 上三个 No-ERC 叉(全图仅此 3 个) / 四层 gerber 洪泛(TOP/BOTTOM 孤立圆盘, 内层隔离盘无铜)。高云原厂 USB Cable 外壳丝印 6/7/8 位置也印 X。
- 🔴 **脚序按板子实测, 不按 UG987 图 4-1**: CB-V2 与原厂线缆 = 1 TCK / 3 TDO / 5 TMS / 9 TDI / 4 VCC; UG987 图 4-1 = 3 TDI / 5 TDO / 9 TMS / 6 VCC(照图接三根全错)。台架接线表本来就是实测的, 没问题。
- "4 根就够"的前提是**核心板替你做了配置脚**: UG714 表 3-3 JTAG(Only) 列 RECONFIG_N/READY/DONE 打 √; 核心板上 RECONFIGN(V2) 4.7K 上拉、READY(U3) 4.7K 上拉、DONE(V17)→330R→D1→4.7K、MODE0 1K 上拉/MODE1 1K 下拉(=MSPI), 都不上连接器。**上电先从 flash 自加载, 等横幅/D1 亮再发 JTAG。**
- 官方参考比"4+地"多: TCK 4.7K 下拉 + ESD 阵列(SP3003_04), CB-V2/核心板都没有; 地建议 P5.2 与 P5.10 都接(FS03 CEP1 只有 pin2 一根地, 第二根从 J12.2 引)。
- 🔴 **核心板违反官方"必须"的两处(板级既成事实, 我方补不了, 目标板自画时要改)**: ① PUDC_B(球 D4)被当 DDR3_A8 用, 官方要求直连或 ≤1kΩ 到 VCCIO/GND、配置中不许悬空(UG714 表 3-5); ② UG987 §4.1.1 加载成功后自动切 SSPI, 要求 SSPI_HOLDN 下拉或 SSPI_CSN 上拉, 本板 HOLDN 反而上拉(R2)、CSN 无上拉。
- 位流风险: 若某 .fs 把 JTAG PORT 设成 GPIO(UG714 表 3-6), 加载后 JTAG 失效, P5 上无 RECONFIG_N、核心板无复位键 ⇒ 只能 CB-V2 断电恢复。
- 09-16 实况(DR1V90-1): 接线完成, `LOAD_PL: PASS`, OE=0 时 IN=0x0F; PC 上只有 COM4/5/20 ⇒ **CB-V2 J5 未接 PC, 没有 GW5A 串口日志**(S2 IDCODE 不需要, S3 横幅判据需要)。

## 进展 (09-15 下午, 接手窗口)
- 🔴 **推包和加载都误做在 dr1a(10.10.21.112, ID pov-5d23750da9c1d32a)上 —— 那是 WiFi 测试在用的 FS03, 不是 JTAG 台架板**(用户 09-15 指出; 下面"板子访问"里写的 dr1a 就是误导源)。dr1a 上留下: SD 卡 `/mnt/mmcblk0p1/jtag_load/` 6 个文件(没动 pov/)、`/lib/firmware/jtag_gpio.bin`、PL 被换成 jtag_gpio(WiFi 侧那次开机的第 106 s, 屏 OE 恒消隐)。恢复: `sh /mnt/mmcblk0p1/pov/povboot.sh pl` 或重启(自启烧回生产 PL)。
- 仍有效的结论: 同型号 FS03 上 `load_pl.sh` **LOAD_PL: PASS**(bin 被 fpga_manager 接受、GP0 0x8000_0000、MAGIC/OUT 复位 0x7/SCRATCH/64K 译码/DEADBEEF 全过) ⇒ 位流本身没问题; **台架板要重新推包再加载**, 每次断电重启都要重跑 load_pl.sh。
- ⏳ 未做: J2 档位与 J11.4=3.3V 实测、GW5A 丝印 A/B、jtag_idcode、SRAM 加载。🔴 J2 没确认 3.3V 前不开 OE。
- Windows 串口基线: COM4/COM5 = CH342(COM5 是 DR1 控制台)、COM20 CH340、COM21 FTDI ⇒ CB-V2 J5(CH9102F)插上后多出来的那个就是 GW5A 串口。
- 准备流程 review/doc 阶段没跑完(journal 停在 `started review`), `README.md` 规程没生成; build 两个代理的结论在 journal 里完整。

目标: 验证"主 SoC 通过 JTAG 给桥 FPGA 加载位流"(接口契约里程序加载 = JTAG 4 根, 见 [[project_pov3d_hw_pack_dr1v90_gw5a]])。
产物目录 **`pov3d/dr1v90/jtag_load/`**(入口 `HANDOFF.md`; 流程跑完会有 `README.md` 规程)。
准备流程 `dr1-jtag-load-bench`(run `wf_3cee62db-15c`)结果在
`/home/wanqi/.claude/projects/-mnt-d-claude-workspace-pov3d/a90694ef-7017-4677-9731-1c8200e4c987/subagents/workflows/wf_3cee62db-15c/journal.jsonl`
(每行 type=result 是一个代理的完整结论; 09-15 15:40 时 research 三项完成, build:pl-bit / build:dr1-sw 在跑, review/doc 未开始; 旧窗口关掉则流程中断, 以目录里已有文件为准)。

## ✅ 已解决 (2026-09-16): 芯片是 **25B** —— 用户拍照丝印 `GW5A-LV25 / UG324C2/I1 / 2544BB0N / T1Y264.00`, Date Code 2544BB0N 第 5 字符 = B (2025 年第 44 周)
⇒ A 版"配置 TCK ≥15 MHz"限制不适用, 寄存器位敲加载 SRAM 可行, 用 verB 位流; 下面是当时的分析记录。
## (历史) 先解决的阻塞项: 芯片是 25A 还是 25B
- **UG714-1.0.6 §3.4.1 注: "JTAG 配置模式时钟频率不能高于 100MHz; 对于 A 版本芯片, 时钟频率不能小于 15MHz"**(英文版表 3-7 注[1]: 其他版本无最低频率)。DR1 用户态 /dev/mem 位敲、remote-bitbang 都远到不了 15 MHz ⇒ **A 版大概率加载失败**(openFPGALoader issue #557: Tang Primer 25K = GW5A-25A 用树莓派 libgpiod 能读 IDCODE, 但 SRAM 加载后 DONE 不起, 未解决 —— 旁证非实测)。读 IDCODE 可能仍能成功。
- **IDCODE 分不出 A/B**: GW5A-25 与 GW5AR-25 都是 0x0001281B, verA/verB 两个 .fs 的 ID 行也相同 ⇒ gw5a_loop README 里"Programmer 读 ID 分 A/B"不成立。判定: **看芯片丝印 Date Code 第 5 个字符 = 器件版本**(DS1103-1.0.9 §4.2 注[2]); 或用官方 Gowin 下载器分别下 verA/verB 看哪个出横幅。
- A 版出路: DR1 PL 里做硬件 JTAG 移位器(≥15 MHz TCK)+ XVC server, PC 端 openFPGALoader `-c xvc-client`; B 版: 现方案(PL GPIO 寄存器 + 板上位敲)可行。

## 接线 (FS03 J11 = CEP1 = bank33 ↔ CB-V2 底板 P5)
| 信号 | DR1 方向 | CEP1 脚 | DR1 球 / 管脚名 | 排阻 | P5 |
|---|---|---|---|---|---|
| TCK | 出 | 4 | H20 / IO_R19N_33 | R191 | 1 |
| TMS | 出 | 5 | G15 / IO_R4P_33 | R187 | 5 |
| TDO | 入 | 15 | F21 / IO_R23P_33 | R190 | 3 |
| TDI | 出 | 18 | F17 / IO_R6N_33 | R190 | 9 |
| GND | — | 2 | — | — | 2 和 10 |
- 选的是 bank33 上电"两端都上拉"的球(TMS=1 ⇒ TAP 停 Test-Logic-Reset, 无害); 备选 CEP1.7~12(C17/C18/D18/C19/B19/B20)。约束 `jtag_load/fs03_io/jtag_cep1_pins.adc`, 全表 `fs03_io/out/`。
- **J2 = 丝印 BK35 那个 3 针座, 跳 1-2 = 3.3V**(J1 = BK13 管 bank11/现役屏链, 保持 3.3V 别动)。J1/J2 物理对应是推断, 断电量中间脚↔C69(J2)/C56(J1)通断确认。
- 🔴 **禁止连接**: CEP1 pin1(VCC_CEP, 出厂 3.3V, 但若做过"5V 灌入改法"是 5V, 实测); **P5 pin4 = CB-V2 整板 3.3V 电源轨(不是参考电压)**。两板只共地。
- 朝向: J11 在 FS03 上边, 1/2 脚在左端, 奇数内排偶数外排(位号图无方焊盘, 用万用表确认 pin2 通地)。P5 在 CB-V2 上沿、J5(串口 Type-C)与 J4 之间, 直角牛角座, **pin1 方焊盘**, 俯视板上沿朝远处时 pin1 在左端内侧排; 断电 2/10 脚通地、上电 4 脚 3.3V 确认。JTAG 线上核心板/底板无任何元件; GW5A TMS/TDI 片内弱上拉。建议 TCK 飞线端加 4.7K 下拉。
- 🔴 与"J2 插 2.5V LDO 模块"(FS03 改板, 见 hw_pack 记忆)互斥: **先做加载测试再改板**。

## DR1 侧
- PS IP 没有 EMIO、dtb 无 axi-gpio ⇒ **libgpiod 用不了**, JTAG 四根做成 GP0(0x8000_0000)上的 PL 寄存器, /dev/mem 翻。
- 寄存器(任务约定): 0x00 MAGIC 0x4A544147 / 0x04 OUT bit0 TCK bit1 TMS bit2 TDI bit3 OE(默认 0 高阻) / 0x08 IN bit0 TDO, bit1..3 引脚回读 / 0x0C SCRATCH / 其余读 0xDEADBEEF, 任何地址必须应答。
- PL 工程 `jtag_load/pl/`(build.sh, load_pl.sh, rtl, constr, dtbo); 起点借 `dr1v90/td_soc1`(PS 例化 + GP0 从机, 板载 L18 25M)与 `measure/01_hpbw/build.sh`。TD DR1 专版 `C:\Anlogic\TD_5.9.1_DR1_2025.1_151.508\bin\td_commands_prompt.exe`; bit→bin 用 `C:\Anlogic\FD_2025.1\tools\bootgen\albg1.exe -arch dr1v90 -image x.bif -process_bitstream bin -w`(别用 TD bit_to_bin)。
- 加载: `mount -t configfs none /sys/kernel/config; cp pl.bin /lib/firmware/; rmdir …/overlays/pl; mkdir -p …/overlays/pl; cat pl_load.dtbo > …/overlays/pl/dtbo`, 判据 = dmesg 新出现 `fpga prog successfully`(cat 返回 -22 也可能已烧进)。PS↔PL 使能: 0xF8800080[1]=0 / 0xF8801078[0]=1 / 0xF8800084[0]=0(读改写回读)。🔴 gp_proten 清零后读无应答地址会挂死单核 ~3 分钟自重启。
- 软件 `jtag_load/sw/`(jtag_gpio.c/h, jtag_idcode.c, rbb_server.c, tap_sim 主机自测, Makefile)。交叉编译: `~/toolchains/riscv64-linux-musl-cross/bin/riscv64-linux-musl-gcc -O2 -march=rv64gc -mabi=lp64d -static -no-pie -fno-pie`(已验证非 PIE 纯静态, qemu 跑通; 工具链必须在 WSL 原生盘)。
- 🔴 **dr1a 不是台架板(是 WiFi 测试板), 台架 FS03 的身份/连接方式待用户确认, 动板前先核对**。povsh 用法(以 dr1a 为例): hostname `dr1a`, 找 IP `POVSH_BOARD=dr1a dr1v90/host/povsh_run.sh --find`; 执行 `POVSH_HOST=<ip> host/povsh_run.sh '<cmd>'`(后台命令用 setsid); 推文件 `host/povsh_send.sh`; 串口后备 COM5 `host/serial_run.ps1`(只发回车别发 Ctrl-C)。root 登录, devmem 不用 sudo。重启后自启会烧回生产 `pov/pl.bin`, 实验 bin 另起文件名、每次重启重新加载, **别覆盖卡上 pov/pl.bin**(MANIFEST 校验)。🔴 09-15 上午板子被实验 mt76 模块弄死过、当前状态未知; **另一个会话可能在用 DR1, 换 PL 前协调**。用充电头供电(电脑 USB-C 会重启循环)。

## PC 侧
- openFPGALoader 已全功能构建: `/home/wanqi/src/openFPGALoader/build/openFPGALoader`(commit 57a750c, 识别 0x0001281b GW5A-25)。WSL NAT ⇒ 板子做 server、PC 做 client。
- `-c remote-bitbang --ip <DR1_IP> --port <n> --detect` / `-m <.fs>`; 大块下载建议 `-c xvc-client`(按 server 缓冲打包)。remote-bitbang 每 TCK 2 字节、读 TDO 每 bit 一次 TCP 往返, 复位阶段先打 1,000,000 TCK(≈2 MB)+ 位流 ≈12.3 MB ASCII。
- openFPGALoader 加载 GW5A 前先发 0x3C(从 flash 重载)再擦 SRAM; 它的 .fs 校验和与 Gowin 头不一致但 GW5A 走 skip_checksum。

## 判据
1. IDCODE = **0x0001281B**, 连读 5 次一致(`jtag_idcode`)。
2. ~~加载 .fs 到 SRAM ⇒ 串口出 GW5A-LOOP 横幅 + D1 亮, 重复 ≥5 次(含断电)~~ 🔴 **09-15 作废: 会被 flash 镜像假通过**(openFPGALoader 加载 GW5A 先发 RELOAD 0x3C 从 flash 重配再空翻 100 万 TCK)。新判据以 `dr1v90/jtag_load/README.md` §S3 与 `sw/README.md` 为准: ① GW5A 断电上电、DR1 不跑客户端, 记基线横幅 N/L; ② JTAG 加载的 .fs 的 N/L 必须与基线不同; ③ Erase SRAM 后 D1 熄灭且整个 Load SRAM 期间保持灭; ④ `Load SRAM ... DONE`; ⑤ DONE 后新出现且 N/L 与本次 .fs 一致的横幅 + D1 重亮。上电顺序: 先接地 → FS03 上电跑 load_pl.sh → **GW5A 先上电** → jtag_idcode(默认 + `-d 200` 两次同值)→ rbb_server + PC `timeout -k 10 1200 openFPGALoader …` → 先 kill -INT 服务端再断 GW5A。准备流程 review/fix/doc 已全部跑完(README.md 已生成); riscv64 两个程序、load_pl.sh、MANIFEST.md5 在 16:19~16:33 被修正重编(`jtag_gpio.bin` 未变), 之前推到 dr1a 的是旧版。
3. ⚠ gw5a_loop 把 KEY0/LED 约束成 LVCMOS33, 但核心板 VCCIO01 = 1.5V ⇒ KEY0 可能恒读"按下"导致反复重扫眼 ⇒ **只看横幅第一行, 别依赖 K=1**。
4. 断电或 JTAG 0x3C 回到 flash 镜像; CB-V2 供电 J6 12V DC(S4 拨 DC)或 J5 USB。
