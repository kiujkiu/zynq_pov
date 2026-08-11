---
name: project_dr1_soc_step1_done
description: DR1 PS↔PL 双向打通 + pov_dual_top 双引擎在板上跑通(寄存器级); GP0 窗口实测 0x8000_0000, HP0 写 DDR 返回 OKAY; 只差把排线从 Zynq 挪过来
metadata:
  type: project
---

# Step 1/2 完成: PS↔PL 打通 + POV 引擎在 DR1 上跑起来 (2026-08-07)

## 结果 (板上实测)

| 寄存器 | 读回 | 证明了什么 |
|---|---|---|
| `0x8000_0000` MAGIC | `0x44523156` | **PS→PL 读通**, 且 PL slave 窗口就在 `0x8000_0000` |
| `0x8000_000C` BUILD | `0x00020000` | 加载的确实是这一版 bit |
| `0x8000_0004` SCRATCH | 写 `0xA5A5F00D` → 读回一致 | **写通路也通** |
| `0x8000_0008` TICK | Δ=112,265,177 / ≈4.5 s | **PL 时钟 ≈25 MHz**(板载 L18), 与预期吻合 |
| `0x8000_0010` PLLTICK | `0x00010C2C → 0x0001E73A` | bit16=1 ⇒ **`p2f_rst0_n` 已释放**; 低 16 位在变 ⇒ **p2f_clk0 活着** |
| `0x8000_0014` HPBEAT | `0x2531` | 与 DDR 里的信标计数一致 |
| `0x8000_0018` HPSTAT | `0x00000004` | 收到 B 响应且 **BRESP=OKAY** |
| DDR `0x1000_0000` | `0x44523156`, 计数持续递增 | **PL→PS 写通** (HP0) |

⇒ **GP0(PS 读写 PL 寄存器) 与 HP0(PL 写 DDR) 两个方向都成立。**

## 关键做法

**1. 直接在 Verilog 里例化 PS, 不走 TD 块设计。**
厂商 demo 生成的 `system_RISC_V_Processor_System_0.v` 就是**普通 Verilog 模块**
(76 个端口)。从 `_demo2/07_pl_fdma_cs500/soc_prj/uisrc/01_rtl/system/ip/` 拷两个 `.v`
直接例化即可 ⇒ **全命令行**, 不依赖 GUI / `system.xml` / `Design.xml`。

**2. 先用 HP0 方向验证, 再碰 GP0。**
见 [[feedback_dr1_pl_probe_must_be_hang_proof]]: GP0 方向 CPU 必须等从机, 挂了就整板失联;
HP0 方向 PL 主动发起, CPU 不参与, **不可能挂死**。
所以 Step 1 的第一个判据是 `hp0_beacon` 往 `linux,dma` 保留区(`0x1000_0000`, no-map)
写信标, 然后从 Linux 读普通内存 —— 零风险。**先把地址清零再看图案出现**, 免得被残留骗。

**3. PL 侧总线逻辑跑板载 25 MHz, 不跑 p2f_clk0。**
理由同上。现在已经证明 p2f_clk0 活着且复位已释放, Step 2 起可以切到它(生产要 50 MHz)。

## 顺序上的一个坑

🔴 **使能 PS↔PL 的三个寄存器必须写在加载 bitstream 之前。**
反过来的话, PL 一配置完就开始往 HP0 打 AWVALID, 而 HP0 那时还在复位里 ——
互联卡住之后**连 CPU 读 PS 自己的寄存器都会停住**(实测卡在 `devmem 0xF8800080`)。
`tools/deploy_pl.sh` 已按正确顺序固化。

## 工具

- **`tools/deploy_pl.sh <x.bit.bin>`** —— 送 dtbo + 送 bitstream + 使能 + 加载, 一条命令。
  全走串口: bitstream 压缩后仅约 **37 KB**(78 倍, 里面大多是零), 几十秒就到。
  比"重启后先花几分钟重装 WiFi 再 wget"快得多, 也少一层会坏的东西。
- **`tools/serial_run.sh <cmds.txt>`** —— 跑板端命令并**先 taskkill 残留 powershell**。
  🔴 PowerShell 脚本被 timeout 杀掉时**进程不退出**, 还攥着 COM5;
  下一次调用会静默地一个字节都读不到, 表现得像"板子挂了"而实际板子好好的。
  **这个坑踩了三次。**
- 每次重启都要重做: WiFi(在 initrd 里)、`/tmp/pl_load.dtbo`、`/lib/firmware/pl.bin`、
  三个使能寄存器。`board/cmds_restore_wifi.txt` + `deploy_pl.sh` 覆盖了全部。

## Step 2 也过了 (寄存器级, 2026-08-07)

`pov_dual_top` + 双 `panel_engine_2047` 在 DR1 上跑起来了。综合:
`#eram 18/280` (9 lane × 2 引擎全部落块 RAM) / `#slice 1469` (2.80%) /
**`#pad reg 24`** (24 个 ODDR 全在 IOL) / `#soc 1/1` /
SWNS **+29.04 ns @40 ns** (等效可跑 91 MHz)。

