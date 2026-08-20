## ============================================================================
## lxb_icnd2260_pins.xdc — 鹿小班 + ICND2260 转接板 (zynq-lxb_2260_V0.1) 引脚约束
##
## 引脚来源 (两路独立求证, 都对上了):
##   1. 转接板原理图 D:\工程项目\硬件\pov\zynq-lxb_2260_led4048V0.1\SCH\LKS_FOC.SchDoc
##      —— 网表直接用 FPGA 的 site 名标注 (L3P_33 / L9N_33 ...), 不用猜脚号
##   2. site -> PACKAGE_PIN 用 Vivado 自带封装表核对:
##      C:\Xilinx\Vivado\2024.2\data\parts\xilinx\zynq\public\ibis\pkg\xc7z020_clg484.pkg
##   ⚠ 记忆库 reference_lxb_gpio1_pinout 里那张「GPIO1 排针脚号」表与转接板对不上
##     (脚号错位, site→ball 那一列是对的)。这里只用 site 名, 绕开脚号。
##
## 时钟: 板载 PL_CLK_50M -> IO_L13P_T2_MRCC_34 = M19 (原理图 P3 / P7)
## LED : P20 / P21, 高电平点亮 (BANK 34)
##
## 🔴 电平: BANK 33 的 VCCO 已改成 **2.5V**(为了出 LVDS_25) ⇒ 这份 TTL 约束里
##    BANK 33 的脚全部是 **LVCMOS25**; 只有 clk50(M19) 和 LED(P20/P21) 在 BANK 34,
##    仍是 3.3V。混用会被 Vivado 判 bank VCCO 冲突。DRIVE 4 / SLEW FAST 沿用
##       ssn_2260/CONCLUSION.md 的定案 (这里才 13 根, SSN 根本不是问题)。
## ============================================================================

## --- 时钟 -------------------------------------------------------------------
set_property -dict { PACKAGE_PIN M19 IOSTANDARD LVCMOS33 } [get_ports { clk50 }];  # IO_L13P_T2_MRCC_34 板载 50MHz
create_clock -period 20.000 -name clk50 [get_ports clk50]

## --- 2260 控制线 ------------------------------------------------------------
set_property -dict { PACKAGE_PIN AA13 IOSTANDARD LVCMOS25 DRIVE 4 SLEW FAST } [get_ports { dclk  }]; # L23N_33  -R5(33Ω)-  J1.21 DCLK
set_property -dict { PACKAGE_PIN AA18 IOSTANDARD LVCMOS25 DRIVE 4 SLEW FAST } [get_ports { sync  }]; # L12N_33  -R12(33Ω)- J1.23 I_SYNC
set_property -dict { PACKAGE_PIN AB15 IOSTANDARD LVCMOS25 } [get_ports { ack }];                     # L24N_33  -R11(100Ω)- J1.22 ACK_O (输入)

## --- 数据: TTL 3 通道走 P 侧 (= 芯片 SDI_R1/G1/B1 = 球 D1/E1/F1) -------------
## N 侧 = SDI_R2/G2/B2, 3 通道模式下芯片忽略。RTL 把 N 驱动成与 P 同电平,
## 让跨接的 100Ω (R7~R10) 两端等电位 ⇒ 零电流。⚠ 别改成反相驱动。
set_property -dict { PACKAGE_PIN V22  IOSTANDARD LVCMOS25 DRIVE 4 SLEW FAST } [get_ports { r_p }];   # L3P_33  J1.34
set_property -dict { PACKAGE_PIN W22  IOSTANDARD LVCMOS25 DRIVE 4 SLEW FAST } [get_ports { r_n }];   # L3N_33  J1.35
set_property -dict { PACKAGE_PIN Y20  IOSTANDARD LVCMOS25 DRIVE 4 SLEW FAST } [get_ports { g_p }];   # L9P_33  J1.31
set_property -dict { PACKAGE_PIN Y21  IOSTANDARD LVCMOS25 DRIVE 4 SLEW FAST } [get_ports { g_n }];   # L9N_33  J1.32
set_property -dict { PACKAGE_PIN AA22 IOSTANDARD LVCMOS25 DRIVE 4 SLEW FAST } [get_ports { b_p }];   # L7P_33  J1.28
set_property -dict { PACKAGE_PIN AB22 IOSTANDARD LVCMOS25 DRIVE 4 SLEW FAST } [get_ports { b_n }];   # L7N_33  J1.29

