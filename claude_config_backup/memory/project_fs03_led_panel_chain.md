---
name: fs03-led-panel-chain
description: FS03 J12→双转接板→P0.9375 COB 屏 (ICND2049列驱+ICND3019行驱) 全链路拓扑/pin映射/上电红线; 映射表+XDC 已写进 mlkpai_fs03 仓 docs/vivado
metadata: 
  node_type: memory
  type: project
  created_at: 2026-07-06 21:05 CST
  updated_at: 2026-07-06 21:05 CST
  originSessionId: 2db86089-9605-4f0a-8b5d-90fce155b4e3
---

2026-07-06 新到 LED 屏开调 (FS03 板, [[mlkpai-fs03-zynq-usb-wifi-board]] 的 POV PL 线)。**权威文档 = `mlkpai_fs03/docs/led_panel_chain.md` (端到端 pin 表) + `mlkpai_fs03/vivado/panel_pins.xdc`** — 全部原理图坐标级抽取 + 用户实测线序确认, 别再从 PDF 重推。

## 拓扑
FS03 **J12** (50pin, **Bank13**, 每线33Ω全等长) ↔ 米联派接口板 mlp_panel_v1.0 (P2=50pin; **24V入**→TPS54560→5V; P5=光电传感器口; 双屏输出 P1/P3=30pin; 每线10Ω) ↔ 屏侧转接板 panel_0.93cob_trans (30pin→40pin BTB; buck 出 **VCC=3.8V/VCC_R=2.8V** 给屏) ↔ 屏。
屏 = 老 160×180 同构: **108× ICND2049 列驱** (9 数据线×12级联×16ch=1728列) + **24× ICND3019 行驱** (板位号 ICN2065GP/RT5960 是旧型号, 实贴 2049/3019, 用户为 BCM 换掉 PWM 芯片) + 板载 SPI Flash。

## 上电红线 → ✅ 2026-07-07 已解
1. ~~P2.1 5V 对灌 3.3V~~ **用户改板**: FS03 L16/L17 贴上 (VCC_CEP=VIN_5V0), L18/L19 移除。已核安全: FS03 输入级 = 二极管OR (VBUS→D15 / VIN_5V0→D16 → AO3401 → VCC_5V0), 接口板 5V 从 pin1 灌入是合法第三路电源, 单 24V 可带全系统; TPS54560 5A 预算留意 (FS03 1-1.5A+双屏)。
2. ✅ FS03 跳帽 J1 已设 1-2 (3.3V, ADJ_BANK13)。(FS03 的 J1 是跳帽, 别跟屏/转接板 J1 混。)
3. 24V 进接口板 P4.3(+)/P4.4(GND), pin1/2 悬空。

## 关键信号事实
- **GCLK 线 = 2049 的 OE** (线名是旧 PWM 芯片遗留); **A=3019 DCLK / B=3019 RCLK / C=3019 SDI** (老 160×180 屏 2026-05-27 实测确认, 同族约定, 见 zynq_pov led_panel_seq.v 注释), 行 LCK/BK 屏内由 LAT/OE 组合产生。
- **IP 底子 = zynq_pov `led_panel_seq.v`** (557 行, 老 1069+3019 同物理拓扑: 9-lane broadcast + 3019 三线): 3019 行链逻辑照搬 (DCLK ≥500ns 等坑见 [[feedback_led_panel_protocol_pitfalls]]), 列协议 1069→2049 (2038S 族, 更简单, 同 2047 经验)。
- 光电 SPIN_SYNC = CEP_11P = **FPGA W6** (接口板 P5: 3.3V/信号/GND)。
- 屏1 核心: DCLK=AB4 LAT=AB5 OE=Y5; 屏2 组 (_2) 在 XDC 注释段。SPI_MISO/传感器是输入。
- ICND2049: 协议**兼容 ICND2038S** (移位+LE长度编码指令+OE低有效, 同 2047 族经验); **内置双缓存** (OE=0 期间可移入下帧, 或缓解 BCM 小 plane 遮蔽, 待实测); FCLK max 25MHz; tw min 20ns; 共阴恒流源, R 芯片 2.8V / GB 芯片 3.8V, 与 3019 sink 极性配套。
- 转接板 J1(行序编号) ↔ 屏 J1(奇偶编号) 编号系不同但对位 100% 核过 (用户也实测 OK); 备用 pin 正好落屏 NC。

