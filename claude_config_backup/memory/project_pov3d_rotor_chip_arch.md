---
name: pov3d-200-200-8-bit-cascade-io
description: "Zynq(基座)→滑环→转子芯片(CPLD/ECP5)→panel 三段架构, 各色深档选型, 以及用户验证过的 32扫×16长度拆cascade IO 计算 + 5 个公式漏项"
metadata: 
  node_type: memory
  type: project
  created_at: 2026-06-16
  updated_at: 2026-06-16 (+ICND2047 twOE=40ns 真瓶颈)
  originSessionId: 8499b7fd-f014-43d7-a23c-f4f4b77598b8
---

# 三段架构 (滑环约束下的必然形态)

最终量产: Zynq 在基座, panel 在转子. **滑环只能过几根差分线 + 电源, 过不了 56~224 根并行 HUB75 信号** → 必须在转子上加一颗芯片把高速串行流还原成 panel 并行信号.

```
基座 Zynq 7020          滑环(几根差分)        转子芯片              panel
渲染/预烤volume/DMA  ──段A LVDS/SERDES──▶  解串+扇出(+可选BCM/缓存) ──段B 多lane──▶ LED
```
- 若 Zynq 跟着转 → 不需要转子芯片, 直接 IO 接 panel (现桌面调试形态). 转子芯片只为「Zynq 在基座」而存在.
- DCLK 在**转子本地 PLL 重生成**, 段A 只传数据+帧同步, 不跨滑环传 DCLK (避 SI).

# 转子芯片选型 (按色深分档)

| 色深档 | slice数据(192²) | 转子芯片 | 段A |
|---|---|---|---|
| 8色(1-bit) | 110 kbit | **CPLD MachXO3L-6900 够**(哑透传,无缓存) | 4×LVDS @375M=1.2G |
| 3-4 bit | ~0.5 Mbit | **LFE5U-45**(1.9Mbit EBR) 必需 | LVDS |
| **8-bit** | 884 kbit/slice | **LFE5UM-85**(3.7Mbit + SERDES) 必需 | **SERDES** |

关键芯片事实:
- **Zynq 7020 没有任何 MGT/GTP/GTX** (7z015 才有 GTP, 7z030+ 才有 GTX). 7020 出口只能 LVDS+OSERDES, 每对实测 ~0.8-1.0G, 上限 ~1.25G.
- **ECP5 LFE5U = 无 SERDES**; 只有 **LFE5UM / LFE5UM5G 才有 SERDES** (2-4 通道 @3.2/5G). 选 SERDES 别选成 LFE5U.
- LFE5U-85: 84K LUT / 3.7Mbit EBR / 156 DSP / 4 PLL / 无SERDES. -45: 44K/1.9Mbit/72DSP. 大封装 caBGA756 ~365 IO.
- 订货: LFE5U-85F-6BG381C = 家族-密度F-速度(6/7/8)-封装-温度(C/I).
- 实时流架构下转子内部 block RAM 就够, **不需要外部 RAM**; 只有「转子存整圈 volume」才要外接 DDR3 (192²×360×3B ≈ 40MB).

# 用户的拆 cascade 逻辑 (2026-06-16 已验证数学全对)

现状 32扫 × 128长度 × 8-bit(8 plane) BCM, 25M DDR(双边沿=50Mbps):
- 25e6×2/128/32/8 = **1,526 Hz** (级联128长度)
- 拆 cascade 到 16长度(每16ch驱动芯片独立SDI不级联): 25e6×2/16/32/8 = **12,207 Hz**
- 公式 = DCLK_eff / (chain_len × scan × planes)

200×200 为好算调 **192×192** (=16×12 宽 × 32×6 高):
- 192²/16/32 = **72 组** block (每 block = 16列×32扫)
- 每 block 3 片 RGB → **216 SDI**. 带宽自洽: 216×50Mbps = 10.8 Gbps = 884,736bit×12207. ✅

# 公式漏掉的 5 项 (落地必须修正)

1. **216 只是 SDI**, 还要 +DCLK/LAT/OE/ABCDE(5) ≈ +8 → **~224 IO** (broadcast 共用).
2. **12,207 是 shift-bound 零开销值**, 实际 -10~20% (地址切换/LAT/消隐) → **~10,000-11,000 Hz**, 余量薄. 体刷新(360 slice) ~28-30 Hz.
3. 🔴 **LSB 10ns 问题**: 帧81.9µs/32扫=2.56µs/行, 8-bit BCM 塞255单位 → T_unit≈10ns, **最低位只亮10ns**, LED+OE 非线性区, **名义8-bit 实测可能只 5-6 bit**. 这是8-bit高fps的真墙, 非IO问题. 投板前用小板实测最暗几位.
4. **必须 DDR 输入驱动芯片**: FM6124 是 SDR 做不了双边沿, 用 **ICN2053(65M)/ICN2065(100M)**.
5. 🔴 **段A = 10.8 Gbps 连续**: 转子必 LFE5UM-85(SERDES); **7020 源不出**(LVDS上限~8G) → 评估换 **7z015/7z030(带GTX)** 或让转子存整圈 volume(+DDR3).

# 🔴 ICND2047 twOE=40ns 才是真 fps 瓶颈 (2026-06-16, datasheet 确认)

datasheet `docs/chipone/ICND2047_datasheet.pdf` V2.0: **FCLK max 25 MHz (永远 DDR=50Mbps/lane, 不能再快, 这是芯片上限), twOE min 40 ns, twCLK 20ns, setup/hold 5ns**.

**真正卡 fps 的不是移位, 是 OE 最短脉冲 40ns** (把 BCM LSB 钉死在 40ns):
```
display-bound fps = 1e9 / (twOE × scan × (2^N−1)) = 1e9 / (40 × 32 × (2^N−1))
```

