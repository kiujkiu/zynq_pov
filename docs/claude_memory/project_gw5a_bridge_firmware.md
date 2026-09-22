---
name: project_gw5a_bridge_firmware
description: 2026-09-22 WS4 — 把已时序收敛的 eg4_bridge(EG4A20, dclk150 整机0违例) 移植到 GW5A25 桥片; 工程 dr1v90/gw5a_bridge/; 综合+映射+布局布线全通过 BIT:OK (tools/gen_pins.py 按 bank 短接对+D0~D15专用脚规律生成显式 IO_LOC); 时序未收敛(dclk目标150实际Fmax 133.6MHz, 差~11%; pclk余量足)
metadata:
  type: project
---

# gw5a_bridge — EG4 桥片固件移植到 GW5A25 (2026-09-22, WS4)

用户目标口径②近期验证板定桥片器件 = **GW5A**(不是之前先做出来的 EG4)。已有一份
**时序收敛**的桥片全功能固件 [[project_eg4_bridge_firmware]](EG4A20, dclk150 整机 0 违例,
24 链驱 ICND2260 + DR1 上行分发), 本轮把它移植过去, 工程 `dr1v90/gw5a_bridge/`。

## 🎯 关键判断: 不是从零写, 是移植 + 复用

先查现状避免重复劳动 (用户 09-22 提醒过), 发现两块已经做完不用重做的活:
- **上行 IDES8 改造已在 09-11 做完** ([[project_pov3d_lvds_b2b_bench]] 相邻工作,
  `uplink_rx/rtl_x8/`): 800M 下三颗 GW5A 全 0 违例, 余量 20~27% (IDES4 在 GW5A 上
  规格零余量, 见 `uplink_rx/README_gw5a.md`)。
- **EG4 全功能桥片固件已在 09-07 做完并时序收敛** (`eg4_bridge/`)。

⇒ 真正要做的只是移植: eg4_bridge_top.v 只有两个文件碰厂家原语
(`bridge_io.v` / `bridge_clk.v`, SPEC §3.2 明文规定), 其余 (`ul_dispatch.v` / `tx_array.v` /
`icnd2260_seq.v` / `icnd2260_ack_rx.v` / `tx_shared_ctrl.v` / `tx_lane_dp.v`) 逐个 grep 核过
**零厂家原语**, 直接引用真源, 一个字不改。

## 新写的两个器件层文件 (未上机验证)

- **`bridge_clk_gw5a.v`**: 两颗 PLLA。上行 fclk/pclk (IDES8, 参数照抄
  `uplink_rx_synth_top_gw5a_x8.v`, 已验证 800M 档); 屏侧 dclk/dclk90 (150MHz, 90° 相位公式
  逐条照抄 `gw5a_port/rtl/icnd2260_clk_gw5a.v`, 那份已在 gw5a_port 首光验证过 150MHz 档)。
- **`bridge_io_gw5a.v`**: 上行 TLVDS_IBUF+IDES8×13 (oct 口, 8:1); 下行 ODDRC+TLVDS_OBUF×72+1
  (映射逐条照抄 `gw5a_port/rtl/xil_shim_gw5a.v` 的 XIL_ODDR 壳: D0=上升沿/D1=下降沿/CLEAR)。
  IDES8 位序照抄 `uplink_rx_synth_top_gw5a_x8.v` 文件头 (已逐行核 GW5A simlib 的 prim_sim.v)。
- **`gw5a_bridge_top.v`**: 除时钟/IO 两层外**逐段照抄** `eg4_bridge_top.v` (§4~10 分发/门控/
  tx/ACK/LED 一字未改)。两个关键判断:
  ① 上行改 IDES8 后 **beat 率不变** (50M beat/s, 见 `uplink_rx/README_x8.md`) ⇒
    `START_SLOTS=90` / `dclk=150` 那组下游时序预算**不用重算**, 直接照抄默认值。
  ② 差分端口从 EG4 的"每対一根、N 脚自动配对"改成 GW5A 的"物理 P/N 两根显式端口"
    (GW5A 差分是原语级 TLVDS_IBUF/OBUF, 不是约束级)。