## ✅✅ 2026-07-07 首点亮成功 (红色方块走灯实见) + 三个关键教训
端到端链路全通 (FS03→50pin→接口板→30pin→转接板→BTB→屏, 2049列驱+3019行驱+双缓存OE转移全工作)。IP=`mlkpai_fs03/vivado/hdl/icnd2049_panel_seq.v` (老 led_panel_seq 移植: DCLK门控+OE寄存器+3019 FSM原样), bit=build_panel/, 工具=tools/_panel_light/_panel_probe/_panel_wires/_panel_beacon.tcl。
1. 🔴 **ICND2049 LE 长度编码: 3=普通锁存 4=换行(行+1) 5=首行, LE<3 根本不锁存** (REG2 默认 R_LATCH=0)。手册第12页"LE直通"时序图是老式描述会误导, 第14页指令表才是真相。首黑屏就是 le=1 白灌。latch1→reg2 转移=OE下降沿 (先锁存后拉低OE ✓)。
2. **必须连续刷不能一次性静态**: 3019 有"无信号保护", 静态选行会被关; 且走灯模式下 xsdb 循环 (~0.15s/轮) 足够肉眼调试。
3. 🔴 **电流预算就是显示预算**: 每芯片4点×3R链×4行=576LED≈8.6A 直接压塌 2.8V/3A buck (症状=方块闪现即灭+板载JTAG USB 掉线 FT_Write io error); 调试图形按 ≤2A 配 (单行×0xF000≈2.2A / 单行×0x8000≈0.5A)。JTAG 掉线软恢复: 杀 hw_server 重连即可, 板子不用动 (A9 挂起态和 PL 都保得住)。
4. 排查路上验证过的硬事实: 屏原理图 GCLKIN'→R11→OEIN / AIN→HDCLKIN / BIN→HRCLKIN / CIN→HDIN (坐标级图证); FCLK0=50M 验证 (SLCR 0xF8000170=0x00400500); Bank13 XDC 全对 (2Hz OE 信标在接口板 P3.10 实测); "50.56k方波"是当时发生器已死的残留假象, 别被一次性脚本的静默期骗。
5. xsct 长循环别接管道 head (SIGPIPE 连锅端), 输出重定向文件; 孤儿 rdi_xsct 会毒化 hw_server。

