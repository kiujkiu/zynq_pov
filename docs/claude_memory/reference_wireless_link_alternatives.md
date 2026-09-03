---
name: 替代 WiFi 的链路方案盘点 — 决定性约束是"怎么进芯片", 不是"空口多快"
description: 2026-08-31 盘点; 现役链路不是瓶颈(余量 1.9×), 天花板是 USB2.0 不是空口 ⇒ 任何射频方案(60GHz/UWB/更好的WiFi)在 7020/DR1 上都被同一个漏斗卡死; 唯一能绕开漏斗的是**光链路直接进 FPGA 引脚**; 机械上轴心上下都被占(电机/顶轴承)
metadata:
  type: reference
---

# 替代 WiFi 的无线/非接触链路盘点 (2026-08-31)

## 🔴 先把问题问对: 决定性约束是 **"怎么进芯片"**, 不是 "空口能跑多快"

[[reference_dr1_wifi_ceiling_unestablished]] 08-27 那条已经证明:
**天花板在 USB2.0 + mt76 驱动, 不在 CPU** —— 124 Mbps 传输时两核**各 50% idle**,
板内回环能到 1123-1238 Mbps。而 **XC7Z020 无 PCIe 无 GTP**,
**DR1V90 同样没有**(DS1200 全文 GT/PCIE/SATA 零命中, 见 [[project_pov3d_final_target_chip_verdict]])。

⇒ **所有射频方案都是模组形态, 必须经 USB/SDIO 进板**, 而这两条在现有两块板上分别是
**280-320 Mbps(USB2 实用上限)** 和更低。**换 60 GHz / WiFi7 / UWB 都被同一个漏斗卡死,
空口再快也没用。** 这一步就能砍掉大半候选。

⇒ **唯一能绕开漏斗的是光链路: 光电二极管的差分输出可以直接接 FPGA 的 LVDS 输入脚**,
不经 USB、不经 CPU, 而且天然接上已有的 **PL lz4 解码器直写 bank** 通路
([[project_lz4_pl_decoder]] / [[project_dr1_pl_decode_removes_both_walls]])。
**这是"换链路"这件事上唯一有架构级收益的方向。**

## 现役到底缺不缺带宽 —— **不缺**

| | 数 |
|---|---|
| 现役载荷阶梯 | **2.7 → 64.1 Mbps**(cyl2 最重), 见 [[project_dr1_measure_bench]] |
| Zynq 持续吞吐 | **110-125 Mbps** |
| 余量 | 对最重内容 **1.9×** |
| 现役真瓶颈 | **翻页相位 + 面板刷新**, 见 [[project_pov3d_link_budget_status]] |

⇒ **现在换任何链路方案收益为零。** 唯一真实的痛点是
**每 20-40 s 一次 300-840 ms 的环境性停顿**, 而那是共享空口/办公室 AP 造成的
([[feedback_office_ap_blocks_esp32c5_tcp]]), **专用 AP + 独占 5G 固定信道 + 关省电就能解, 零 BOM**。

## 分层候选 (按"能不能进现有芯片"排, 不按空口速率排)

| 类 | 方案 | 进芯片的路 | 判 |
|---|---|---|---|
| 0 | **专用 AP / 点对点 / 固定 5G 信道 / 关 PS** | 不变 | ✅ **零成本, 先做这个** |
| 1 | WiFi6E/7 PCIe 网卡(MT7922 类, ~1 Gbps) | **要 PCIe** | ❌ 7020/DR1 都没有; 只有 PH1A400(PCIe Gen3) 或换外挂 SoC 才成立 |
| 2 | **60 GHz / 802.11ad / UWB** | USB/PCIe 模组 | ❌ 被 USB2 漏斗卡死 + 生态差 + 要对准 |
| 3 | **轴心自由空间光链路(自制)** | **直接进 FPGA LVDS 脚** | 🎯 **唯一绕开漏斗的路** |
| 4 | **光纤旋转关节 FORJ / 光纤滑环**(商用) | 同上(经光模块) | 🎯 工业成熟 1-10 Gbps, 但要占轴心 + 价格未询 |
| 5 | 电容/电感耦合旋转接头 | 差分进 FPGA | ⚠ 环形不占轴心, 但高速的都是商用整机, DIY 难 |
| 6 | 导电滑环传千兆 | PHY | ❌ 接触噪声/磨损, 900 RPM 寿命; 有非接触方案就别选 |
| 7 | **根本不传: 转子侧 SD/eMMC 预载** | 板上已有 | 🎯 **需求归零**, 代价是失去实时性 |

## 🔴 机械约束: 轴心上下**都已经被占**

从 macha 侧([[reference_macha_mechanical_repo]] 及其记忆库)读出的现况:
- **轴心下方 = 电机 C4110**(坐底盘顶 Z5, 转子面 Z31.7)
- **轴心上方 = Φ8 螺柱 + 688 轴承**(螺柱 267.95..307.95, 轴承 293..306) + 静止顶轴承架
- 转子上已有 **光电对射模块**做角度索引, 且 v3 六改时特意"**重解转角保光轴过圆心**"
  ⇒ **轴心光路的机械经验这个项目已经有了**

⇒ 轴心点对点光链路要么把顶轴承改成**中空轴**, 要么退而求其次用
**环形发射**(定子一圈 IR LED 常亮 → 转子单个 PD): 不占轴心, 但 PD 面积/杂散光会压带宽。
**在轴心加质量不破坏动平衡**(偏心才破坏), 而动平衡目前正是未解决项(≤850 RPM 限速),
所以轴心方案在这一点上反而占便宜。

