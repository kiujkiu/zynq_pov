---
name: project_dr1_pl_decode_parity
description: 🎯 2026-09-01 DR1 的 PL 三引擎硬件解码跑通并追平 Zynq — 71.4ms/帧 = 0.98 B/clk(Zynq 74ms/0.95), eng=3/3, drop=0; 挡路的是 pl_selftest 的 DR1 专属 cache 缺陷
metadata:
  type: project
---

# PL 三引擎解码在 DR1 上跑通 (2026-09-01)

```
FRAME seq=0 n=284 comp=166760 flags=0xe8 dec=71.4ms pl=71.4ms 3str/PL
STAT rx=2 flip=2 drop=0
PLDIAG pl 71.4/71.5ms n=2 0.98B/clk out=20448KB eng=3/3 fb=0 ok=1 pipe=off
```
| | Zynq 现役 | **DR1** |
|---|---|---|
| PL 解码 | 74 ms/帧 = 0.95 B/clk | **71.4 ms/帧 = 0.98 B/clk** |
| 并行 | 3 引擎 | `eng=3/3` `3str/PL` |
| 丢帧 | drop 9 | **drop=0, flip == rx** |

## 🔴 挡路的是 `pl_selftest` 的 DR1 专属缺陷 (两层)

**① 缺 cache 回写**: 自检把 LZ4 流写进 CACHED 的 comp 缓冲后只有 `wmb_frame()`,
而 `pov_rxd.c:761` 自己写着"**DR1 上光有它是不够的** —— 见 `frame_flush()`"。
屏障只排序**不赶出 D-cache**, HP 口不 snoop ⇒ 引擎读到旧内容 ⇒ 三个引擎全报
`E_OFF0` 判死 ⇒ **整条 PL 通路被关掉**。
🎯 `pl_dispatch()`(真帧路径)一直有 `frame_flush`(`:2199`), **只有自检漏了** ——
"自检"成了唯一过不去的那一关。

**② 读回做不到, 是基础设施缺失**: 加 flush 后引擎 **done 且不报错**, 但读回是
`memset` 的 `0xa5`, 不一致点落在 **128/448 字节 = 64 的倍数(cache line 边界)**。
`povmem_dr1.c:242` 的 `IOC_FLUSH` 是 `dma_sync_single_for_device` ——
**只 writeback 不 invalidate**; `/dev/mem` 对这块 CMA **同样是 cached**(实测)。
🎯 **驱动没实现读方向是因为真实帧路径不需要**(PL 直写 bank, CPU 从不读 bank);
**自检是全项目唯一"CPU 读 PL 写的数据"的地方**。
⚠ **读回前再 flush 一次是有害的** —— 会把 cache 里的 `0xa5` 写回 DDR 盖掉结果。
⇒ 判据降级: `cmp[k]==0xa5 && k%64==0` 判活并**明说数据未验**, 其它形状仍判死。

## 端到端配方

- 上游 `mlkpai_fs03/stream/pc/povstream.py` **直接能推 DR1**
  (两边 `protocol.h` 只差一行 `PVS_FRAME_RAW_MAX` 12MB vs 21MB)
- `povstream.py stream --dir <frames> --host <IP> --port 9500 --codec lz4
  --lz4-level 12 --stream-split even --stream-workers 3`
- 🔴 **必须 `--stream-split even`**(切 [94,95,95] 三条等分流 = 三个引擎);
  `balanced` 出 **4 流**, 那是当年给两个 CPU 核调的
- 板端 `--pl-lz4 --pl-engines 3 --no-pipeline`
- WSL2 NAT 无碍: povstream **主动 connect 出去**, ACK 走同一条 TCP 回来
- 压缩比实测 **62.9x**(10.47MB 帧 → 166KB)

## 🔴 容器路径最多 2 流

`pov_rxd.c:2415` **硬拒 `PVS_FLAG_MSTREAM`** ⇒ 一个 `.pvs` 最多两条流(面A/面B)
⇒ **开机固化内容只用得上 2/3 个引擎; 吃满三个只有网络推流**。
`dr1v90/tools/make_idle_anim_dr1.py` 能出 lz4 容器(现有 `helix3b.pvs` 是 zlib, flags 0x8a)。