## 🔴 两个当天新坑 (2026-07-08 傍晚)
1. **rebuild_panel.tcl 只 reset synth_1 → module_ref OOC 缓存吃旧网表**: system_panel_0_0_synth_1 是独立 run, 不 reset 它 build "成功" 但 bit 是旧 RTL (v4 首烧三特性全无就是这个)。已修: rebuild_panel.tcl 加 `catch { reset_run system_panel_0_0_synth_1 }`。改 RTL 后 build 完可核 build_panel/mlkpai_panel.runs/system_panel_0_0_synth_1/*.dcp 时间戳。
2. **Digilent SMT2 (板1, 目标断电) 插着会僵死整个 FTDI/hw_server 栈**: connect 永久挂 (banner-only), 换 hw_server/新会话/板冷循环/拔插 MLK JTAG 全没用, **拔掉 Digilent USB 线立解**。规则: 用哪块板只插哪块的 JTAG。(板载 MLK JTAG=FT2232H 双通道="USB Serial Converter A/B"+COM14, SN 2515BCEF4DEA; Digilent=单 Converter, SN 210251A08870。)

## ✅ v5 build 通过 + rodin 错定案 (2026-07-08 19:32 重启后)
**BUILD_OK, WNS=10.425** (bit=build_panel/.../system_wrapper.bit + mlkpai_panel.xsa, 全新建仅 ~9 分钟非 13)。git push 欠账已清 (ed0fbf2 已推 GitHub)。
**rodin `Common 17-232` 根因定案 (agent 取证)**: 不是磁盘损坏不是缓存 — **瞬时 commit/虚拟内存耗尽** (失败 run 日志头 Available Virtual 仅 ~8.8GB/106GB, vmmemWSL 撑爆; rodin slave 解释器创建=分配失败, 所以每次炸点随机)。重启后 19:21 那败=开机 4 分钟 boot-storm。%TEMP%/AppData/tclapp 路线全排除 (Temp 仅 567 项零 Xilinx 垃圾)。
**规则**: rodin 错再现→先查 Windows 可用内存 (vmmemWSL, 考虑 .wslconfig 限内存), 开机 10 分钟内别跑 batch Vivado; 1 分钟级复现脚本留在 `D:\claude_workspace\pov3d\_rodin_debug\{repro,repro2}.tcl`。
**✅ 19:39 v5 fake 全管线上板通** → **🔴→✅ "每部分显示2次" 案 (22:20-23:00)**: 根因=旧 ps7_init 缺 AFI 写, 见 [[ps7-init-stale-afi-word-swap]] (阶梯诊断图案方法论也在那)。修复=从 v5 XSA 重抽 ps7_init, 无需 rebuild, commit c3c15cf。
**🏁🏁🏁 23:1x 体像素点亮 (2026-07-08 深夜)**: 光电 sensor 模式 + 旋转 → **用户实见体像素 (3D anime 转出来了)** = v5 POV 全链路 (光电 W6→angle_tracker→DDR 取帧→fb→2049/3019) 收官。注意: 当晚 rev_period 具体数值没抓到 (轮询会话挂 connect 被清, 显示是 PL 自主跑不受影响)。
**剩余队列**: 电机稳态长跑观察 (亮度/供电/机械) → overlap/亮度档在旋转下调优; 欠账: 示波器抓 v4.1 行间空档定案 / task#1 / rev_period 实测数值补记。

## 🚧 PC→WiFi→直显 动图栈 (2026-07-09 凌晨, 三 agent 全交付, 待上板联调)
用户定方向: PC 发点云动图 1-bit 直显。栈全在 `stream/` (commits e09bd5a/9abfd04/f716307 已推):
- **协议 PVS1** (stream/protocol.h): magic|comp_len|raw_len(4423680)|n_slices=360|flags(bit0 RLE/bit1 zlib), TCP :9500, 逐帧 ACK。zlib-6 实测 13× → ~320KB/帧 → 链路上限 ~29 模型fps (WiFi 不再瓶颈, 实际卡转速=每圈一帧)。
- **PC**: stream/pc/povstream.py (render/stream/bench; 动图源 spinpulse=anime呼吸摆披风 / globe / --dir; Bayer 相位随帧+片) + fake_board.py 回环。~2.3s/帧预渲染。
- **板端**: stream/board/pov_rxd (armv7 静态 430KB 已 commit, 零依赖): 双 bank 0x10000000/0x10500000, slice_idx<8 时 flip 0x18, 丢帧不阻塞; --fake rps 可免电机测。/dev/mem 映射 mem=256M 外=uncached 已核 (kernel 6.6 phys_mem_access_prot)。
- **boot**: stream/boot/BOOT.BIN = v5-XSA FSBL (AFI 写×3 已验 embed) + v5 bit + 出厂 u-boot (从 03_restore_factory 镜像抠出 byte-identical); uEnv.txt optargs=mem=256M (出厂 u-boot 有 uenvboot 钩子)。🔴 **坑: 出厂 u-boot 会跑 fpga_loadbit, FAT 上 system.bit.bin 必须改名** 否则覆盖 FSBL 的 bit (SD_CARD_GUIDE.md step1)。拨码: ON-ON=JTAG / OFF-OFF=SD。
- **联调序列**: 用户改 SD 按 stream/boot/SD_CARD_GUIDE.md → 插 dongle → SD boot → 串口核 cmdline/free/devmem → 连 WiFi (wpa.conf 已在板) → scp pov_rxd → root 跑 `pov_rxd --fake 0.5` → PC `povstream.py render --anim spinpulse` + `stream --host <板IP>` → 屏动图 → 真转速换 sensor 模式。
- slice_base flip 原子性已核: fetch_go 时锁存, RTL 免改。

## 🏆🏆 动图端到端收官 (2026-07-09 凌晨): 上电直显全自主验证通过
**PC povstream → WiFi(2.4G undef, 板IP 10.10.20.234) → pov_rxd → DDR双bank → 屏动图实见**; 24V单供+无Type-C冷启动全链自动恢复 (pov.service)。上板路上破了四个案:
1. **v5 XSA FSBL 不配 USB PHY 复位**: USB3320 RESETB=MIO7 (SCH P3/P10), 出厂 FSBL 有板级代码拉它, 标准 FSBL 没有 → ci_hdrc -110。
2. **sysfs gpio 编号动态不可靠** (base 512 跨 boot 会漂) → 确定性配方 = /dev/mem 直驱: SLCR unlock + 0xF800071C=0x600 (MIO7解三态) + **APER_CLK_CTRL 0xF800012C |= bit22 (gpio_aper 时钟, 内核 late-init 会关, 不开写不进 GPIO 寄存器!)** + GPIO 0xE000A204/208/040 bit7 复位脉冲(低2s高3s) + ci_hdrc unbind/bind + 等 wl 接口(循环30×2s)。
3. **brownout 三连**: WiFi TX 尖峰下整板重启 (7dBm 限功率也没救), 全部发生在 Type-C 插着时 (双供二极管OR, PC USB弱源被抢载) — 拔 Type-C 后待长测定论。**pov.service 自愈在 brownout 后全自动恢复实证有效**。
4. PowerShell .ps1 中文注释 (UTF-8 无BOM 被 GBK 解析) 会毁参数绑定 → 板控脚本一律纯 ASCII; 串口传文件走 gzip+base64 分块 (_upload.ps1, 先 dmesg -n 1 + rmmod 刷屏驱动防 RX 丢块)。
**板上部署** (repo stream/board/pov_boot.sh = 权威副本): /home/uisrc/{pov_rxd,pov_boot.sh,*.log} + /etc/systemd/system/pov.service (enabled, 用户授权)。ssh: WSL→板不通(防火墙), 走 Windows ssh, key=C:\Users\kiujkiu\.ssh\pov_ed25519; root 通道=只有串口 (用户拒 NOPASSWD, 选按需插 Type-C)。串口三件套 stream/boot/_expect/_upload/_scan.ps1。
**后续同夜进展 (07-09 02:00-02:40)**: ①sensor 版已装 (v3→v4) ②**pov_boot v4 = bank A 开机预载 /home/uisrc/anime_slices.bin** (无WiFi直显默认anime, 推流到达翻页自动切换; 换默认动画=scp 覆盖该文件, 免root) ③**POV Studio 图形软件交付** (stream/pc/pov_studio.py + POV_Studio.bat, commit 216087f): 设备扫描/状态灯/板日志 + GLB渲染/预设/预览 + 推流带**自动重连** (板重启自动续流) + 一键设开机默认; povstream.py 重构出 Streamer 类 (--reconnect), 测试 9/9 ④Type-C 弱源实锤: 拔掉后 fake 模式 4.5 分钟稳定零断流 (vs 插着 ~3 分钟必崩)。
**🔴→✅ 电机 brownout 已解 (2026-07-09 上午, 用户硬件修)**: **5V→2.8V buck 输入端加大电容** — 电机启动/WiFi TX 瞬态在源头被缓冲, 5V 轨不再压塌, 电机运转下板子稳定。之前"电机一开重启循环"的根因 = 2.8V buck 输入抽载瞬态拖垮共享 5V。待长跑复验。次要遗留: 2.4G→5G 摸底 / RTC 无电池 / rev_period 正式记录 (~4.0rps 实测于翻页间隔 248ms)。
**✅ WiFi 议题闭环 (07-09 中午)**: dongle 拔插复活 (确系物理松脱/锁存) → v6 满功率生效: **2.4G ch6 信号 -36dBm / PHY 258Mbps / 实测吞吐 3.5MB/s=28Mbps** (bw_send.py↔bw_sink.py 对账零丢失) — 1-bit 满转速 6.6fps 需 ~18Mbps < 28 ✓ 够用+50%余量。**7dBm 限功率才是之前掉线抖动的元凶** (电容修好后限制应立即撤——教训: 应急手段要随根因修复回收)。5G freq_list 没生效 (2437 依旧, AP 5G BSS 疑不可见), 留作 >28Mbps 需求时排查。⚠ ssh 非登录 shell 无 /usr/sbin, iw 要全路径 (别把 command not found 误判成链路死)。
**(历史) WiFi 5G 切换卡在 dongle 物理离线 (07-09 上午)**: v6 已装 (txpower 限制删除 + wpa.conf 5G freq_list 优先双块, 原配置 .bak24g)。但 Type-C 插入瞬态疑似又触发一次重启, 该 boot USB 起来后 dongle 从总线消失: EHCI/PHY 全健康 (ULPI viewport 读 SMSC 0x0424 ✓), PORTSC CCS 恒 0 = 插座无电气连接, **VBUS 软拔插 (ULPI OTG_CTRL 0x0B/0x0C set/clear 0x60, viewport 0xE0002170) 15s 也无效** → 物理问题: dongle 震松脱落 (转子震动!) 或 CH217K 过流硬锁存。恢复 = 用户拔插 dongle (免重启, 总线自动枚举) 或断电。**ULPI viewport 软拔插配方存 /tmp/vbus_cycle.py + 本条** = dongle 挂死第一救援手段。带宽实测 (2.4G 基线 + 5G 对比) 排队在后, 测速脚本 stream/pc/bw_send.py + /tmp/bw_sink.py。
**断口案结档 (07-09 上午)**: 圆环断口复测消失 = 瞬态 (翻页撕裂/电机打断取帧的瞬间), 数据+硬件双侧均已排除 (逐列点数完整 + RGB 实心盘三色无缺); 复发再查, 诊断帧留存 frames_rings (三环: 红25/绿38/蓝50)。
**04:45 地球仪演进 (07-09 后半夜)**: 壳版稀疏偏青 → 三步到位: ①纯通道色修偏青 (1-bit 混通道 G=70 过阈值→青, 图形学内容一律纯 R/G/B) ②直径减半(用户定, R=0.48×预算) ③**终版=实心真贴图** (移植 zynq_pov _gen_globe_slices 方案: stream/pc/earth_clean.jpg=NASA Blue Marble 本地拷贝 + 方向投影 + 海b>g+10&b>r+10/冰全>170/余=绿): 442→**6842 点/片** (实心圆盘截面, POV 物理见 [[pov3d-vs]])。commit 6ed6073。⚠ 办公网拦 wikimedia/NASA 外链 (curl 只回错误页), 真贴图资产一律用本地 zynq_pov/tools/earth_clean.jpg。
**07-09 上午续 (05:00-08:00)**: ①globe 最终形态=**空心壳+NASA真贴图** (用户明确不要实心, commit b83e079, 已落板默认 md5 cf4d5660) ②pov_boot **v5 fastboot** 已部署 (显示最先/脉冲1.1s, 8b9a7c9; service 提前挂还欠 root) ③**GLB 动画加载器交付** (a53723d): glbseq (--glb-dir 帧序列) + glbanim (单 GLB 骨骼skinning/morph/TRS, glb_anim.py, sticky采样防抖) + 测试资产 spincube/armskin/morphcube ④POV_Studio.bat 修 CRLF (⚠ Write 工具默认 LF, **.bat 必须 CRLF**) ⑤带宽账: 1-bit@4rps 只用链路 10-30%, 20rps 需切 5G, 3-bit 需帧间 delta 或有线 ⑥⚠ zynq_pov glb_to_points._node_matrix TRS 序反 (S@R@T, 静态没事动画会错, glb_anim 自带正确实现, zynq_pov 侧待修) ⑦**遗留 bug: 单片圆环有断口** (用户圈图, 数据侧已排除=显示链问题, X≈52 跨分区边界或电机震出新虚焊; 纯绿盘+RGB循环诊断帧已备 frames_diagdisk/frames_rgb, 板掉线没测完)。
**⏸ 未完成交接**: 实心地球仪 bin (md5 fbe1badd...) **没落到板上** (板被电机 brownout 循环按死, scp 全失败) — 板上默认还是壳版 (2a2a4855)。恢复动作: 电机停+板上电 → `scp frames_globe/frame_0000.bin uisrc@10.10.20.234:/home/uisrc/anime_slices.bin` + 推流 `povstream.py stream --dir frames_globe --fps 4 --loop --reconnect`。用户还问过"地球仪能不能 GLB 加载"→ ✅ 2026-07-09 16:1x 已做 (commit 984964a): povstream `spin` 预设 (任意 GLB 绕竖轴自转, --scale 缩放 / --shells N + --shell-gap 洋葱加厚) + `make_globe_glb.py` (纯 pygltflib 手写 UV 球, 贴图预分类纯通道色烘 baseColor, 配 --lighting none + brighten/gamma/sat 全 1.0 原色直出; WSL 无 trimesh 且 PEP 668 拦 pip, 别走 trimesh 路线)。globe_pure.glb → shells=3 实测 1412 lit/slice ≈ 定稿 1308, 当天已推流上屏。GLB 手性公式与 globe 源一致 (x=cos lo, z=sin lo, tex col 随 lo 增), 上屏取向同定稿。

## 🌍 浮雕地球仪 relief 版 (2026-07-09 下午, commit f7611a9, ⏸ 用户令先别上板)
用户要照片那种立体地形地球仪 (海拔有高度+颜色, 太空视角), **仍 1-bit**。`make_globe_glb.py relief`: 顶点 r=R×(1+e×0.12) (屏上峰值≈4.5 voxel), 分层设色 绿→黄→红→白 + 海纯蓝 (锚点全 1-bit 纯组合色, 过渡交 Bayer 逐通道混色); 海拔源 = `earth_topo.png` (three-globe earth-topology, **github raw 办公网可达**, NASA/wikimedia 仍被拦); 🔴 冰盖分类必须限 |lat|>50° (撒哈拉亮沙漠 RGB全>170 会误判成白冰)。frames_globerelief 已渲 (36帧, 1465/片)。效果预览 artifact: https://claude.ai/code/artifact/fc390ad8-2aea-494b-9078-7db6ad8fe716 + viewer globe_relief.glb。
连带修 zynq_pov glb_to_points **searchsorted 越界 bug** (float32 cumsum 误差, 三角形多必现, commit 511890c)。
🔴 **pov_rxd 幽灵连接卡死**: 单客户端 recv 无超时无 keepalive, WSL 推流进程被杀后 NAT RST 不达 → 板上 ESTAB 半开永卡, 9500 拒新连接 (板 ping/ssh 正常, WSL→板 ssh 现在直通了, key 拷 ~/.ssh 600)。解法=root 重启 pov_rxd (串口) 或板电源循环; 根治=pov_rxd 加 SO_KEEPALIVE/RCVTIMEO (待做)。⚠ pkill -f 推流时 pattern 会自匹配 bash wrapper 连自己杀 (exit 144), 用 'frames_globe[r]elief' 括号技巧。⚠ 同时有**并行会话** (Windows python 推 frames_rings + povstream 加了 palace 源), 改 povstream 前先看磁盘版。
**03:00 封盘补充**: ①globe 已渲染 (frames_globe, 911 点/片 vs anime 1456, 电机稳后重验亮度再决定加厚壳层) ②"flip 250ms"≠转速证据 (= 发送端 4fps ACK 节奏, slice_idx 冻小值时 flip 门常开) — rev_period 才是转速权威 ③sensor 静止=单片稀疏散点是正常形态 (用户已目验), 转起来人眼积分成体 ④判读铁律: 帧在 flip ≠ 屏在显示 3D, 要么读 rev_period 要么问现场。收工状态: 电机停/板自愈待命(默认anime单片)/PC 推流已停(遗留 python 全杀)/POV Studio 待用户白天目验 GUI。
工具补充: _pov_sensor_poll.tcl (sensor 加强轮询 0x10/14/18); ⚠ xsct 会话若 banner-only 挂 connect: TaskStop + taskkill 孤儿 rdi_xsct 再来, 别叠会话。

## 🖥️ 硬件特性: 屏中央 (转轴附近) 显示效果差 (2026-07-09 用户实见)
用户确认转轴附近区域显示质量差 (过轴切片重叠+线速度→0), **内容布局规则: 尽量平移离轴显示, 不要把主体压在屏中央**。povstream render 侧加水平偏移参数解决 (波比首验)。

## 🎮 LoL 英雄上屏 (2026-07-09 晚) + 幽灵卡死复发实录
悠米 R 上屏成功 (frames_yuumi, glbanim 蒙皮渲染, fps 4)。内容库新增: frames_yuumi; 65 个 LoL 女性角色 glb+GIF 库在 `models/heroes/lol/` (流水线见 [[lol-dota-model-pipeline]])。
**盘旋模型解转轴差区 (07-09 深夜)**: 用户嫌人形角色居中显示差/偏移又太小 → **铸星龙王 DanceLoop = 最优** (蛇形龙身天然绕轴: r<20 仅 8% / 中位半径 46, vs irelia R 21%/39; 密度 184/片>irelia 139, 深蓝身没被 1-bit 吃), 已上屏 frames_asol_dance; 备选已渲 frames_asol_runspin (螺旋飞行 17%) / frames_asol_idle (悬浮盘绕 15%); 蛇女 Dance 12%/40 次优。**径向分布量化法**: AnimSampler 采样→robust bbox 归一→r=√(x²+z²) 直方图, 选内容/take 先跑这个再渲。
🔴 **推流 fps 别设成贴着转速** (07-09 深夜实测翻案): --fps 4 时发送 sleep+ACK RTT 叠加让实际只有 3.5 页/秒 < 电机 4.5 rps = 白丢 28% 显示帧率; **正解 = --fps 设高 (12), 逐帧 ACK 门控自动贴住翻页率** (实测 222ms/页=4.5页/秒 全帧 flipped 零丢), 电机转速成为唯一真瓶颈。显示帧率判读用板端 pov_rxd.log 翻页间隔, 别信发送端设定值。

## 📊 系统关键数值 (2026-07-09 深夜实测汇总)
- **电机转速 ≈ 4.5 rps** (翻页间隔 222ms, 电容修复后比上午 4.0 略快; rev_period 寄存器正式读数仍欠) → **显示帧率天花板 = 4.5 页/秒** (每转一圈翻一页)
- **WiFi 2.4G ch6**: 吞吐实测 28 Mbps (3.5MB/s), 信号 -36dBm / PHY 258Mbps
- **典型帧带宽**: 角色类 zlib 压后 80-115KB/帧 (50× 压缩比), 4.5页/秒 只占 ~3.5Mbps = **链路 12%**; 纯传输能力 ~29 帧/秒
- **提升显示帧率唯一路 = 提电机转速**: 6.6 rps → 6.6页/秒 需 ~18Mbps < 28 ✓ 供电经 07-09 上午 buck 电容修复后待验证长跑
- **动作连贯配方**: 帧数 ≈ take 秒数×6 (每帧 ≤0.17s 动作量), 4.5页/秒下轻微慢放最顺
- 内容库新增: frames_asol_{dance,idle,runspin} / frames_zac_dance{,72} / frames_yasuo_r{2,3} / frames_robot (Robot.glb 144帧, 1559/slice 密度冠军) / frames_groot (96帧) / **frames_bonsai3 (07-10 定稿)**; models/Models/ 还有 Dino/Skeleton/walking/Engine 未试
- 🔴 **1-bit 断点诊断配方 (07-10 bonsai 实证)**: 静态 GLB (Tripo AI 类) 贴图大面积中间调 → 阈值点不亮全靠 Bayer 抖动 ≈ 半密度散点 → 旋转体断续断点。**定位法 = 渲一帧 --no-dither 对照**: no-dither 点数反而更低 (bonsai 341 vs 抖动 774) 即坐实中间调问题, 非显示链/虚焊。修法 = `--brighten 2.0 --gamma 0.8` (中间调顶过阈值) + `--shells N` 加厚: bonsai 774→shells2 1585→**shells8 3498/片 (定稿, spin 预设)**; shells 增益递减 (内壳缩小), samples 加倍无用 (体素网格饱和)。跷跷板: 密度↑帧变大 (614KB) → 翻页降 ~2.25页/秒
- commit a252b61 (pure-rgb + robust-fit/x-offset + fps默认12) ✅ 已推 GitHub (办公网 github 曾短暂全断 ~10min, TLS 握手失败是网络波动非凭证, 挂后台 90s 重试循环第 2 次即通)切流实录: kill 本侧推流 FIN 正常送达无幽灵, --reconnect 新流秒接 (幽灵只在 NAT 旧模式/异常断出现)。
🔴 **幽灵卡死复发全程**: 并行会话 `_push_globe.py` (17:04 起) 占单客户端槽半卡死 (Send-Q 8.4万积压, pov_rxd 54% CPU R 空转) → 新推流永远 SYN-SENT 排队, 屏显 bank A 预载 (anime) 让人误判 → 杀 sender 也救不回 pov_rxd (uisrc 无权杀 root 进程, sudo 无 NOPASSWD) → **唯一解=板电源循环**, pov.service 自愈后 --reconnect 流自动顶上。规则: 推流前先 `ss -tn | grep 9500` 查占用。
✅ **幽灵根治补丁已做 (2026-07-10 13:0x, commit 9323f4e)**: pov_rxd 加 SO_KEEPALIVE (idle 10s+3s×3≈19s判死) + RCVTIMEO 30s / SNDTIMEO 10s; ARM 静态重编+回环测试 PASS, **板上已生效 (07-10 13:30 用户断电重启激活, 26s 全自愈+续流)**; 此后幽灵应 ≤30s 自动踢掉, 若再见 9500 长卡 = 补丁失效要复查。07-10 12:53 幽灵第三次复发 (板 12:47 重启后 --reconnect 换端口, 旧连接成幽灵), 同源端口 RST 戳一下秒解 (第二次实战), 脚本固化 scratchpad rst_ghost.py 思路: bind 幽灵客户端源端口+SO_REUSEADDR → connect :9500 → close(linger0)。
✅ **幽灵免重启解法 (2026-07-09 21:00 实证, 波比切换现场)**: 板端 ESTAB 幽灵 (WSL 杀推流 FIN 不达) → 本地 socket **bind 同一源端口** (SO_REUSEADDR, WSL mirrored 网络端口 1:1 上线) 再 connect :9500 → 板内核对幽灵回 challenge-ACK → 我方内核回 RST 拆掉幽灵 → pov_rxd recv 解锁回到 accept, 新推流即入。整个免 root 免电源循环, ~秒级。切英雄标准序: kill 旧推流 → 若新流 SYN-SENT 超时 → 查板端 `ss -tn` 拿幽灵的客户端源端口 → 同端口 SYN 戳一下 → reconnect 流自动顶上。
⚠ pkill 自匹配坑变体: pattern 用了括号但**同一条 bash 命令其他部分含明文目录名**照样自杀 (exit 144), pkill 和重启拆两条命令。

## 🚧 v5 POV 全套 (2026-07-08 20:30, sim 全绿, build 中, commit c5df5df)
目标=这套硬件转出 3D anime。三 agent 并行一晚全交付:
- **icnd2049_panel_pov.v** (v5, 模块改名过 BD 坑): spin_sync(W6)→angle_tracker (⚠zynq_pov 独立文件是修复前版, 已带 2026-06-15 两 bug 修复移植) + ddr_slice_fetch (AXI4 读主, v6 DMA 套路, slice_base+idx*0x3000, 11664B/slice lane-major) + fb 写口仲裁 + 寄存器 0x10 POV_CTRL{pov_en,fake_en,n_slices}/0x14 fake_period/0x18 slice_base, 读 0x10 slice_idx/0x14 rev_period/0x18 峰值锁存。**fake_en=免电机免光电全管线验证**。
- **anime 数据**: tools/anime_slices.bin (360×0x3000=4.4MB, gen_anime_slices.py, 源=zynq_pov host/anime_62459.glb 1.8M 点采样); 轴在屏中心 X=79.5 (右半 θ/左半 θ+180°); Bayer 抖动相位随 slice; 无径向补偿 (避 Voxon P3)。pack_obs.py=映射库 (与 gen_chess_obs diff=0)。
- **BD v5**: create_panel_proj_v5.tcl (smc→HP0, spin_sync const0 显式查杀, panel_pins_v5.xdc W6 LVCMOS33+false_path); rebuild_panel.tcl OOC 通配 reset。
- 集成 sim tb_pov_int.v 全绿 (fake 轮播/真脉冲 rev_period 精确/硬回零/18 fetch 对账/丢帧跳最新)。
- 上板工具 _panel_pov.tcl [fake|sensor] [rps]: 烧+dow -data 灌镜像+配 POV。**下一步: build 完→烧→fake 0.5 rps 看切片轮播→接光电(P5)→sensor 模式手拨→电机**。

## 🏁🏁 1-bit 里程碑收官 (2026-07-08 18:45): 彩色编号棋盘观察者视角全对
数字/色序探针 (gen_lane_digits.py 7段码 lane 身份 + _panel_colorprobe.tcl 三组 mask) 三张照片解出**全部映射, 已实测锁定**:
- **条序 (用户视角左→右) = lanes{6,7,8} 53宽 / {3,4,5} 53宽 / {0,1,2} 54宽** (与 fb_pack 默认假设相反!)
- **组内色序 R,G,B = lane_base+0/1/2** (9/9 实拍确认); **条内水平镜像**: 扫描行 r = 条内从右边缘数第 r 列 (53宽条 r=53 落空); 竖向 Y 直通上→下
- **权威打包器 = tools/gen_chess_obs.py** (观察者视角 160×180 生成+直写打包二合一, fb bit: h=11-Y//15, bit=(h%2)*16+Y%15, 字=h//2)。fb_pack.py 的 rotate 路径映射不符此屏, 弃用
- 终验: 72 格彩色编号棋盘 (7色循环+编号+白边) 观察者视角全对: 0红格左上/数字正立无镜像/接缝无错位 @ 25M overlap 1/4 亮度
- 探针方法论: 7段码数字每 lane 一个 = 一图解"区排列+色+旋转+镜像"; 镜像判读靠手性数字 (2/3/5/6/7), 对称数字 (0/8) 会骗人
- ⚠ 摄像头 cam0/1 MSMF 起流失败未解 (0xC00D3704, 疑被占用), 全程用户手机照片代
**下一步队列**: SPIN_SYNC 光电 (W6) 接入 / 动图管线 (WiFi→DDR→fb) / 与 mlkpai USB WiFi 数据通路汇合 ([[mlkpai-fs03-zynq-usb-wifi-board]])。

## ✅✅ v4 overlap+25M 上板收官 (2026-07-08 17:30): 7色循环 OK
用户验收通过: 全屏实心 + 1/4 亮度 (oe_window=48/192) + 25M overlap 7 色轮换无异常。刷新 ~1.9kHz。上板用 `_panel_ovl8.tcl [force]` (force=强制重烧新 bit; 无参=PL 活着跳烧写)。STATUS 健康 = 高位清 + 0xD0 (bit7 fast/bit6 ovl/bit4 auto)。overlap 下电流: 全屏白 3.8V 轨仅 ~1.9A, 7 色全安全, 不再需要棋盘/跳色凑预算。

## 🚧 v4 overlap+25M (2026-07-08 14:40, xsim 全绿→上板 OK)
用户定规格: DCLK 25M + 1-bit BCM overlap (OE 窗=移位窗内占空调光, 192 DCLK/行, 默认 48=1/4 亮度→白场 3.8V 轨压到 ~2.4A 顺解电流预算)。RTL v4 = icnd2049_panel_fb.v 无新端口(躲 BD 重建): subcmd10 加 cfg_we=bit27 门控 {bit29=dclk_fast, bit28=overlap_en, [15:8]=oe_window(DCLK)}, 状态位 [7:6]=fast/ovl (tcl 健康掩码改 0xFFFFFF00)。overlap 实现: OE 低显示行N同时移入N+1 (2049 双缓存, 转移在OE下降沿), oe_cnt 独立计数, AU_WAIT 双门(移完&&窗收), 切行必消隐, au_row 在 AU_ROWW 递增。**xsim: v3 回归 8 项 + overlap 7 项全 PASS** (OE 低窗内 47 DCLK 沿实证 overlap; TB 用 negedge oe 做段边界)。预期 ~1.9kHz@54行。工具: _panel_overlap.tcl [oew] [fast] [ovl] (停auto→cfg→开的安全序; dclk_fast 不能带载切)。

## 🔴 供电规则翻案 (2026-07-08 13:30): 24V 单供是正解, Type-C 别插 PC
昨晚"Type-C 保持插着"作废。实测: Type-C(PC 5.1V)+24V 双供 → 二极管 OR 交界反复切换, 瞬态打进共享 5V 网(P2.1 同网) → 转接板 3.8V buck 输入抖 → **G/B 全场刷滚动带 (R 好因 2.8V 独立轨余量大)**; 拔 Type-C 后 G/B 干净。24V 单供带全系统 OK (改板后 P2.1→D16 路实测能带板)。⚠ 拔插 Type-C 的瞬态会 brownout 抹 PL 配置 → **凡 brownout 过: 旧会话作废, 必须板冷循环+主机清进程+新会话** (brownout 半死 PL+旧会话失败写事务=DAP sticky 配方, 今天两次静默卡死都是它)。要 CH342 串口时才插 Type-C, 插拔前先停屏。_panel_8colors.tcl v2 已加同会话自愈重烧(限3次)+时间戳+flush stdout (xsct puts 重定向文件是块缓冲, 屏在动≠日志有字, 别误判卡死)。

## 📍 RESUME 点 (2026-07-08 12:15 更新: fpga 静默失败已解 ✅)
**2026-07-08 中午按 SOP 一次通**: 主机清零 (rdi_xsct/hw_server 杀干净, 昨晚僵尸 72340 拔线后自愈) → 板冷循环(无SD)+JTAG USB 拔插 → `tools/_flash_check.tcl` 分步验证: fpga OK + devcfg INT_STS=0xf802001f (**PCFG_DONE=1**) → `tools/_panel_8colors.tcl` (alt-port 3122) board ready + fb filled + 红绿蓝循环运行中。**结论: 昨晚的静默失败就是 churn 毒化 (僵尸 hw_server + DAP sticky), 硬件无恙; SOP 有效, 照做即可。** repo HEAD=76a0472。
**日常操作**: 分步验证=`_flash_check.tcl` (每步显式打印+devcfg DONE 位); 色循环=`_panel_8colors.tcl`; 换图形走寄存器绝不重启会话。
**今晚故障链复盘 (已固化为规则)**: ①屏电流脉冲拖垮共用5V→FS03 PL掉配置 (**已解: FS03 插自己 Type-C, 二极管OR兜底**——保持插着!) ②反复杀 hw_server/重烧 churn→DAP sticky+僵尸进程→读写全垃圾 (0x17002=PL半死的读数特征)。**规则: 换图形走寄存器 (_panel_color/_panel_rows), 绝不重启会话; 一个循环会话开着就别动它。**
**队列 (硬件恢复后)**: 三色循环→用户焊接检查报虚焊清单→补焊→orient_f90/f270 探针定取向→fb_pack --rotate 重打包棋盘→**1-bit 里程碑收官**。之后: DCLK 25M 运行时切换 (RTL 待加) / SPIN_SYNC 光电 / 与 WiFi 数据通路汇合。

## ✅✅✅ 2026-07-07 晚: v3 framebuffer IP + 棋盘格上屏 (1-bit 里程碑 95%)
- **IP v3 = `icnd2049_panel_fb`** (vivado/hdl/icnd2049_panel_fb.v): v2 auto 引擎 + **9 lane × 512×32 BRAM fb** (AXI 窗 awaddr[15]=1: 地址=0x40018000+lane*0x800+row*0x20+pair*4, 32bit=2×16bit word) + use_fb(subcmd11 bit1) + 行数寄存器(subcmd10 [24:16])。xsim 仿真 agent 全项 PASS (192沿/word重组/LE 5|4/OE窗/回绕)。
- **屏几何 (用户口述+实证)**: 扫描轴160=3区54+53+53 **并行**同数据 (rows=54 ✓整屏均匀); 列轴180=12颗2049×**15**通道(每颗浪费1个, dummy默认OUT15猜测暂对); 屏**竖放**(180轴垂直)。色序正: R→红 G→绿实拍。
- **棋盘格已显示** (tools/gen_chess160.py + fb_pack.py 全参数化 + chess160_fb.tcl; _panel_chess.tcl 灌+开): 格子/数字/边框清晰, 无15px撕裂 → chip序/bit序/dummy 默认全对; **待修: 取向 (需逆时针90°+疑似镜像) + lane↔(区,色) 排列** — orient_f 探针图形一照定 8 种取向, agent 已在做 --rotate。
- **工具链**: _panel_auto.tcl(烧+auto) / _panel_color.tcl(换色) / _panel_rows.tcl / _panel_chess.tcl / rebuild_panel.tcl(**增量build 5分钟**: 开工程+RuntimeOptimized, 全新建13分钟仅module改名时用) / cam/snap.py+watch_panel.py(摄像头cv2 cam0 MSMF 720p, 可自动看屏)。
- ⚠ **屏上 2049 是手焊的, 有虚焊**: 实拍顶部带右段缺失 = 右区G链级联最末芯片可疑 (单芯片缺=自身虚焊, 成串缺=中间级联断)。fb 单芯片点亮图形可出芯片级好坏地图供补焊。
- DCLK 25M (2049上限): 计划做成运行时可切分频 (12.5/25M), 打进下次 build; 现瓶颈在显示窗非移位 (fb模式已~234Hz)。
- v2 教训: BD module_ref 加端口/改位宽必须**改模块名+删build目录全新建** (老坑 feedback_vivado_bd_addr_width_cache)。

## 下一步
断 pin1→查跳帽→逐级电压→PL 静态图形 (先单色 R/G/B 验九线映射+色序, [[feedback_panel_brg_vs_grb]])→光电 ILA。IP 从 icnd2047_panel_seq 系改造 (9 lane × 12 级联 W=192? 几何靠 [[project_pov3d_calib_sweep]] 反推)。相关: [[project_pov3d_final_target]] [[reference_led_driver_chips]]