板上 (GP0 @ `0x8000_0000`):
- STATUS 复位 `0x00000008` ⇒ **bit3 oe_A=1 = 消隐**, 复位即黑屏
- 写 POV_CTRL `0x01680007` → 影子 `0x24` 读回**逐位一致** (360 片 + pov_en/fake_en/dual_en)
- **slice_idx 递增** `0x4C→0x50→0x54`, bit31 **locked=1**
- STATUS `0x00000F08` = bit3/8/9/10/11 (oe_A+locked+pov_en+fetch busy+dual_en) 逐位符合
- `0x18` = `0x80000167` ⇒ slice_max **359 = 360-1**

### 生产配置 (aclk = p2f_clk0 = 50 MHz) 也过了

综合: SWNS **+7.881 ns @20 ns** (关键路径 12.12 ns ⇒ Fmax ≈ 82.5 MHz, 余量 39%) /
HWNS +0.036 ns / Domain Luts `aclk | 50MHz | 1881 LUT | 18 BRAM`。

板上: `povctl fake 15 360 50000000` ⇒ slice_idx 每 100 ms **+181**
(理论 15 rev/s × 360 片 = 5400 片/s, 100 ms 走 540, mod 360 = **180**; 多的 1 是 printf 开销)。
⇒ **这同时独立证明了 p2f_clk0 就是 50 MHz** —— 按 50 MHz 算的 fake_period 得到了
精确的预期速率, 若实际是 25 MHz 速率会正好减半。

### 🔴 `fake_period` 的单位是**每 slice 的 aclk 数**, 不是每圈

`angle_tracker.v:11` 写着 `fake 模式: 每 slice aclk 数`。我按"每圈"算过一次,
结果实测 15 **片**/秒而不是 15 **圈**/秒 —— 正好差 n_slices=360 倍。
`povctl fake <rev/s> [nslices] [aclk_hz]` 已经把换算包进去了, 别再手算。

⏸ **只差把 50 针排线从 Zynq 板挪到 DR1 板** —— 这是整个移植里唯一需要动手的一步。

## Step 3 (DDR 取片) 也过了 —— 不接屏验的

`pov_dual_top.m_axi` (AXI4, 32位, arlen 8位) → `rtl/axi4_to_axi3_hp.v`
→ HP0 (AXI3, **64位**, arlen 4位)。桥顺手按 64 位取数、每拍拆两个 32 位还给上游,
AXI 拍数减半。桥先在 `dr1hw_sim/` 过了 **11 档回归**(反压/下游延迟/错误注入/
定向 corner 向量/端到端), 见 [[feedback_always_ready_tb_hides_handshake_bugs]]。

板上实测: **`FETCH_ERR = 0 / 148,561 字`**、25.5 片/秒(与 fake 40ms/片精确吻合)、
`misalign_err = 0`。判据怎么设计的、以及为什么前三版判据都错,
见 [[feedback_verdict_design_before_blaming_dut]]。

🔴 **`MAX_OUTST = 2` 不是可选项**: 单笔在途时 AR 往返延迟完整暴露在数据流里,
HP0 首拍延迟 25 周期就只剩 106 MB/s < 双屏需求 109.2 MB/s。2 笔在途 170 MB/s。
(Zynq 的 `ddr_slice_fetch256` 也是 outstanding=1, 设计文档那个"1.7× 余量"
 是理论 beat 效率、**没有实测**, 也没把 AR 往返算进去。)

## Step 4 (转角追踪) 随 Step 2 一起过

`angle_tracker.v` 与 Zynq 版 md5 相同。假转 15 rev/s 实测 +181 片/100ms,
`locked=1`。真传感器要等排线接过来。

## 每次重启都要重做的事 (rootfs 是 initrd)

### ⚠ 2026-08-10 重写: 旧的 `cmds_restore_all.txt` 跑完系统其实起不来

审计发现三个静默失败: `.ko` **只 cp 从不 insmod**(⇒ `/dev/povmem` 不存在, pov_rxd 起不来)、
`pov_rxd` **只 cp 从不启动**、五条 `cp` 只有一个 `echo "rc=$?"` 而
`serial_cmd.ps1:58` 是**一行一行发**的 ⇒ `$?` 只反映最后那条, 前四条失败全静默。
另外 `dtb_cma96.bin` 被引用但**没有任何脚本把它传到卡上**。

🔴 **结构性原因**: `cmds_*.txt` 由 `serial_cmd.ps1` 逐行发送 ⇒ **没有 `if`、没有循环、
没有提前中止**。"每步有判据"这件事在这个载体上不可能实现, 必须换载体。

✅ 现在: **`board/povboot.sh`**(busybox ash, 住在卡上 `/mnt/mmcblk0p1/pov/`,
用 `sh <path> <stage>` 调用 —— 卡是 FAT 没有 exec 位)。一条命令走完
卡 → 文件 → configfs → **三个使能(读回, 不成立就拒绝加载 bitstream)** → bitstream →
寄存器探针 → povmem → 引擎+假转 → WiFi → pov_rxd, 结尾 `POVBOOT: PASS/FAIL (n)`。
分段: `pl` / `sw` / `engine` / `wifi` / `run` / `check`(只读)。
`cmds_restore_all.txt` 等变成薄壳, 只负责挂卡 + 调它。