⚠ **未知**: 转子现在**怎么供电**(滑环? 电池?) 记忆库里没有。
若已有电源滑环, 加数据通道或改中空轴的机械代价会小很多 —— **这是问用户的第一个问题**。

## 推荐顺序

1. **专用 AP + 固定信道**(零成本) ⇒ 先把那个 300-840 ms 停顿消掉。
2. 要提带宽先**改架构**: 传体素表(~~108 Mbps @15fps 未压估计~~ → **09-03 实测 lz4 后 26.4 Mbps**, 见 [[project_pov3d_voxel_table_payload_measured]]) 或干脆**预载到卡上**, 别动物理层
   —— 与 [[project_pov3d_final_target_chip_verdict]] "架构 → 板 → 器件" 同一条纪律。
3. 只有在"必须实时传切片 **266-837 Mbps**"时才换物理层, 那时首选**轴心光链路**,
   理由不是它更快, 是**只有它能绕开 USB2 直接进 PL**。
4. 光链路建议做**单向下行**, **保留 WiFi 做控制/ACK/反馈** —— PVS1 本来就有 ACK,
   而反向通道速率要求极低, 不值得为它再做一路光。

⚠ 本文除"现役余量 1.9×""USB2 是天花板""轴心被占"三条外, **其余全是纸面评估, 零实测**;
FORJ/耦合器的**价格与货期没查到**(厂商不公开, 需询价: JINPAT/大能/CENO/同康)。

---

## 🔴 2026-08-31 补: USB 这条路的硬数字 (查 DS1200 V1.0 原文)

**DS1200 V1.0 表 3-37 USB 接口性能** (本地 `dr1v90/docs/vendor/anlogic/DS1200_Datasheet_V1.0.pdf`):

| Speed Mode | 最大 |
|---|---|
| LS | 1.5 Mbps |
| FS | 12 Mbps |
| **HS** | **480 Mbps** |
| Endpoint | 16 个/控制器 |

**2× USB2.0 控制器, Device/Host 都支持。整颗 DR1 没有 USB 3.0**(也没有 PCIe/GT/SATA)。
480 是信令率, 扣协议开销实用 **280-320 Mbps**。**Zynq-7020 同样只有 USB2.0**(ci_hdrc)。

⇒ **两块板在这一点上又是打平的**, 且 **WiFi 6E/7 的 USB dongle 全是 USB3.0 器件,
插上去只会降速枚举成 HS** ⇒ **换 6E dongle 买不到带宽。**

### WiFi 6E/7 的 USB 方案确实存在, 但只有一条 mainline 路

| 芯片 | 制式 | 6 GHz | Linux 驱动 |
|---|---|---|---|
| **MT7921AU**(现役) | WiFi 6 | ❌ | mainline `mt7921u` |
| **MT7925U** | **WiFi 7 (be)** 2×2 160MHz | ✅ | **mainline, 6.7 内核合入**, mt76 树下 `mt7925/` |
| RTL8832AU/8832CU/8852CU | WiFi 6E | ✅ | ❌ **out-of-tree**(morrownr/rtw89 等) |

⇒ 真要换就只有 **MT7925U**(成品 2025-07 才出, 社区说尚未广泛测试)。
Realtek 那几颗 out-of-tree 对"交叉编译 RISC-V 内核模块"这件事是明显额外坑
(见 [[project_dr1_wifi_modules]] 那串 CRYPTO_ALGAPI/aead.o)。

### 🔴 但换 dongle 之前必须先做那个至今没做的实验

[[feedback_wifi_throughput_bottleneck_isolated]] 已经定过一个**决定性且几乎免费**的实验:
**同口插一个 U 盘测裸吞吐**。
- U 盘 250+ Mbps ⇒ 是 mt76 的锅, **换 dongle 有戏**
- U 盘也 ~125 ⇒ **ci_hdrc/dwc2 主控上限, USB 这条路到顶, 换什么 dongle 都没用**

现役 124 Mbps 只有空口协商速率(324-540)的 **25-28%**(正常 WiFi 应为 50-65%),
**这段差距至今未归因**。⇒ **在做完 U 盘实验之前买 6E dongle 是赌 50/50。**

## 🎯 顺带挖出来的: **千兆以太网是现有两块板上唯一现成的 >125 Mbps 通路**

**DS1200 V1.0 表 3-38 GBE 接口性能**: RGMII / GMII **10-1000 Mbps**, MII 10-100;
DR1 有 **2× 三速以太网 MAC**(DS1200 概览: "2x Tri-mode Gigabit Ethernet"),
出厂 Linux 的 eth0 就是千兆([[reference_dr1_factory_linux_boot]]); Zynq-7020 的 GEM 同为千兆。

⇒ **GbE 完全绕开 USB, 是这两块板上唯一不用换芯片就能拿到 8× 带宽的路。**
它当然不能直接接在转子上 —— 但**正好接上本文第 4 类**: **1000BASE-X 过 FORJ 是工业标准做法**,
用的是**板上已有的 GbE MAC, 不需要任何新芯片、不碰 USB、不碰 PCIe**。
**这是全表里工程代价最低的高带宽方案**, 前提是接受"非无线"。

相关: [[reference_pov_wifi_streaming]] [[project_dr1_wifi_modules]]
[[feedback_wifi_throughput_bottleneck_isolated]] [[reference_anlogic_lineup_pair_counts]]
