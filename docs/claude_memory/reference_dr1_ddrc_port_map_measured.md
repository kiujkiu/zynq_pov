---
name: reference_dr1_ddrc_port_map_measured
description: 🎯 实测判决 — HP0 落在 DDRC port 2, APU 落在 port 0, 两者读同一片低4G DDR ⇒ 分口按 master 不按地址; 推翻原厂"完全按地址"的答复, UG1214 框图那半是对的
metadata:
  type: reference
---

# HP0 → DDRC port 2 (2026-08-28 上板实测)

## 怎么测的 (全只读, 不写 DDRC)

`PSTAT` @ **`0xF84213FC`**(UG1215 原文, **ro**) 的 `rd_port_busy_0..3` = bit0..3,
`wr_port_busy_0..3` = bit16..19。面板取片引擎跑起来後**差分采样**:

| | bit0 | **bit2** | bit16 |
|---|---|---|---|
| A: `pov_en=1` 取片在跑 | 29/30 | **7/30** | 1/30 |
| B: `pov_en=0` 不取片 | 29/30 | **0/30** | 0 |

⇒ **bit2 只在取片时出现 = HP0 在 port 2**。bit0 两种情况都常亮 ⇒ 是 CPU(APU)
自己在读(devmem 轮询本身)【推断: 当时唯一的另一个 DDR 读者】。

## 🔴 因此推翻的

**原厂在线答复"DDRC 端口完全按地址分, 512MB 全在低 4G ⇒ 必然都走 M2"——错。**
APU 在 port 0、HP0 在 port 2, **两者读的是同一片低 4 GB DDR**。
同一地址段的不同 master 落在不同端口 ⇒ **分口按 master, 不按地址**。

⇒ **UG1214`:7275-7280` 框图那半(按 master, XPI2=HP0)是对的。**
[[project_dr1_hp_port_shortage]] 里那条"不选边"的未决项**可以结案了**。

⚠ 仍未测: HP1 是不是 port 3(要等 lz4 引擎接上 HP1 才能同法验)。

## 🔴 但 QoS 这条路仍然走不通 —— 堵点不是地址

偏移全有了(UG1215): DDRC 窗口 **`0xF8420000` 128 KB**;
安路把 uMCTL2 的裸偏移整体 **`+0x1000`**(PSTAT 0x3FC→0x13FC 等三处印证);
HP0 对应的是 **`PCFGQOS0_2` @ `0xF84215F4`**(端口 stride 0xB0)。

🔴 **但所有 QoS 字段都标 "Quasi-dynamic Group 3", 而允许这类写入的握手寄存器
`SWCTL`/`SWSTAT`/`sw_done` 在整本 UG1215(26 个 HTML)里命中 0 次。**
⇒ **没有任何被文档化的、运行中安全写 QoS 寄存器的方法。裸写会挂整个系统。**

另外两条未知会让 VPR 即使写进去也可能无效:
- `UMCTL2_VPR_EN` 这颗芯片是 0 还是 1 未知 ⇒ 写 VPR **可能被静默降级成 LPR**
- single RAQ 还是 dual RAQ 未知 ⇒ **若是 dual RAQ, HPR 在 `PCFGQOS0` 上根本走不通**
  (原文: "For dual address queue configurations… valid values are 0 - LPR, 1 - VPR **only**")

⛔ **`0xF84203F4` 作废** —— 那是漏了 `+0x1000` 的推算, 手册 0x3F4 上没有寄存器。
⛔ `0xF8421400`(PCCFG) **最高风险不要写**: 手册把它的位域列成了 PCFGR 的形状,
   而正文 8 处引用的 `pagematch_limit`/`go2critical_en`/`bl_exp_mode` 一个都没定义。
⛔ `PCTRL_n.port_en` 复位值是 0, **别"恢复默认值"** —— 那会关掉一个 DDR 端口。

## ✅ 该走的是 XMON, 全只读

XMON 不只挂 HP_S0/HP_S1, **还挂 DDR_S0..S3**, 每实例 stride `0x400`:
`DDR_S0..S3` = `0xF8440000/0400/0800/0C00`, **`HP_S0` = `0xF8444800`**, `HP_S1` = `0xF8444C00`。

| 偏移 | 寄存器 | 用途 |
|---|---|---|
| +0x00 | `QOS_RECORD` (ro) | **PL 侧实际打的 arqos**。若是 0, DDRC 配再多 HPR 也没用 |
| +0x24 | `ARRESPTIME_MAX` (ro) | **读响应最大延迟** —— 开/关 lz4 写洪水对比即得干扰量 |
| +0x28/2C/30 | `ARRESPTIME_ACC_H/L`, `CNT` | 平均读延迟 =【推算】`(ACC<<32|ACC_L)/CNT` |
| +0x34/38/3C | `BANDWIDTH_TMWD/WR/RD` | 窗内字节数(TMWD 单位手册没给, 要标定) |
| +0x10 | `RESPTIME_CFG` | `[0]=enable` **复位是 0, 统计默认关着** |

⚠ XMON 整片(`0xF8440000-0xF8446FFF`)**不在 `Addr_mapping_dr1v90.html` 里**, 只在
`XMON_rpu.html` 自己的绝对地址列 ⇒ 两份文档不一致, 记为冲突。

相关: [[project_dr1_hp_port_shortage]] [[project_dr1_hp0_fetch_measured_ok]]
[[reference_dr1_hp_backpressure_and_ot]]
