---
name: feedback_every_pl_bitstream_needs_a_gp0_slave
description: 🔴 2026-09-20 在 dr1a 上实挂一次 — 凡是要用 load_*.sh 从 Linux 加载的 PL 位流, **必须挂 GP0 从机**, 否则脚本读 MAGIC 那一笔没人应答, 单核 CPU 挂死, 3 分钟后看门狗重启回生产位流; lvds_b2b 的 b2b_tx_top 当初按"JTAG 烧 bit"设计所以没挂, 改成 Linux 加载后漏补
metadata:
  type: feedback
---

# 从 Linux 加载的位流, 一律要挂 GP0 从机 (2026-09-20 实挂)

## 发生了什么

`lvds_b2b` 的发端 `b2b_tx_top.v` 是按"发端用 JTAG 烧 bit, 不需要读数"设计的, 所以**没有例化
`b2b_sys`(PS + AXI3 寄存器块)**。用户 09-20 说"现在都是插 TF 卡的 Linux 模式", 我给
`conn_tx` 补了寄存器块, **却漏了 LVDS 的 `b2b_tx`**。

于是 `load_b2b.sh b2b_tx_p200_n6.bin` 加载成功后, 脚本照例去读 MAGIC ——
GP0 上没有从机应答 ⇒ **单核 CPU 挂死** ⇒ 约 3 分钟后看门狗重启 ⇒ PL 回到生产位流。

板子没坏, 串口日志里时间戳从 3195 s 回到 22 s、加载的 firmware 变回 `pl.bin`、
povmem 模块重新加载, 一眼就能认出来。

## 教训

📌 **判据: 凡是要用 `load_*.sh` 从 Linux 加载的 PL 位流, 顶层必须例化 GP0 从机。**
不是"需要读数的才挂", 而是**全都挂** —— 因为加载脚本的自检链(MAGIC/SCRATCH/未映射 0xDEADBEEF)
是无条件跑的, 而那条自检本身就是致命操作。

这条与 [[feedback_dr1_pl_probe_must_be_hang_proof]] 是同一个根因的两面:
那条讲"寄存器块内部必须对窗口内任意偏移都应答";
这条讲"**整个位流有没有这个块**"。前者管块内, 后者管块在不在。

⚠ 反过来也要注意: **没法靠探测来判断位流有没有从机** —— 探测本身就是会挂死的那一笔。
所以只能靠"约定所有位流都挂"或"调用方显式传参说这个位流没有寄存器", 不能靠脚本自己试。

## 怎么改的

`lvds_b2b` 现在**四个角色 (tx / rx / conn_tx / conn_rx) 全部挂 `b2b_sys`**,
`build.sh` 的 RTLS 列表与 PS wrapper 拷贝对四个角色一视同仁。
发端没什么可报的, 就报一个心跳计数 + 真实的 `pll_lock`(发端 PLL 没锁就什么都发不出去)。

代价只是多占一点资源, 换来加载脚本对所有位流行为一致。

相关: [[project_pov3d_lvds_b2b_bench]] [[project_pov3d_jtag_load_bench]]