## 🎯 第一次结果 (已过时, 见下节): 综合/映射/布局布线全跑通, 只卡最后 IO 引脚放置

```
LUT 6294 (28%)   Register 6494/23736 (28%)   I/O Port 191/239 (80%)
ERROR (PR0003): Failed to place with '37 IOBUF(s) unPlaced'
```
不是资源真的装不下 (LUT/Register 都只占 28%), 是自动布局把单端信号撒进了太多 bank。

## ✅ 2026-09-22 二修: 显式 IO_LOC, BIT: OK (综合+映射+布局布线全部通过)

新增 `tools/gen_pins.py`: 从 Gowin 自带的器件球位表 (`IDE/data/device/GW5A-25A/
UBGA324S-LV.json`, 权威数据不是手抄) 生成显式 IO_LOC, 上机试错定位到两条硬规律:

1. **bank 两两物理短接同一 VCCIO 轨** (已坐实 0↔1、4↔5、6↔7 三对, CT1143 报
   "locked by short circuit bank(x)"; 2↔3 按封装规律推定同样短接)。⇒ 单端(3.3V)
   信号必须**整对整**占一对 bank, 不能跨对拆分 (拆了另一半被 2.5V LVDS 占用就
   电压冲突)。
2. **CFG 字段里的 D0~D15 (CPU/SPI-Flash 启动数据总线) 是真专用脚**, 哪怕标签里
   还带别的名字 (如 "D08/SDA" 被 Gowin 报成 "dedicated pin (I2C)") 也会被 PR2017
   拒收 —— 只按关键字 (SSPI/I2C/CPU 等字面匹配) 不够, 要再加正则挡 `D\d{1,2}`。

最终方案: 19 个单端信号独占**最小的短接对** bank[4,5](17 位点, 用 10); 86 対
LVDS25 分给其余三对 bank[0,1,2,3,6,7](86 位点, 精确用满零富余)。

```
BIT: OK
Logic 28%   Register 28%   CLS 56%   I/O Port 191/239(80%)   IOLOGIC 86/232(38%)
```

## 下一步 (未做)

1. 🔴 **时序未收敛**: dclk 目标 150MHz, PnR 报的 Actual Fmax 只有 **133.6MHz**
   (差 ~11%); pclk(100MHz, 上行 IDES8 侧) 余量充足, Fmax 128.6MHz。要收敛 dclk
   这条(大概率是 tx_array/icnd2260_seq/ul_dispatch 某条组合路径过长, 需要在
   eg4_bridge 那份的关键路径上核一遍, 或加一级流水)。
2. `run.sdc` 里 `ck_clr_q` 的 false_path 因层次路径 (在 `u_io` 子模块里) 被裸名找不到,
   本轮先删掉过关, 收敛前要按真实例化层次名 (查 `bridge.rpt.txt`) 补回。
3. 本轮 IO_LOC 只是"工具认的合法差分位点", 不是按转接板 PCB 网表排的 —— 上真板前
   要按 `POV3D_GW5A转LED转接板_逐球引脚分配` 的实际网表重排。
4. 未上机验证 (只到布局布线, 没到实测)。
5. `icnd2260_regs_vendor.mem` (238 条供应商实测表, 与 eg4_bridge 共用) 未按 GW5A 特有的
   BSRAM 初始化写法核过。
6. 上行 DR1 侧 `uplink_tx` 仍是 LFSR 探针 (见 `uplink_rx/README_x8.md` §五), 真联调前要
   按 `uplink_rx_defs.vh` 的帧结构实现。

相关: [[project_eg4_bridge_firmware]] [[project_pov3d_bridge_logic_need]] [[project_gw5a_bridge_verification]]
[[project_pov3d_lvds_b2b_bench]] [[project_pov3d_bridge_architecture]]