🔴 **`devmem 0x80000000 == 0x44523156` 这条判据对 `pov.bit` 永远不成立** ——
MAGIC 属于 Step 1 的探针设计(`td_soc1/.../axi3_probe_regs.v:15`),
`td_pov/` 下 grep MAGIC **零命中**; 那里 `0x00` 是 STATUS(`pov_dual_top.v:418` default 分支),
复位读 `0x00000008`(bit3 = oe_a_state = 消隐)。
✅ 换成: STATUS 解码合理 + **往 `0x10` 写两个不同值、读 `0x24` 影子逐位一致**
(位序与写口逐位对齐, `:412` vs `:294`; 两个值都保持 pov_en/fake_en 清零,
免得在 `fake_period` 还是复位值时启动取片)。warm reboot **不清 PL**, 所以必须"写进去再读回来"。

**STATUS 位序**(`pov_dual_top.v:417-422` 数出来, 三条线交叉验证过):
`[16]`base_b_act `[15]`fold_a_en `[14]`mirror_a `[13]`mirror_b `[12]`eng_b_busy
`[11]`dual_en `[10]`pair_busy|df_busy `[9]`pov_en `[8]`at_locked **`[7]`dclk_fast**
`[6]`overlap_en `[5]`use_fb `[4]`auto_en `[3]`oe_a_state `[0]`eng_a_busy。

⚠ **`povboot.sh` 里没有一条判据上板验过。** 第一次跑要盯**假 FAIL** ——
见 [[feedback_verdict_design_before_blaming_dut]], 先怀疑判据别先怀疑板子。

### 🔴 三条写出来又删掉的坏判据 (都会在健康板子上 FAIL)

- **用 `0x18` 反推 `n_slices`**: `slice_max` 是 slice_idx 的**历史最大值只增不减**
  (`pov_dual_top.v:454`)。"写 180 期待 179"会在一块只是转过 179 的正常板子上 FAIL。
- **隔 200 ms 读两次 `slice_idx` 期待不同**: 15 rev/s × 360 片下 200 ms 正好 1080 片
  ≡ 0 (mod 360) ⇒ **健康板子有权给出两个相同的值**。改成 5 个不均匀采样、≥2 个不同。
- **STATUS bit10 (fetch busy) 必须为 1**: 15 rev/s 下一片 185 µs 而取一片只要几十 µs
  ⇒ **单次 devmem 大概率落在空档, 读到 0 是合法的**。改成 FETCH_CNT 两次采样比大小(单调)。

### 真持久化 (评估完, 未动手, 等批)

**推荐 A-lite**: 只往 `rootfs.bin` 加 `/etc/init.d/S95pov` + 一份 `povboot.sh`(约 10 KB),
churny 的东西继续留卡上。卡上 `S10mdev`+`automount.sh` 已经自动挂 `/mnt/mmcblk0p1`,
`inittab` 也 `remount,rw /` ⇒ **差的只是"开机有东西去跑 povboot.sh"**。
**不推荐 A-full**(把 WiFi 栈烤进 initrd): +19 MB 几乎全是 `mac80211.ko`(6.5 MB)+
`cfg80211.ko`(4.2 MB), 已核实**没有 `.debug_*` 段, strip 省不下来**;
运行时 RAM 占用两种方案一样, 等于拿一个**没验过的 u-boot 29 MB ramdisk 重定位风险**换零收益。
overlayfs **不可行**(upperdir 不能放 vfat)。

🔴 **落地前必修的雷**: `tools/mkrootfs.sh:44` 默认基底是 `tfboot/uInitrd.lz4`
(md5 `ca0b0467…`, 5,422,770 B, 带 strace), 而 `:36-43` 注释斩钉截铁说"这就是卡上那份"。
**不是。** 卡上跑的是 `boot/rootfs_card_orig.bin`(md5 `0e685550…`, 4,984,832 B, 无 strace),
cpio 清单逐条比对确认。**下一个人重跑就会静默换掉整个 userland。**
建议: 默认值改对 + 硬断言 md5; `S95pov` 加**开关文件闸门**(只有
`/mnt/mmcblk0p1/pov/AUTOBOOT` 存在才执行) —— 万一自动跑 PL 把板子搞挂,
插读卡器删一个文件就能停, 不用重烧 rootfs。

## 板端工具 povctl

`host/povctl.c` → musl 静态链。`regs`(解码 STATUS 各位) / `rd` / `wr` /
`fb <pattern> [face]`(直灌图案) / `fake <rev/s>` / `idx <n>`。
为什么要它: fb 直写一屏 = 9 lane × 54 行 × 6 字 = **2916 次 32 位写**,
用 devmem 走串口逐条发要几十分钟, mmap 一次几毫秒。

相关：[[reference_dr1_ps_pl_enable]] [[feedback_dr1_pl_probe_must_be_hang_proof]] [[project_dr1_parity_plan]]