16长度 × 32扫 各色深 (取 shift-bound / display-bound 的小值):

| 色深 | shift-bound (50Mbps) | display-bound (40ns OE) | 实际上限 | 体刷新(360) |
|---|---|---|---|---|
| **6-bit** | 16,276 | **12,401** | 理论12,401 / **单缓冲实际~9,500** ✅ | 理论34 / 实际~26 Hz |
| 7-bit | 13,950 | 6,152 | 6,152 | 17 Hz |
| 8-bit | 12,207 | **3,064** | **3,064** ❌ | 8.5 Hz |

**用户之前算的「8-bit=12,207」是移位数, 但 OE 推不出<40ns 脉冲 → 8-bit 显示侧只到 3,064 fps, 那 12,207 在 8-bit 下到不了.**

## ⚠ 2026-06-16 二次修正: 12,401 是理论天花板, ICND2047 单缓冲实际只 ~9,500 (6-bit)

6-bit BCM 每 plane 显示 = 1:2:4:8:16:32 × T_unit(≥40ns OE地板). shift = 16像素 DDR = 8 clk = **320ns/plane**.
- MSB(1280ns) >> shift(320), 轻松藏; **小 plane (LSB 40ns < shift 320ns) 的 shift 藏不住** → 被 shift 卡, 每个实际 ~320ns.
- 每行时间 = max(总shift, 总display) **只在能完美多级 shift-ahead 时成立**: 总shift=6×320=1920ns, 总display=63×40=2520ns → 2520>1920 → 理论 12,401 Hz.
- **ICND2047 是 SR+单latch, 只能提前 1 plane, 藏不住小 plane shift** → 每行 ~3,200-3,500ns → **实际 6-bit ≈ 9,000-9,600 Hz**, 不是 12,401.
- 用户提的「最长 OE=16clk」**错**: MSB 本就 1280ns 够长藏 shift; 压到 16clk 会逼 T_unit<40ns 违 OE 地板. 瓶颈在最短 plane 不在最长.
- 想逼近 12,401: 链长 16→8 (shift 320→160, 小plane也能藏, IO翻倍) / 降色深 / 换内置 GCLK 的 ICN2053/2065 (芯片内部生成灰度, 不用逐 plane shift).

**实际 fps = min(移位上限, 显示上限)** (粗略框架, 精确值见上面单缓冲修正):
- 移位上限 = 50Mbps/(链长L × scan × N) —— **跟链长 L 成反比** (L=128→2,035; L=32→8,138; L=16→16,276)
- 显示上限 = 1e9/(40ns × scan × (2^N−1)) —— 跟链长无关 (6-bit/32扫 = 12,401)
- 临界链长 L* = 50e6/(显示上限×scan×N) ≈ **21** (6-bit/32扫). L≤21 → 显示(OE)卡, 缩短链长无用; L>21 → 移位卡, fps 随链长反比掉.
- ⚠ 拆 cascade 128→16 的意义 = 跨过 L*=21 这条线, 把瓶颈从移位搬到显示, fps 2,035→12,401. 16 是刚好越线又不浪费 IO 的点.

结论:
- **ICND2047 甜区 = 16×32 / 6-bit / 25M DDR → 理论 12,401 fps, ICND2047 单缓冲实际 ~9,500 fps (体 ~26Hz), gamma LUT → 感知 ~8-bit.** 12,401 是显示(OE)理论上限(仅链长≤21 时成立; 链长>21 如128=2,035 被移位卡死); 但单缓冲藏不住小plane shift → 落到 ~9,500 (见上「二次修正」).
- **提移位速度对 fps 无用** (你是 display/OE-bound, 不是 shift-bound). 换 100M 芯片也不提 fps —— OE 40ns 限一样在.
- 更快芯片(ICN2065 100M)的真正价值 = **省 IO**: 移位有富余 → re-cascade 拉长 chain → 216 SDI 可降到 ~72, fps 不变.
- ⚠**(2026-06-29 纠正, 别信这条)** ~~真8bit换GCLK绕开OE~~ — 跟 [[reference_pov_chip_selection]] 结论冲突: **内置GCLK对POV慢**(16-bit PWM=15Hz/ICN2065 16-bit=762fps, 比7K慢10-56×), GCLK芯片是给静态大屏120-240Hz不是POV. 用户确认"GCLK速度更低". **真8-bit高fps在已验证硬件上无解**(BCM撞OE40ns→8bit~3k; GCLK对POV慢). 彩色POV只能 ICND2047 BCM **6-bit~9500fps**. (注: GCLK-慢是拿16-bit算的, 6-8bit没严谨对比, 但既然没坐实就别当捷径).

详见 [[project_pov3d_panel_chip_pivot_2026-06-04]] (ICND2047 永远 DDR / register / LE 命令).

# 带宽优先分析框架 (任何 POV 驱动讨论先算这个)

- 每 slice 数据 = W×H×3×bitdepth
- 段A带宽 = 数据/slice × fps; 段B lane数 = 段A带宽 / (单lane DCLK)
- 8色/10k = 1.2 Gbps (轻松, CPLD级); 8-bit/10k = ~10 Gbps (逼 SERDES+MGT, 最贵档)
- 同一块 48-lane 板换色深: 1-bit→10k fps, 8-bit→只~1,250 fps (差8×). 提色深不加宽数据线(仍1bit/线), 只乘 fps/lane.

相关: [[project_pov3d_48sdi_io_plan]] [[reference_pov_chip_selection]] [[project_pov3d_led_chip_decision]] [[project_pov3d_final_target]]
