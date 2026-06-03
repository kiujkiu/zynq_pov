---
name: HUB75E 48-SDI 高速 POV 方案 IO 分配 (鹿小班 GPIO1+GPIO2)
description: 拆 daisy chain 让 8 chip per RGB chain 各占独立 SDI, 48 SDI + 8 control 全部分配到 GPIO1/GPIO2 BANK 33/35 实测可行
type: project
originSessionId: cddd55be-5600-43d2-9b26-a291ffc28846
---

## 总体设计

**目标**: 把 128×64 HUB75E 单 panel 上每个 chain 8 颗 cascade chip 拆开, 每颗芯片有独立 SDI 接 Zynq IO. shift_time 从 128 DCLK 减到 **16 DCLK** (8×), 帧率突破 1440 fps 上限, 推到 ~10K fps 满足 POV-3D 7K+ fps 需求.

**硬件改动**: panel PCB 飞线 / 切迹, 把每颗 FM6124 的 SDI 引出来. 接到鹿小班 GPIO1 + GPIO2 排针.

## IO 总需求

| 信号 | 数量 | 备注 |
|---|---|---|
| SDI[47:0] | 48 | 每 chip 独立, 6 chain × 8 chip 拆 daisy |
| DCLK | 1 | 全 panel broadcast |
| LATCH | 1 | broadcast |
| OE | 1 | broadcast |
| ABCDE | 5 | 行地址 broadcast |
| **合计** | **56** | |

## IO 供给 (鹿小班)

- GPIO1 (BANK 33): 34 PL IO, 全空 (HUB75E 当前用 14)
- GPIO2 (BANK 35): ~32 PL IO, 跟 ETH **不冲突** (见 `reference_lxb_gpio2_pinout.md`)
- 合计 66 IO > 56 需求 ✓ ETH 保留

## SDI 分组逻辑

48 SDI 按"chain × chip" 二维编号:
```
chain 0 (R1): SDI[0..7]   = R1_chip0..R1_chip7  (top half panel R 通道, 8 颗 cascade chip)
chain 1 (G1): SDI[8..15]  = G1_chip0..G1_chip7  (top half panel G)
chain 2 (B1): SDI[16..23] = B1_chip0..B1_chip7  (top half panel B)
chain 3 (R2): SDI[24..31] = R2_chip0..R2_chip7  (bot half panel R)
chain 4 (G2): SDI[32..39] = G2_chip0..G2_chip7  (bot half panel G)
chain 5 (B2): SDI[40..47] = B2_chip0..B2_chip7  (bot half panel B)
```

每颗芯片驱动 16 LED 列 (chip 0 = col 0..15, chip 1 = col 16..31, ..., chip 7 = col 112..127).

## GPIO1 (BANK 33) 分配 — 24 SDI (top half) + 8 control

| GPIO1 Pin | Site | PIN | 信号 | 备注 |
|---|---|---|---|---|
| 5 | IO_L9N_T1_DQS_33 | Y21 | DCLK | 时钟 (DQS 高速 OK) |
| 6 | IO_L9P_T1_DQS_33 | Y20 | LATCH | |
| 7 | IO_L7N_T1_33 | AB22 | OE | |
| 8 | IO_L7P_T1_33 | AA22 | A (addr_bit0) | |
| 9 | IO_L8N_T1_33 | AB21 | B (addr_bit1) | |
| 10 | IO_L8P_T1_33 | AA21 | C (addr_bit2) | |
| 11 | IO_L10P_T1_33 | AB19 | D (addr_bit3) | |
| 12 | IO_L10N_T1_33 | AB20 | E (addr_bit4) | |
| 13 | IO_L11N_T1_SRCC_33 | AA19 | SDI[0]  R1_chip0 | |
| 14 | IO_L11P_T1_SRCC_33 | Y19  | SDI[1]  R1_chip1 | |
| 15 | IO_L18N_T2_33 | AB16 | SDI[2]  R1_chip2 | |
| 16 | IO_L18P_T2_33 | AA16 | SDI[3]  R1_chip3 | |
| 17 | IO_L12P_T1_MRCC_33 | Y18  | SDI[4]  R1_chip4 | |
| 18 | IO_L12N_T1_MRCC_33 | AA18 | SDI[5]  R1_chip5 | |
| 25 | IO_L13N_T2_MRCC_33 | W18  | SDI[6]  R1_chip6 | |
| 26 | IO_L13P_T2_MRCC_33 | W17  | SDI[7]  R1_chip7 | |
| 27 | IO_L17P_T2_33 | AA17 | SDI[8]  G1_chip0 | |
| 28 | IO_L17N_T2_33 | AB17 | SDI[9]  G1_chip1 | |
| 29 | IO_L14P_T2_SRCC_33 | W16  | SDI[10] G1_chip2 | |
| 30 | IO_L14N_T2_SRCC_33 | Y16  | SDI[11] G1_chip3 | |
| 19 | IO_L19P_T3_33 | V14  | SDI[12] G1_chip4 | |
| 20 | IO_L19N_T3_VREF_33 | V15  | SDI[13] G1_chip5 | VREF 当 LVCMOS OK |
| 21 | IO_L22N_T3_33 | AA14 | SDI[14] G1_chip6 | |
| 22 | IO_L22P_T3_33 | Y14  | SDI[15] G1_chip7 | |
| 23 | IO_L20N_T3_33 | W13  | SDI[16] B1_chip0 | |
| 24 | IO_L20P_T3_33 | V13  | SDI[17] B1_chip1 | |
| 31 | IO_L23N_T3_33 | AA13 | SDI[18] B1_chip2 | |
| 32 | IO_L23P_T3_33 | Y13  | SDI[19] B1_chip3 | |
| 33 | IO_L24N_T3_33 | AB15 | SDI[20] B1_chip4 | |
| 34 | IO_L24P_T3_33 | AB14 | SDI[21] B1_chip5 | |
| 35 | IO_L3P_T0_DQS_33 | V22  | SDI[22] B1_chip6 | |
| 36 | IO_L3N_T0_DQS_33 | W22  | SDI[23] B1_chip7 | |
| 37 | IO_L2P_T0_33 | T22  | spare1 | |
| 38 | IO_L2N_T0_33 | U22  | spare2 | |

