# eta_test — DDR 读效率 η 实测 (鹿小班 XC7Z020, 2026-09-03)

**要回答的一个数**: DDR 对「每片 192 列 × 54 拍 × 8 B 散布突发读, 两路并发」的读效率 η。
判据 (2026-09-02 定): 两个渲染实例**同时**跑, 每片 ≤ 110.6 µs; η ≥ 0.70 (裸) / ≥ 0.84 (留 20%)。
η = (两路 slices/s 之和 × 82,944 B) / 2.1333 GB/s (DDR3-1066 × 16 bit, 板子实际峰值)。

## 0. 设计决定 (与昨天判据不同的三处, 每处都是为了让量具量得到要量的东西)

| # | 昨天写的 | 这里做的 | 为什么 |
|---|---|---|---|
| 1 | "跑现有 pov_slice_v2 两实例" | **主量具 `pov_eta_rd`: 只读变体** (`hls/pov_eta_rd.cpp`), 读回 64 位字 XOR 后经寄存器交回 | 现有 IP 每片**读 82,944 B 又写 82,944 B**; 两路并发 × 110.6 µs = 3.0 GB/s > 峰值 2.133 ⇒ η=1 也过不了。「切片不落 DDR」拓扑里 DDR 上**只有读流**, 量具必须只读。现有 IP 原样版保留为 `pov_eta_wr` (第二组对照, 昨天判据的字面版本) |
| 2 | 条件 C2 "IP 每列只提前 8 拍发请求, 空载即擦线" | `pov_eta_rd` 用 `hls::burst_maxi` **提前 pf_cols 列发请求** (运行期寄存器 0..6; 0 = 复现现有 IP 的"发完就等") | 请求方喂不饱口, 量出来的是 IP 延迟不是 DDR η。pf 可调 ⇒ 一次上板同时拿到 C2 的答案 |
| 3 | (未定) 软件走裸机 Vitis 还是 Linux | **都不走**: `return` 改 `ap_ctrl_hs`, ap_start/ap_done/ap_idle 变引脚, PL 侧 `rtl/eta_mon.v` 同一拍拉起两路、逐拍计数; 主机只用 **xsdb** 写 10 个寄存器 + 读计数器, ARM 全程 halt | 鹿小班现在没 Linux 镜像在用; 裸机要为新 XSA 重建 Vitis 平台 (5 min + java 锁坑), 且 ARM 计时精度差、两次 AXI-Lite 写之间有 ~100 ns 错位。PL 计数器精度 = 1 拍 (6.67 ns) 且"两路同时"由硬件保证 |

地址算法**逐字来自** `hls_proj/pov_slice_v2.cpp` (u→rx,rz→clamp→src); `hls/pov_eta_rd_tb.cpp` 用原算法对拍, csim **6/6 PASS**【实测 2026-09-03】。
`hls/pov_eta_wr.cpp` 由 `tools/derive_eta_wr.py` 从 `pov_slice_v2.cpp` 机械派生 (只改顶层名 + return 语用), 不会漂移。

**体素内容**: IP **无条件读** (先 clamp 地址再读, `inside` 只屏蔽值, 见 pov_slice_v2.cpp 注释) ⇒ 全零也不会少读一拍;
但仍灌**随机数** (`tools/gen_voxel.py`), 因为 IP 交回的 XOR 必须等于主机按同一地址算法算出的值 —— 这是「读的正是那些地址」的证明。

## 1. 从零到 η 的命令序列 (全部在 WSL 敲, 调 Windows 工具)

```bash
cd /mnt/d/claude_workspace/pov3d/zynq_pov/eta_test
```

