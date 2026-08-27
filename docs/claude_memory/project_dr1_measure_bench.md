---
name: project_dr1_measure_bench
description: dr1v90/measure/ 三个测量台(wifibw/pairmiss/hpbw) — 板子一空出来就能跑; 附实测载荷阶梯(2.7-64.1 Mbps, 跨内容差 24 倍)与"先证明量具"的判据设计
metadata:
  type: project
---

# DR1 三个未知数的测量台 (2026-08-26 建, commit `78c81cf`)

`dr1v90/measure/`。三个"决定移植成败、但至今零实测"的数, 做成**板子一空出来就能跑、
跑完就有结论**的套件。每套都写了"实测值 → 影响后面什么"的对照表, 结论能直接改排期。

**执行顺序是依赖关系定的, 不是重要性**:

| 顺序 | 套件 | 量什么 | 板子占用 | 前置 |
|---|---|---|---|---|
| 1 | `03_wifibw/` | DR1 WiFi 真实吞吐 | ~15 min | **不需要任何新 bitstream**, 现役系统就能跑 + 一台**有线**服务端 |
| 2 | `02_pairmiss/` | 共享口下面板取帧丢对率 | ~10 min | 现役 `pov.bit` 即可 |
| 3 | `01_hpbw/` | HP 口实际带宽 + CPU 侧 DDR 带宽 | ~30 min | 要综合一版专用 bit(占 TD, 与 A 线冲突) |

`03_wifibw` 排第一是因为**零成本且可能改写后面两步的目标**。
交叉编译好的 `iperf3` 已入库(riscv64 musl static-pie, 189 KB)。
🔴 `-static` 会被 **libtool 吃掉** —— 给 `configure` 传 `LDFLAGS="-static"` 不够,
产物照样 `dynamically linked`, 见 `build_iperf3.sh`。

## 🔴 载荷不是一个数, 是一条阶梯 —— 而且旧比率是错口径

`measure/tools/measure_payload.py` 拿**真实渲染帧**实测
(3-bit + fold_a 213 片 + lz4-**HC12** + `--stream-split even --stream-workers 3`):

| 内容 | 压缩后/帧 | 压缩比 | @11 fps |
|---|---|---|---|
| colors8 / solidtop | 31 KB | 254× | 2.7 Mbps |
| helix3 / helix2 | 127-132 KB | 59-62× | 11-12 Mbps |
| **rgbhelix**(上电固化的空闲动画) | 142 KB | 55× | **12.5 Mbps** |
| cyl / helix_full | 200-213 KB | 37-39× | 18-19 Mbps |
| bonsai_h | 227 KB | 34× | 20.0 Mbps |
| **cyl2** | **729 KB** | **10.8×** | **64.1 Mbps** ← 实测最重 |

**两条对记忆的纠正**:
- 流传的 **22.8× / 33.7×** 是 **1-bit 720 片 `frames_robot`** 的数。3-bit 把位平面分开后
  重复度高得多, 实测 **34-255×**。**拿旧比例推链路需求会失真。**
- `povstream.py:147` 的默认级别**早就是 HC12** 不是 HC9(且 HC10 实测比 HC9 还差 6.4%)。

⇒ **别拿某一个内容的数当常量, 换模型要重量。** 验收标准里必须写清用哪个内容。

## 🔴 开工前查实的另一条: HP1 在当前 PS IP 里根本没生成

见 [[project_dr1_hp_topology_decision]]。因此 `01_hpbw` 分两阶段:
**阶段 1(现在就能做)** HP0 单口纯读/纯写/读写并发/outstanding 扫描 ——
已足够回答 B 线最关心的"三个引擎的读+写挤一个口够不够";
**阶段 2** 等 PS IP 重生成后测双口并发。

`hpbw cpu` 顺手结掉 08-10 悬着的那个问题: `cpy 160ms` 里 memcpy 占 153ms = 59 MB/s,
是 **DDR 的上限**还是 **musl 通用 C 版 memcpy 的上限**?(`copy64` 比 `memcpy` 快 >1.3× ⇒ 是后者。)

## 判据设计: 三类禁忌与本套件的避法

Step 3 那次连着三次 FAIL 全是判据设计错、被测物一直是好的
([[feedback_verdict_design_before_blaming_dut]])。所以每条判据都自问过
"**健康的板子有没有可能让它 FAIL**":

| 禁忌 | 为什么会咬人 | 做法 |
|---|---|---|
| 用只增不减的历史最大值反推当前值 | `slice_max` 只增不减, "写 180 期待 179"会在只是转过 179 的正常板子上 FAIL | `hpbw` 统计**绑在 run 上升沿清零**, 读本窗口增量 |
| 采样间隔恰好整除周期 | 200ms × 15rev/s × 360 片 ≡ 0 (mod 360) ⇒ 健康板子**有权**给出两个相同的 `slice_idx` | `pmrate` 分母是**墙钟 × 已知片率**, 从不用 `slice_idx` 差(它会 mod n_slices 绕回) |
| 单次采样撞 busy 瞬态 | 一片 185 µs 而取一片只要几十 µs ⇒ 读到 busy=0 是合法的 | 全部用累计计数的单调性/增量, **没有一条读瞬态标志位** |

另外三条通用做法: **停稳复查**(`run=0` → 等 → 读 → 再读确认不变) /
**不做频率假设**(自由跑计数器 + 墙钟实测 aclk, MB/s 由实测频率算 —— aclk 25/50 那桩悬案
被"假设"坑过两次) / **先证明量具**。

🔴 `pmrate selftest` 不能跳: 把 `fake_period` 压到 400 aclk/片注入**必然发生**的丢对,
不涨就说明哨兵/位域解码/寄存器地址三者有一个是坏的 —— 而此后任何 `pair_miss = 0` 都是假的。
见 [[feedback_pair_miss_sentinel_was_broken]]。
DR1 的一个便利: `fpga_manager` 运行时重配就拉 `aresetn` ⇒ **哨兵清零**(Zynq 上这要冷启动),
所以"每次测量前重新基线"在 DR1 上负担得起。

## 载体: 为什么不是 `cmds_*.txt`

`host/serial_cmd.ps1` 是**一行一行**发的(`<line> ; echo __EOC__`) —— 没有 `if`、没有循环、
没有提前中止, 每行不管前一行错得多离谱都照跑。**"每步有判据"在那个载体上物理做不到。**
⇒ 板端全部是 busybox ash 脚本, **纯 ASCII**(串口会 mangle UTF-8,
一个坏字节落在引号里就把 shell 停在 `>` 续行提示符上)。

⚠ **没有一条判据上过板。** 第一次跑要盯**假 FAIL** —— 先怀疑判据, 别先怀疑板子。

相关: [[project_dr1_parity_plan]] [[project_dr1_hp_topology_decision]]
[[reference_dr1_wifi_ceiling_unestablished]] [[feedback_pair_miss_sentinel_was_broken]]
[[feedback_verdict_design_before_blaming_dut]] [[reference_dr1_cache_and_frame_memory]]
