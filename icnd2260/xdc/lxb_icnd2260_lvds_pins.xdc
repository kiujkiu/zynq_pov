## ============================================================================
## lxb_icnd2260_lvds_pins.xdc — 鹿小班 + 转接板 zynq-lxb_2260_V0.1, **mini-LVDS** 版
##
## 🔴 前提: 鹿小班 BANK 33 的 VCCO 必须先改成 2.5V, 否则 7 系列 HR bank 出不了
##    LVDS_25, 这份约束会直接报错。BANK 33 是唯一挂在 VCCIO_ADJ 上的 bank
##    (34/35/13/0 都固定 VCC3V3), 改 U6 的反馈电阻 R13: 33K → 22.6K(1%)。
##    详见 docs/02_lvds_bringup.md。
##
## 引脚来源与 TTL 版同源(转接板网表用 site 名标注 + Vivado 封装表核对),
## 差别只在电平标准和「哪一对是第一通道」。
##
## ⚠ 第一通道 = D0 = SDI_B1 = **B 对**(不是 R)。手册 §3 传输模式表的
##   「寄存器配置」列: TTL 走 SDI_R1, mLVDS 一律走 D0IP/N。
## ============================================================================

## --- 时钟 (BANK 34, 仍是 3.3V) ----------------------------------------------
set_property -dict { PACKAGE_PIN M19 IOSTANDARD LVCMOS33 } [get_ports { clk50 }];
create_clock -period 20.000 -name clk50 [get_ports clk50]

## --- mini-LVDS 四对 (BANK 33 @ 2.5V) ----------------------------------------
## 位时钟对
set_property -dict { PACKAGE_PIN AA21 IOSTANDARD LVDS_25 } [get_ports { clk_p }]; # L8P_33  J1.25 L_CKIP
set_property -dict { PACKAGE_PIN AB21 IOSTANDARD LVDS_25 } [get_ports { clk_n }]; # L8N_33  J1.26 L_CKIN
## D0 = SDI_B1 = lane0 (配置 + VHEAD + B 图像数据)
set_property -dict { PACKAGE_PIN AA22 IOSTANDARD LVDS_25 } [get_ports { b_p }];   # L7P_33  J1.28
set_property -dict { PACKAGE_PIN AB22 IOSTANDARD LVDS_25 } [get_ports { b_n }];   # L7N_33  J1.29
## D1 = SDI_G1 = lane1
set_property -dict { PACKAGE_PIN Y20  IOSTANDARD LVDS_25 } [get_ports { g_p }];   # L9P_33  J1.31
set_property -dict { PACKAGE_PIN Y21  IOSTANDARD LVDS_25 } [get_ports { g_n }];   # L9N_33  J1.32
## D2 = SDI_R1 = lane2
set_property -dict { PACKAGE_PIN V22  IOSTANDARD LVDS_25 } [get_ports { r_p }];   # L3P_33  J1.34
set_property -dict { PACKAGE_PIN W22  IOSTANDARD LVDS_25 } [get_ports { r_n }];   # L3N_33  J1.35

## --- 单端控制 (BANK 33 ⇒ 跟着变 LVCMOS25) -----------------------------------
set_property -dict { PACKAGE_PIN AA18 IOSTANDARD LVCMOS25 DRIVE 8 SLEW FAST } [get_ports { sync }]; # L12N_33 J1.23 I_SYNC
set_property -dict { PACKAGE_PIN AA13 IOSTANDARD LVCMOS25 DRIVE 8 } [get_ports { dclk }];           # L23N_33 J1.21 (LVDS 模式恒 0)
set_property -dict { PACKAGE_PIN AB15 IOSTANDARD LVCMOS25 } [get_ports { ack }];                    # L24N_33 J1.22 ACK_O
set_property -dict { PACKAGE_PIN V14  IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW } [get_ports { en_3v8 }];
set_property -dict { PACKAGE_PIN V15  IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW } [get_ports { en_2v8 }];

## --- 板载 LED (BANK 34, 3.3V) -----------------------------------------------
set_property -dict { PACKAGE_PIN P20 IOSTANDARD LVCMOS33 } [get_ports { led[0] }];
set_property -dict { PACKAGE_PIN P21 IOSTANDARD LVCMOS33 } [get_ports { led[1] }];

## ============================================================================
## 源同步输出约束
##
## mini-LVDS 的 tSTU/tHLD = **1/4 tLVCP** (datasheet V1.7) ⇒ 芯片在**位中间**采样
## ⇒ 转发时钟必须比数据晚 90°(顶层用 MMCM CLKOUT1_PHASE=90 做)。
## ⚠ 这跟 TTL 版的「边沿对齐」要求正好相反, 别把两份 XDC 混用。
##
## 下面的 BITCLK_NS 必须和顶层 CLK_DIV 对上: 位时钟 = 1000MHz / CLK_DIV
##   CLK_DIV 24 -> 41.667MHz -> 24.0 ns      (首光用这档)
##   CLK_DIV 12 -> 83.333MHz -> 12.0 ns
##   CLK_DIV  6 ->166.667MHz ->  6.0 ns      (手册上限)
## ============================================================================
set BITCLK_NS 24.0
set MARGIN     1.0
set TSU [expr {$BITCLK_NS/4.0 - $MARGIN}]
set THD [expr {$BITCLK_NS/4.0 - $MARGIN}]

create_generated_clock -name lvds_ck -source [get_pins u_oddr_ck/C] -divide_by 1 [get_ports clk_p]

set LVDS_DATA [get_ports {b_p g_p r_p}]
set_output_delay -clock lvds_ck -max  $TSU              $LVDS_DATA
set_output_delay -clock lvds_ck -min [expr {-$THD}]     $LVDS_DATA
set_output_delay -clock lvds_ck -max  $TSU          -clock_fall -add_delay $LVDS_DATA
set_output_delay -clock lvds_ck -min [expr {-$THD}] -clock_fall -add_delay $LVDS_DATA

## I_SYNC 在 LVDS 模式下每帧才翻一次, 不是逐位信号 —— 不做源同步分析
set_false_path -to   [get_ports {sync dclk en_3v8 en_2v8 led[*]}]
set_false_path -from [get_ports ack]
