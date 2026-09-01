---
name: project_dr1_hp1_lz4_verified
description: 🎯 2026-08-31 HP1 + 3 个 lz4 硬件引擎首次上板全部验证通过 — 0.987 B/clk(Zynq 0.95), 并发不干扰面板取片; 那条"HP1 吃掉 hold 余量 2-4 倍"的警告实测没出现
metadata:
  type: project
---

# HP1 + lz4 三引擎上板验证通过 (2026-08-31)

那份 bit 是 `ad6e3d9` 的产物, 当天从 gitignore 里**抢救**出来
([[feedback_bit_and_bitbin_can_disagree]]: 只有一份、被忽略、从没生成过 `.bin`)。**这是它第一次上板。**

## 结论: HP1 可用, 3 个引擎能解压, 且不干扰面板

| 项 | 实测 |
|---|---|
| bit 身份 | `0x80004014` = **3**(=`NENG`)连读不变; 旧 bit 那里**别名到 `FETCH_CNT`**(刚复位应为 0) |
| PS 使能 | 只写 2 个寄存器, 而且 🎯 **`0xF8801078` bit1 本来就是 1**(HP1 早就出复位了) |
| 面板 | `STATUS` `0x00001879` 与旧 bit **相同**; `edges` 692354 vs 691670; `duty` **0.041 相同** |
| **三引擎存在** | `0x5008/0x6008/0x7008` 各写**两个不同值**再读回, **六次全 MATCH** |
| **首次解压** | `done=1 err=0`, **4096 B / 4150 拍 = 0.987 B/clk**(Zynq 0.95), 数据逐字对 |
| **并发** | 取片 + lz4x300: `0x2C`/`0x30` **逐位不变**, `pair_miss`=0, lz4 只慢 **0.2%** |

⇒ 🎯 `make_card_image_dr1.sh:73-78` 那条 **"HP1 把面板 hold 余量吃掉 2-4 倍"的警告,
实测没有出现。**

## 关键操作细节

- 引擎窗口 **`0x80005000/6000/7000` 步距 `0x1000`**(`pov_dr1_top.v` 地址 demux)。
  🔴 `povctl.c:683` 记着旧默认 `0x80020000` 是从 Zynq 平移的**错值** —— PL 从机只译码低 16 位
  ⇒ 三个引擎会全塌到 `0x0000` 落进面板寄存器堆。
- 寄存器: `0x00`=CTRL(bit0=start) `0x04`=STATUS `0x08`=SRC `0x0C`=SRC_LEN
  `0x10`=DST `0x14`=DST_LEN `0x18`=CYCLES
- 换 bit 不用动卡: `cp pov/pl_hp1.bin /lib/firmware/pl.bin` 然后手动走 configfs overlay
  (`rmdir/mkdir .../overlays/pl` + `cat pl_load.dtbo > .../dtbo`), 判据是 dmesg 出现**新的**
  `fpga prog successfully`。回退 `povboot.sh pl` 一条命令。

## 🔴 两条判据设计的教训

1. **`povctl lz4` dump 全 0 是有歧义的** —— 既可能"引擎不在", 也可能"引擎在但从没配置过"
   (`SRC`/`DST` 复位就是 0)。**写两个不同的值再读回**才能消解, 两个都中才排除"恰好读到残留"。
2. **解压前把 DST 预置成 `0xDEADBEEF`** —— 变成参考值才证明是**引擎写的**, 而不是恰好读到什么。

## ⚠ 诚实的边界

- **lz4 占空比 <1%**(shell 每次 `devmem` 是 fork+exec 5-10ms, 而引擎跑一次只要 83µs)
  ⇒ **不是三引擎满载**的严苛负载
- 🔴 **XMON HP1 写计数全程读到 0** —— `TMWD=0x400` 只有 20µs 窗口, 稀疏流量捕捉不到。
  **这条判据在低占空比下不可用**; 能用的是"done=1 且数据正确"(HP1 不应答引擎会挂 `busy=1`)。
  要用 XMON 得先调大 `TMWD` 或让引擎连续满载。
- 🔴 **没跑过 `pov_rxd --pl-lz4` 完整路径** —— `helix3b.pvs` 是 **zlib**(flags `0x8a`),
  **PL 引擎解不了它**。要吃到 PL 解码的 fps 收益, **内容必须重新渲染成 lz4 容器**。
  这是离 Zynq 效果剩下的两个 gap 之一(另一个是 PC 端推流通路)。

相关: [[project_dr1_hp_topology_decision]] [[project_lz4_pl_decoder]]
[[feedback_bit_and_bitbin_can_disagree]] [[project_dr1_parity_plan]]