**用 32 IO / 34, 留 2 spare. 8 control + 24 SDI 完成 top half panel.**

## GPIO2 (BANK 35) 分配 — 24 SDI (bot half)

| GPIO2 Pin | Site | PIN | 信号 |
|---|---|---|---|
| 5 | IO_L4N_T0_35 | G16 | SDI[24] R2_chip0 |
| 6 | IO_L4P_T0_35 | G15 | SDI[25] R2_chip1 |
| 7 | IO_L1P_T0_AD0P_35 | F16 | SDI[26] R2_chip2 |
| 8 | IO_L1N_T0_AD0N_35 | E16 | SDI[27] R2_chip3 |
| 9 | IO_L12N_T1_MRCC_35 | C19 | SDI[28] R2_chip4 |
| 10 | IO_L12P_T1_MRCC_35 | D18 | SDI[29] R2_chip5 |
| 11 | IO_L3P_T0_DQS_AD1P_35 | E15 | SDI[30] R2_chip6 |
| 12 | IO_L3N_T0_DQS_AD1N_35 | D15 | SDI[31] R2_chip7 |
| 13 | IO_L2P_T0_AD8P_35 | D16 | SDI[32] G2_chip0 |
| 14 | IO_L2N_T0_AD8N_35 | D17 | SDI[33] G2_chip1 |
| 15 | IO_L7P_T1_AD2P_35 | C15 | SDI[34] G2_chip2 |
| 16 | IO_L7N_T1_AD2N_35 | B15 | SDI[35] G2_chip3 |
| 17 | IO_L14N_T2_AD4N_SRCC_35 | C20 | SDI[36] G2_chip4 |
| 18 | IO_L14P_T2_AD4P_SRCC_35 | D20 | SDI[37] G2_chip5 |
| 19 | IO_L9P_T1_DQS_AD3P_35 | A16 | SDI[38] G2_chip6 |
| 20 | IO_L9N_T1_DQS_AD3N_35 | A17 | SDI[39] G2_chip7 |
| 21 | IO_L8P_T1_AD10P_35 | B16 | SDI[40] B2_chip0 |
| 22 | IO_L8N_T1_AD10N_35 | B17 | SDI[41] B2_chip1 |
| 23 | IO_L18P_T2_AD13P_35 | B21 | SDI[42] B2_chip2 |
| 24 | IO_L18N_T2_AD13N_35 | B22 | SDI[43] B2_chip3 |
| 25 | IO_L16N_T2_35 | C22 | SDI[44] B2_chip4 |
| 26 | IO_L16P_T2_35 | D22 | SDI[45] B2_chip5 |
| 27 | IO_L21P_T3_DQS_AD14P_35 | E19 | SDI[46] B2_chip6 |
| 28 | IO_L21N_T3_DQS_AD14N_35 | E20 | SDI[47] B2_chip7 |
| 29-38 | (剩余) | | spare 10 IO |