## --- LVDS 时钟对: TTL 模式不用, 静态拉低 (等电位, R7 不流电流) ---------------
set_property -dict { PACKAGE_PIN AA21 IOSTANDARD LVCMOS25 DRIVE 4 } [get_ports { clk_p }];           # L8P_33  J1.25
set_property -dict { PACKAGE_PIN AB21 IOSTANDARD LVCMOS25 DRIVE 4 } [get_ports { clk_n }];           # L8N_33  J1.26

## --- 两路 DCDC 的 EN (各带 100k 下拉, 复位态电源是关的) ----------------------
set_property -dict { PACKAGE_PIN V14 IOSTANDARD LVCMOS25 DRIVE 4 SLEW SLOW } [get_ports { en_3v8 }]; # L19P_33 -R2(1k)-  U1.EN (39k/10k -> 3.9V)
set_property -dict { PACKAGE_PIN V15 IOSTANDARD LVCMOS25 DRIVE 4 SLEW SLOW } [get_ports { en_2v8 }]; # L19N_33 -R13(1k)- U2.EN (27k/10k -> 3.0V)
## ⚠ V15 = IO_L19N_T3_VREF_33。本工程 BANK 33 全是 LVCMOS 不需要 VREF, 所以能当普通 IO 用;
##   将来若在 BANK 33 上用需要 VREF 的电平标准, 这根要挪走。

## --- 板载 LED ---------------------------------------------------------------
set_property -dict { PACKAGE_PIN P20 IOSTANDARD LVCMOS33 } [get_ports { led[0] }];
set_property -dict { PACKAGE_PIN P21 IOSTANDARD LVCMOS33 } [get_ports { led[1] }];

## ============================================================================
## 源同步输出约束
##
## dclk 由 ODDR 从 25 MHz 时钟转发出去, 数据由同一时钟的 ODDR 发出 ⇒ 边沿对齐:
## 一个数据位正好横跨「上升沿 → 下降沿」, 与手册 §3.1「数据在时钟上升沿开始传输,
## 在时钟下降沿结束传输」的字面描述一致 (芯片内部自己在位中间采样)。
##
## 🔴 这里**不写手册的 tSU/tHLD**, 因为拿不到:
##    datasheet V1.7 只给了 mini-LVDS 的 tSTU/tHLD = 1/4 tLVCP, TTL 那张开关特性表还没有。
##    ⚠ 别随手编一个「tSU=5ns, tH=5ns」: set_output_delay -min 的含义是**外部器件要求的
##      保持时间取负**, 边沿对齐的设计天生 hold≈0, 编个正的 tH 必然违例 (试过 WHS -5.4ns),
##      那是约束自相矛盾, 不是设计有问题。
##
## ⇒ 改成约束**我们能控制、也确实想要的东西**: 数据沿与 DCLK 沿的偏斜卡在 ±1 ns 内。
##      -max (T/2 - 1) = 19.0  ⇒ 数据不得比 DCLK 沿晚超过 1 ns
##      -min       +1.0        ⇒ 数据不得比 DCLK 沿早超过 1 ns (hold 要求 = -1 ns)
##    实测偏斜 ~0.44 ns (数据略早于时钟), 两侧各剩 ~0.5 ns。
##    拿到 TTL 时序表后, 换成真实的 (tSU, -tHLD) 即可。
## ⇒ 若上板发现是「芯片在 DCLK 沿上采样」而不是位中间, 把顶层的 DCLK_Q90 置 1
##    (DCLK 走 90° 相移), 那时这两行也要跟着改成非对称窗口。
## ============================================================================
create_generated_clock -name dclk_out -source [get_pins u_oddr_dclk/C] -divide_by 1 [get_ports dclk]

set DATA_PORTS [get_ports {r_p r_n g_p g_n b_p b_n sync}]
set_output_delay -clock dclk_out -max 19.000 $DATA_PORTS
set_output_delay -clock dclk_out -min  1.000 $DATA_PORTS
set_output_delay -clock dclk_out -max 19.000 -clock_fall -add_delay $DATA_PORTS
set_output_delay -clock dclk_out -min  1.000 -clock_fall -add_delay $DATA_PORTS

## ACK 是慢速回传 (手册 ACK 协议里的位宽是 µs 级), 不做时序分析
set_false_path -from [get_ports ack]
set_false_path -to   [get_ports {en_3v8 en_2v8 led[*]}]
