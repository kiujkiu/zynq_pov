---
name: feedback_dr1_pl_probe_must_be_hang_proof
description: 清掉 gp_proten 后读没有从机的 PL 地址会永久挂死单核 CPU(之前只是干净 fault); 板子会自己重启恢复; PL 总线从机必须用板载晶振而不是 p2f_clk0
metadata:
  type: feedback
---

# 探测 DR1 的 PL 总线必须做成"不可能挂死"的 (2026-08-07, 挂过一次)

## 三个状态, 差别巨大

| gp_proten | 读一个没有从机应答的 PL 地址 | 后果 |
|---|---|---|
| **=1 (出厂默认)** | **干净的 load access fault** (`cause 5`, `badaddr 0x80000000`) | 只杀掉 devmem 进程, **板子照常跑** —— 扫地址是安全的 |
| **=0 (使能 PS-PL 之后)** | **永久挂住** | 单核 CPU 停在那条 load 上, **整块板子失联** |

⇒ **一旦清掉 `gp_proten`（见 [[reference_dr1_ps_pl_enable]]），随手 devmem 探地址就从"安全"变成"会挂板"。**

## 好消息: 挂了会自己重启

实测挂死后约 3 分钟, 板子**自行重启**（`uptime 3 min`, 串口回到 login 提示符），
不需要断电。⇒ 实验风险可控, 但每次重启会丢:
- initrd 里的一切（WiFi 模块/固件/工具）—— 用 `board/cmds_restore_wifi.txt` 从卡上重装
- 运行时写的 PS 寄存器（`gp_proten` 等会恢复出厂值）
- PL bitstream（BOOT.bin 会重新加载它自己那份）

## 我自己的两个 bug (都会挂总线)

**① 复位期间 `arready = 1`**
```verilog
if (!aresetn) begin
    s_arready <= 1'b1;   // 🔴 错: 主机的 AR 握手会完成, 然后永远等不到 R
```
AXI 的地址通道握手一旦完成, 主机就**必须**等到响应。复位期间接受地址 = 承诺了
一个永远不会兑现的响应。复位期间应当 `arready = 0`（主机会等, 但复位一释放就能走）。

**② 把总线从机时钟接到 `p2f_clk0`**
`p2f_clk0` 的分频**不是** PL Verilog 参数决定的, 是 **PS 寄存器
`0xF880103C[5:0]` (`FCLK_CNT_DIV.div_fclk0`)** 决定的 —— 属于软件配置。
我改 `system_RISC_V_Processor_System_0.v` 里的 `p2f_clk0_1st_Divisor` 是**无效操作**。
（实测出厂 BOOT.bin 里 `0xF880103C = 0x07070707`, 即四路 p2f 时钟的 div 都是 7
 ⇒ 400/8 = **50 MHz**, 本来就配好了。所以 ② 未必是这次挂死的直接原因,
 但**把"能否访问 PL"绑在 PS 配置上**这件事本身就是错的。）

## 对策 (已落地在 td_soc1 v2)

🔴 **PL 侧总线从机和 gp0 接口一律用板载晶振 (L18, 25 MHz), 不用 p2f_clk0。**
板载晶振与 PS 配置完全无关, 上电就在跑 ⇒ 从机**永远**能应答 ⇒ CPU 不可能挂在 PL 读上。
`master_gp0_axi_aclk` 是 PS 的**输入**, 喂什么时钟都行（和 Zynq 的 `M_AXI_GP0_ACLK` 一样）。

于是 `p2f_clk0` 从"前提"变成"**被测对象**":
用格雷码计数器跨域同步进一个寄存器（`0x10 PLLTICK`, 低 16 位是边沿计数,
bit16 是 `p2f_rst0_n` 电平）。计数不动 ⇒ p2f_clk0 死的; 动 ⇒ 与本地 TICK 的比值即频率比。
**全程不阻塞。**

生产设计要 50 MHz aclk 时再切到 p2f_clk0 —— 但那时已经确认它活着了。

## 可推广的原则

**用来做诊断的东西, 本身不能依赖被诊断的对象。**
心跳 LED 也是同一条: 它挂在板载时钟上、不经总线, 所以"总线不通"和"时钟没起来"
这两种完全不同的故障能分开 —— 而这正是 v1 分不开的地方。

相关：[[reference_dr1_ps_pl_enable]] [[project_dr1_parity_plan]]