**用 24 IO / 32, 剩 10 IO 可做 photodiode sync / extra control.**

## 性能预测

DCLK_DIV=2 @ aclk 75M → DCLK = 37.5 MHz (或 60M aclk = 30M DCLK spec 内):

**shift_time** = 16 col × 2 cyc = **32 aclk cycles** (chain length 16, 不再 128)

**6-bit BCM, TUNIT sweet spot = 1** (plane 5 = 32 cyc = shift):
- Phase = OE_PRE(8) + max(32, TUNIT<<plane) = 40 cyc (for all planes when TUNIT≤1, shift-bound)
- per row overhead = 6 × (5+4+3) = 72 cyc + 6 × OE_PRE+shift = 6 × 40 = 240 cyc
- per row = 72 + 240 = 312 cyc
- 32 rows = 9984 cyc
- @ 75M: **7510 fps**, @ 60M: 6010 fps

**8-bit BCM, TUNIT=1** (plane 7 = 128 > shift 32 → disp-bound for high planes):
- Phase = max(32, TUNIT<<plane) + OE_PRE = ~8+max(32, 1..128)
- planes 0-5 phase = 32+8 = 40 cyc (shift-bound)
- plane 6 phase = 64+8 = 72 cyc
- plane 7 phase = 128+8 = 136 cyc
- per row = 6×40 + 72 + 136 + 8×(5+4+3) = 240+72+136+96 = 544 cyc
- 32 rows = 17408 cyc
- @ 75M: **4307 fps**, @ 60M: 3447 fps

**满足 POV-3D 目标** (7K+ fps 6-bit, 4K+ fps 8-bit). 8-bit 不够也可降到 7-bit @ ~5500 fps.

## 实施 phase

### Phase 1: PCB 改动 (硬件, 1-2 周)
- panel 现有连接: 6 chain 各 8 chip cascade
- 改动: 切每个 chain 内 chip 间 SDI 走线, 把每颗 chip 的 SDI 引出到独立 wire
- 接到鹿小班 GPIO1/GPIO2 排针 (48 SDI + 8 control 用线)
- DCLK/LATCH/OE/ABCDE 共用一根线 broadcast 给所有 chip

### Phase 2: PL IP 重写 (verilog, 3-5 天)
- 修改 `hub75e_panel_seq.v`: rgb_out 6-bit → 48-bit parallel SR
- Pattern fetch: 一次取 48 个 pixel (每 chip 当前 col 对应的 R/G/B bit)
- col_idx 0..15 (chain length 16, 不是 128)
- 其他 BCM + LATCH + OE_PRE + overlap FSM 不变

### Phase 3: 软件 (1-2 天)
- ARM C API 不变 (still hub75e_fb_set 等)
- 内部 fb_top_dout / fb_bot_dout 仍是 24-bit per pixel, PL 端 rearrange 为 48 chip bit-slice

## 关键风险

- **panel PCB 拆 daisy 是不可逆改动**, 失败要换 panel
- **48-bit shift register 同时 toggle** 可能引起电源 di/dt 大, 需电源/decap 检查
- **DCLK fan-out 48 chip**: 单 GPIO 直驱 48 个芯片 SDI 没问题（每 chip 输入电容 ~5-10 pF, 总 ~250 pF），但 DCLK 信号 fan-out 48 个 RX 跟 48 个 SDI 同时拉高拉低还要确认 SI

## 备份方案 (PCB 改不成时)

- **12-chain (4-chip cascade)**: 12 SDI + 8 control = 20 IO，**只用 GPIO1**, 保 ETH, shift_time = 64 cyc, 帧率 ~3700 fps @ 6-bit. 改 PCB 较易, 只断 4 处即可
- **24-chain (2-chip cascade)**: 24 SDI + 8 control = 32 IO, 仍只用 GPIO1, shift_time = 32 cyc, 帧率 ~5800 fps @ 6-bit

## 工具 / SCH 来源

- SCH: `/mnt/d/芯片资料/zynq7020-484/01_硬件资料/SCH_Schematic1_2024-10-07.pdf`
  - P6: BANK 33 site → pin
  - P7: BANK 34/35 site → pin
  - P8: GPIO1/GPIO2 connector site map
- `tools/extract_sch.py` / `tools/dump_sch_pages.py` 用 pypdf 抽取
- BANK 33 ↔ GPIO1: `reference_lxb_gpio1_pinout.md`
- BANK 35 ↔ GPIO2: `reference_lxb_gpio2_pinout.md`