| 步 | 命令 | 耗时 | 怎么知道成了 (脚本自己检查, 不满足就 exit 1) | 状态 |
|---|---|---|---|---|
| 1 HLS | `tools/eta_all.sh hls` | **1.5 min** | 日志 `hls/_hls_run.log` 末尾 `ETA_HLS_OK rd` / `ETA_HLS_OK wr`。脚本自查: csim `TB_PASS 6/6`; 流水 `II=1`; 导出 RTL 有 `ap_start/ap_done/ap_idle/ap_ready` 四个引脚; 驱动头**没有** `AP_CTRL` 寄存器 (证明 return 真变成引脚了) | ✅ 已跑通 |
| 2 bit (rd) | `tools/eta_all.sh build rd` | **4 min** | `_full_rd.out` 有 `DDR_INIT_MATCH` **和** `BUILD_ETA_OK ... WNS=+x WHS=+y`。脚本自查: PS7 每个关键 CONFIG **写后读回**; ip 的 6 个 ap 引脚都在; 地址段 offset 读回 = 0x43C0_0000/0x43C1_0000/0x4120_0000; **生成的 ps7_init.tcl 的 DDR 块 (3 个硅版本) + DDRIOB 行与 `02_hello_zynq` 那份逐行相同** | ✅ WNS +0.77 / WHS +0.06 |
| 3 bit (wr) | `tools/eta_all.sh build wr` | 4 min | 同上 | ✅ WNS +0.60 / WHS +0.04 |
| 4 体素 | `tools/eta_all.sh voxel` | 5 s | `build_common/voxel_expect.tcl` 有 `EXPECT(xor,0,1)` 等 4 个 XOR 期望值; 脚本 assert 角 0 的片是连续 82,944 B | ✅ |
| 5 干跑 | `tools/eta_all.sh dry rd` | 2 min | **不接板**: `tools/_mock_xsdb.tcl` 用行为模型顶替 xsdb 命令, 走完 run_eta.tcl 全部逻辑, 末尾 `RESULT:`。只证明脚本本身没 bug, 不是测量 | ✅ rd/wr 都到 RESULT |
| 6 上板 | `tools/eta_all.sh run rd 6` | **3–4 min** | 见下节。末尾 `RESULT: GO/NO-GO`, 全文存 `build_eta_rd/eta_result_<时间>.txt` | ⏳ 需要板子 |
| 7 对照 | `tools/eta_all.sh run wr 6` | 3–4 min | 同上 (读+写版) | ⏳ |

单步等价命令 (不想用 eta_all.sh 时):
```bash
# 1
cd hls && cmd.exe /c "set ETA_VARIANT=all&& set ETA_CSIM=1&& C:\Xilinx\Vitis_HLS\2024.2\bin\vitis_hls.bat -f run_eta_hls.tcl -nolog" 2>&1 | tee _hls_run.log; cd ..
# 2/3
cmd.exe /c "cd /d D:\claude_workspace\pov3d\zynq_pov\eta_test && call C:\Xilinx\Vivado\2024.2\settings64.bat && vivado -mode batch -nojournal -log build_eta_rd.log -source tools\build_eta.tcl -tclargs rd" 2>&1 | tee _full_rd.out
# 4
python3 tools/gen_voxel.py
# 6
cmd.exe /c "cd /d D:\claude_workspace\pov3d\zynq_pov\eta_test && D:\Vitis\2024.2\bin\xsdb.bat tools\run_eta.tcl rd 6" 2>&1 | tee run_eta_rd.log
```
🔴 `vitis_hls.bat` 从 WSL 调**必须加 `-nolog`**, 否则它把 stdout 灌进 hls_tee, 非控制台时 puts 全部消失【实测 2026-09-03, 第一次跑就栽在这】。
🔴 `-tclargs` 只能给关键字 (cmd.exe 把 `=` 和空格都当分隔符, 与 build_bit_dbg.tcl 同一个坑)。

## 2. 上板前提

- 鹿小班上电, **Digilent JTAG** 接主机; **FS03 的 JTAG 拔掉** (两块都是 xc7z020, 记忆里差点烧错板; run_eta.tcl 数到 ≠1 个 xc7z 直接拒跑)。
- 没有别的 Vivado Hardware Manager / xsdb 占着 hw_server。
- boot mode 拨码 SW3 无所谓 (bit/DDR init 全走 JTAG), 但建议非 QSPI 档, 免得 flash 里旧 FSBL 在 `rst -system` 后抢着初始化。
- 不需要串口, 不需要 SD 卡, 不需要 Vitis。

## 3. run_eta.tcl 做什么 / 每步的证据