## 🔴 2026-09-15 连续推流撑不住: 37 帧后引擎卡死 + 读错数据, pov_rxd 永久关 PL
09-01 那次**只解了 2 帧**。09-15 首次连续跑(WSL 点对点 WiFi, 原版驱动, 手动加载 pl_hp1.bin, `--pl-lz4 --pl-engines 3 --no-pipeline --fake 16.15 --fake-slices 142`,
frames_helix 36 帧 `--loop` @12fps, 每帧 ~186.5 KB 3 流):
- seq 0..36 全部 `3str/PL` 71.5-71.8 ms, eng=3/3, 0.98 B/clk(与 09-01 一致);
- **seq=37**(= 循环第二遍的第 2 个文件)**引擎2 卡死**: `STATUS=0x00000020` busy 恒 1 不 done 不 error, 400 ms 超时摘出 ⇒ 2/3 引擎 142 ms/帧;
- **seq=50 引擎0 流#2 报 `STATUS=0x06 err_code=1 E_OFF0`**, 但**同一份数据 CPU liblz4 解得出** ⇒ PL 读到的字节与 CPU 不同(不是流坏) ⇒ pov_rxd 永久关 PL, 退 CPU 串行 ~210 ms/帧, rx=flip=4.3 fps。
- 引擎无软复位, 只能重载位流/重启。GP0 读一直正常。
- 待验假设(未测): ① CACHED povmem comp 缓冲的 D-cache 刷写不完整(失效恰在循环复用同地址、同尺寸时出现); ② 假转 HP0 取片与 HP1 lz4 DDR 争用; ③ RTL 引擎持续满载的健壮性。
⇒ **DR1 的 PL lz4 解码目前不能算"可用"**, 端到端真实收包(L3)被它挡住。
- 🔎 **离线 RCA(5 agent 工作流, `results/2026-09-15/rxd_p2p/PL_RCA.md`, 全是推算未上板)**: 汇总先把"CCM D-cache 回写循环无关中断保护、被 USB DMA tasklet 打断 ⇒ comp 缓冲尾部没进 DDR"排第一(~40%);
  **对抗审查改判**: DR1 D-cache 只有 32 KB, seq 50 出错那行在刷写前早被逐出写回, 且 CPU 按序解到那里时已是从 DDR 读的 ⇒ "DDR 一直是旧数据"类被排除;
  改排: **H3 PS/HP1 读路径给引擎错/丢/重复 R beat(引擎不看 RRESP/RLAST, 含 DDRC 内部陈旧读) ~40%** / H6 热加载 PL 没按 UG1214 先关 HP 口 ~15% / H4 引擎 RTL 偶发 ~15% / H1 刷写竞争 ≤10%(只可能解释 seq 37)。
  - 注意: pov_rxd 报"CPU 能解同一帧 ⇒ PL 引擎有问题"这句推断不严谨(用的是 CPU 缓存视图), 审查认为结合 32 KB 缓存仍能排除 DDR 永久陈旧。
  - 下一步上板区分实验(按性价比): X0 出错当次(不重启)只读抓引擎寄存器 SRC/LEN/CYCLES/STATUS + 0x80004024/28; X3a **关掉假转(HP0 取片空闲)再跑**; X1 反复推同一帧(要连 meta.json 一起拷, ≥1000 帧/臂); X2 IRQ 安全刷写(预期无变化, 降级)。
  - 候选修复: pov_rxd 出错先原数据重试一次并记录寄存器; RTL 加源 CRC/已读字节计数、RRESP/BRESP 粘滞位、读看门狗、E_SRC(已定义从未赋值)、软复位位; 内核 ccm_dcache_op 加中断保护作加固。
  - 🔴 **另一个独立真 bug**: PL 失效退回 CPU 解码后, 写进 bank 的帧**从不 flush**(flip 线程对 bank≥0 跳过刷写) ⇒ 屏上可能显示部分陈旧行。证据 `dr1v90/measure/03_wifibw/results/2026-09-15/rxd_p2p/FINDINGS.md`、`D0/D0-R0-1.fail.txt`。

## 🎯 2026-09-16 上板区分实验 (DR1V90-2, 办公网 AP, povsh 控制) —— 全文 `dr1v90/measure/03_wifibw/results/2026-09-16/pl_x1/FINDINGS.md`
- ✅ **换板复现**: 原版 3 次跑, 首个故障 seq 1/30/34, 合计 ~7 次/195 PL 帧 ≈ **3.6%/帧**; **全部在流#2(comp 缓冲尾部)**, ARBERR=STALL=0。
- 🎯 **X1 同内容 A/B 定性**: 单帧 frame_0014 反复推 **1480 PL 帧 0 故障**, 36 帧循环几十帧内必挂 ⇒ **PL 读到的是缓冲里上一帧的旧字节**;
  frame_0014 在 09-15 循环里自己挂过 ⇒ 不是"好解的帧", **纯数据触发的 RTL 偶发(H4)基本排除**。