| 步 | 动作 | 证据 (不满足 ⇒ `ETA_ABORT: ...`) |
|---|---|---|
| 1 | `connect; targets` | 恰好 1 个 xc7z |
| 2 | `rst -system; fpga -file eta_rd.bit; ps7_init; ps7_post_config` (顺序照抄 `tools/dl_pl_only.tcl`) | ps7_init.tcl 是 build 产物, DDR 块已与 hello_zynq 逐行核对 (`ETA(ddr_init_match)=1`, 否则拒跑) |
| 3 | 量具自检 | GPIO→eta_mon: sel=6 读回 MAGIC `0xE7A00001`; sel=7 回显写入值; 活计数器两次读**不同**; 两 IP `idle=1`; **f_clk 用主机时钟标定 4 s**: 与 150 MHz 差 >2% 拒跑 |
| 4 | DDR | 三处写/读回; `dow -data voxel.bin 0x10000000` (16 MB, JTAG 约 20–40 s); 读回文件头 4 字 + 片 0 起点 4 字 (0x10798000) 与文件比对 |
| 5 | IP 寄存器 | 每个写入都读回 |
| 6 | 矩阵 (下表) | 每行: 清零 → **一次写同时拉起两路 ap_start** → 0.5 s 稳定 → 快照 A → 窗口 6 s → 快照 B → 撤 start → 等 idle → (rd) XOR 与主机期望比 / (wr) slot 内容与体素比 |
| 7 | 判决 | DUAL 行: 两路 µs/片 ≤ 110.6 且 both-busy ≥ 98% ⇒ GO; ≤ 92.2 ⇒ GO 含 20% 余量 |

每片时间取**硬件精确值**: eta_mon 累加 ap_done→ap_done 的周期 (`per/pcnt`), 只算完整 run, 无窗口边缘误差; 同时打印墙钟值作交叉核对 (差 >5% 会警告)。

**矩阵** (rd 变体; wr 变体没有 pf 行):

| 行 | ip0 | ip1 | 目的 |
|---|---|---|---|
| CAL_SEQ | phase 0, n=1, pf 2 | — | 角 0 = **整片连续 82,944 B** ⇒ 单口顺序读参照 (csynth 下界 69.1 µs) |
| CAL_STRIDE | phase 151, n=1, pf 2 | — | 90.15° = 列间跨 82,944 B ⇒ 最散的模式 |
| CAL_PF0 | phase 0, n=1, **pf 0** | — | 复现现有 IP"发完就等"行为 ⇒ C2 的代价 |
| SINGLE | phase 0, n=603, pf 2 | — | 单路整圈 |
| **DUAL** | phase 0, n=603, pf 2 | phase 151, n=603, pf 2 | **决定 GO/no-go 的那一行** (两面正交) |
| DUAL_SAMEPH | 同上 | phase 0 | 两路同模式 (行缓冲命中更多?) |
| DUAL_PF0/4/6 | pf 0/4/6 | 同 | 预取深度对 η 的影响 ⇒ C2 该提前几列 |
| DUAL_FACEB | 同 DUAL | axis_off 4391, mirror 1 | 面 B 真实几何 (部分列 clamp 到列 0) |

## 4. 怎么读结果

- `DUAL: eta ≥ 0.84 且 worst ≤ 92.2 µs` ⇒ **GO 含余量**; `0.70–0.84 / ≤ 110.6` ⇒ 裸 GO, 要上 V1/V2/V3 之一补余量。
- `DUAL 不过, 但 SINGLE 也 > 110`: 瓶颈在**单路 IP→HP 通路**不在 DDR (看 CAL_PF0 vs CAL_SEQ: 若 pf 无影响, 是 HP 口/SmartConnect 拆 54 拍→16 拍 AXI3 的 outstanding 上限, 试 AFI 发射能力寄存器 `0xF8008000+` 或降到 100 MHz 换 128 位)。
- `DUAL 不过, SINGLE 过, DUAL_SAMEPH 明显好于 DUAL`: DDR bank 冲突/行缓冲, 是真 η 问题 ⇒ V1 (共面穿心) / V2 (列复用) / V3 (8-bit 调色板)。
- `wr 变体 DUAL 过`: 更强的 GO (连写流一起都撑住)。`wr 不过 rd 过`: 差的是写流, 与直供拓扑无关。
- `CAL_PF0 ≫ CAL_SEQ`: 证实 C2 (现有 IP 必须改预取), 差值 = 每列一次 DDR 延迟 × 192。

## 5. 最可能卡的地方与备选

| 风险 | 现象 | 备选 |
|---|---|---|
| hw_server 被占 / JTAG 掉 | `connect` 报错或 targets 空 | 关掉所有 Vivado HW / xsdb; 物理拔插 USB (记忆 reference_hardware) |
| DDR init 失败 | `dow` 或读回错; xsdb `Memory write error at 0x1000xxxx` | DDR 块已与跑通过的 hello_zynq 相同, 先 power-cycle; 再看 `ps7_init.tcl` 里 `ps_version` 选的硅版本 |
| IP 不跑 (`runs=0`) | ETA_ABORT ip0 completed 0 runs | HP 未使能/地址窗错 —— build 时已读回; 看 sel=9 状态字 (idle/ready); 用 `mrd 0x43C00000 0x20` 看寄存器 |
| 150 MHz 时序 | 已收敛 (+0.77 ns); 若改 IP 后失败 | `-tclargs rd f100` |
| 器件速度等级 | 02_hello_zynq 用 -2 (记忆说板子是 -2), icnd2260 用 -1 | 本工程 -2; 保守可把 build_eta.tcl 的 `PART` 改 -1 重跑 (4 min) |
| XOR 不匹配 | ETA_ABORT XOR readback | 读的地址集合不对 (体素基址/寄存器) —— 不要看性能数, 先修 |
| 并行 agent 也在建 `ddr_eta/` | `zynq_pov/ddr_eta/hls/pov_slice_v2_rd.cpp` (同思路的只读变体, 但 return 仍走 s_axilite, 无预取) | 两套独立, 本目录自洽; 合并时以能 PL 计时的这套为准 |

## 6. 文件

```
eta_test/
  hls/pov_eta_rd.cpp        主量具 (只读 + burst_maxi 预取 + ap_ctrl_hs)        hls/pov_eta_rd_tb.cpp  csim 对拍
  hls/pov_eta_wr.cpp        现有 IP 原样 + ap_ctrl_hs (由 tools/derive_eta_wr.py 派生)
  hls/run_eta_hls.tcl       csynth + export + 自检
  rtl/eta_mon.v             PL 量具 (start 扇出 / cyc / done / busy / both / 周期累加 / 快照 / MAGIC)   tb/eta_mon_tb.v (iverilog PASS)
  tools/build_eta.tcl       Vivado: PS7(LXB) + 2×IP + SmartConnect×(3|5) + GPIO + eta_mon → bit + ps7_init + eta_regs
  tools/gen_voxel.py        随机体素 + 期望 XOR / 期望字
  tools/run_eta.tcl         xsdb: 烧 + 初始化 + 自检 + 矩阵 + 判决
  tools/_mock_xsdb.tcl      不接板的干跑
  tools/eta_all.sh          串起来, 每级有闸
  build_eta_rd/  eta_rd.bit ps7_init.tcl eta_regs.tcl *.rpt eta_result_*.txt      build_eta_wr/ 同
  build_common/  voxel.bin voxel_expect.tcl
```
BD 拓扑: `ip0/m_axi_vox → sc_rd0 → S_AXI_HP0`, `ip1/m_axi_vox → sc_rd1 → S_AXI_HP2` (HP0/1 与 HP2/3 各共享一个 DDRC 口, UG585 ch.10 ⇒ 两条读流落在**不同 DDRC 口**); wr 变体写流走 HP1/HP3。GP0 → sc_gp0 → ip0/ip1 控制 + GPIO。全部 FCLK0 = 150 MHz。无 PL 引脚, 无 XDC。
资源: rd 版 LUT 8.1% / BRAM 2.9% / DSP 8.2%; wr 版 LUT 15.1% / BRAM 5.7%。