- ✅ **X0 当场抓寄存器**: 卡死时 CYCLES 仍在涨(核在等源字节, 不是丢 B); E_OVERRUN 那次寄存器 == 日志任务 ⇒ **H5 排除**。
- 🔴 **09-15 两条说法作废**: ① "循环复用缓冲时才出事" —— 第一遍 seq 30 就挂; ② PL_RCA 对抗审查"32 KB 缓存早逐出 ⇒ D-cache 类排除" —— 反了:
  **memcpy 187 KB 时前面的行靠逐出写回(可靠), 只剩最后 ~32 KB 靠 IOC_FLUSH 写回 ⇒ 只坏尾部**, 与"只有流#2"、"E_OFF0 距尾 ~35 KB"吻合。
  D-cache 大小是**事实**: OpenSBI 打的 `mdcfg_info=0x2b0615` 按 NMSIS 公式 = 256 组×2 路×64 B = **32 KB**。
  ③ PL_RCA "pov_rxd.c:765 编译不过" 也错: 本机重编**与板上 7eb1ac40 逐字节相同**。
- 🎯 **X2' 用户态变体(刷写后、发车前插一步)**: 再刷一次 **0.2%** / 强制逐出 256 KB **0.4%** (≈降 10×) / 等 50 ms 1.3% / 写 FPIPE(0x4CF, 用户态可写不陷入) ~8% / 发送窗口 1 仍 seq 40 挂
  ⇒ **发车时尾部确有脏行没写回, IOC_FLUSH 漏行**; 头号嫌疑仍是 H1(内核 ccm_dcache_op 回写循环不关中断, 被别处 DMA 同步改了 0x5cb);
  两种补救都不到 0 ⇒ 真正的判决+修复要在内核侧做 **关中断的 CCM 回写循环(+FPIPE)**, 有卡死单核风险, 要串口原始抓取 + 用户能到场断电。
- 🔴 **量具坑(差点下错结论)**: 往**只写不读的 static 数组**写数据做"逐出", `gcc -O2` **整段删掉**(二进制里没有该符号) ⇒ 第一次模式 2 其实是原版;
  必须 `volatile` 并在 objdump 里看到 `sb` 循环。**任何"写了但没人读"的实验性副作用都要先查反汇编。**
- 台架坑: 变体二进制换名(`pov_rxd_x`)会让 `rxd_board.sh` 的 `pidof pov_rxd` 判启动失败而进程已在后台监听 ⇒ 变体放 `/tmp/xbin/pov_rxd` 保持进程名。

## ✅ 2026-09-17 根因坐实: 内核 CCM 回写循环不关中断 (H1) —— povmem 关中断分段回写即修好
- 实验模块(补丁 `results/2026-09-16/pl_x1/scripts/povmem_kx_irqsafe_flush.patch`, vermagic 与卡上一致): 运行时参数 `flushmode`
  0=原内核 `ccm_dcache_op`(0x5cb 写一次 + 每行 0x5cc, **开着中断**) / 1=每 ≤64 行一段 `local_irq_save` 并重写 0x5cb / 2=1+FPIPE。
- **flushmode=1: 36 帧循环 1660 PL 帧 0 故障**(原版 pov_rxd); **同一次开机运行时切回 0: 220 帧 3 故障(首个 seq 28, 全在流#2)** ⇒ H1 坐实, FPIPE 不是必要条件。
- flushbench: 刷 187 KB 模式 0/1/2 = 0.106/0.121/0.124 ms ⇒ 关中断零代价; 整个回写窗口只有 ~0.1 ms, 3.6%/帧说明 USB 收包中断极密。
- 机理: 同核软中断里 USB RX `sync_for_cpu`(WBINVAL) 也调 `ccm_dcache_op`, 改写 0x5cb ⇒ 我们剩下的行不回写; memcpy 已逐出前面 ⇒ 只坏最后 ~32 KB ⇒ 永远是流#2。
- 🔴 **推论(未测)**: 同一个不关中断的循环服务**所有**非一致性 DMA(SD/MMC、USB、网口) ⇒ 进程上下文的回写被软中断打断时, 别的驱动缓冲也可能静默旧数据(如 SD 卡写入);
  根治在内核 `arch/riscv/mm/dma-noncoherent.c` 的 `ccm_dcache_op()` 加关中断(要重编内核), povmem 局部修只保护帧区/comp 缓冲。
- 台架坑: K1-1 板子重启后连到 **2.4 GHz** ⇒ 收帧体 0.5-0.9 s, 0.88 fps, 差点当成模块副作用; 用 `wifi5g.sh`(运行时 freq_list 限 5 GHz, 40 s 连不上自动回退) 拉回 5745。
  办公网白天拥挤, 5 GHz 下也只有 3-5 fps(昨晚 22 点 11 fps) —— **吞吐数据要注明时段**。
- 还没做: povmem 正式版默认关中断回写并进卡/MANIFEST; 内核根治; CPU 回退帧不 flush 的独立 bug; RTL 软复位/E_SRC 加固。

相关: [[project_dr1_hp1_lz4_verified]] [[reference_dr1_cache_and_frame_memory]] [[project_lz4_pl_decoder]] [[project_dr1_parity_plan]] [[reference_wsl_p2p_wifi_rig]]
