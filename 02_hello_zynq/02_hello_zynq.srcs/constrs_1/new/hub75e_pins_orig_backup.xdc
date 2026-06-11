## ============================================================================
## hub75e_pins.xdc — HUB75E LED panel Phase 1 引脚约束
##
## Target: FM6124 panel, 128x64 1/32 scan (or 1/16, ADDR bit E 配置开关)
## 占用 14 个 BANK 33 (GPIO1) IO. Phase 2 扩到 48 SDI + 8 broadcast = 56 IO
## (跨 BANK 33+35), 详见 HUB75E_PHASE1_HOWTO.md.
##
## 接线: panel HUB75E 标准 IDC 2x8 (16 pin)
## ============================================================================

## --- 6 RGB SDI (panel 是 GRB 顺序, 软件 swap: R/G 在 PACKAGE_PIN 互换) ---
## 信号意义: hub75e_rgb[0]=R1, [1]=G1, [2]=B1, [3]=R2, [4]=G2, [5]=B2 (PL 内)
## panel 物理: panel.1=G chip, panel.2=R chip (panel.5/6 同理), panel.3/7=B 不变
## → R 信号走 panel.2 (AB22 / AB21), G 信号走 panel.1 (AA22 / Y20)
## v34h: swap R2/G2 — 把 R2 从 Y20 (L9 DQS 跟 B2 共差分对) 挪到 AB21 (L8), 减少 R2-B2 crosstalk
##: 降 IO 翻转速率 + 驱动电流, 减少 SSO 噪声 + bank Vccio droop
set_property -dict { PACKAGE_PIN AB22 IOSTANDARD LVCMOS33 } [get_ports { hub75e_rgb[0] }]; # R1 → panel.2 (GRB swap)
set_property -dict { PACKAGE_PIN AA22 IOSTANDARD LVCMOS33 } [get_ports { hub75e_rgb[1] }]; # G1 → panel.1 (GRB swap)
set_property -dict { PACKAGE_PIN AA21 IOSTANDARD LVCMOS33 } [get_ports { hub75e_rgb[2] }]; # B1 → panel.3
set_property -dict { PACKAGE_PIN AB21 IOSTANDARD LVCMOS33 } [get_ports { hub75e_rgb[3] }]; # R2 → panel.6 (v34h: was Y20, swap to L8 break DQS crosstalk)
set_property -dict { PACKAGE_PIN Y20  IOSTANDARD LVCMOS33 } [get_ports { hub75e_rgb[4] }]; # G2 → panel.5 (v34h: was AB21)
set_property -dict { PACKAGE_PIN Y21  IOSTANDARD LVCMOS33 } [get_ports { hub75e_rgb[5] }]; # B2 → panel.7

## --- v34e: panel 2 RGB SDI (128×128 dual panel, 共享 panel 1 的 CLK/LAT/OE/ABCDE) ---
## panel 2 IDC: pin 1 R1', pin 2 G1', pin 3 B1', pin 5 R2', pin 6 G2', pin 7 B2'
## 用户选物理换线兼容 (panel 2 内部 BRG vs panel 1 GRB), xdc 跟 panel 1 一致
## GPIO1 pin 号已纠正 (memory 之前 J1.19/20/21/22 跟 J1.31/32/33/34 抽反)
## v34h: 加 减 SSO
set_property -dict { PACKAGE_PIN AA19 IOSTANDARD LVCMOS33 } [get_ports { hub75e_rgb2[0] }]; # R1'  → J1.13 AA19
set_property -dict { PACKAGE_PIN AA13 IOSTANDARD LVCMOS33 } [get_ports { hub75e_rgb2[1] }]; # G1'  → J1.22 AA13
set_property -dict { PACKAGE_PIN Y13  IOSTANDARD LVCMOS33 } [get_ports { hub75e_rgb2[2] }]; # B1'  → J1.21 Y13
set_property -dict { PACKAGE_PIN AB15 IOSTANDARD LVCMOS33 } [get_ports { hub75e_rgb2[3] }]; # R2'  → J1.20 AB15
set_property -dict { PACKAGE_PIN AB14 IOSTANDARD LVCMOS33 } [get_ports { hub75e_rgb2[4] }]; # G2'  → J1.19 AB14
set_property -dict { PACKAGE_PIN Y16  IOSTANDARD LVCMOS33 } [get_ports { hub75e_rgb2[5] }]; # B2'  → J1.30 Y16

## --- v34L: panel 2 独立 DCLK2/LAT2/OE2/ABCDE2 (减 dual panel 共享信号 SI) ---
set_property -dict { PACKAGE_PIN Y14  IOSTANDARD LVCMOS33 } [get_ports { hub75e_dclk2 }];   # DCLK2 → J1.31 (Y14, L22P)
set_property -dict { PACKAGE_PIN V14  IOSTANDARD LVCMOS33 } [get_ports { hub75e_lat2  }];   # LAT2  → J1.34 (V14, L19P)
set_property -dict { PACKAGE_PIN V15  IOSTANDARD LVCMOS33 } [get_ports { hub75e_oe2   }];   # OE2   → J1.33 (V15, L19N VREF 输出 OK)
set_property -dict { PACKAGE_PIN V13  IOSTANDARD LVCMOS33 } [get_ports { hub75e_addr2[0] }]; # A2 → J1.23 V13
set_property -dict { PACKAGE_PIN W13  IOSTANDARD LVCMOS33 } [get_ports { hub75e_addr2[1] }]; # B2 → J1.24 W13
set_property -dict { PACKAGE_PIN T22  IOSTANDARD LVCMOS33 } [get_ports { hub75e_addr2[2] }]; # C2 → J1.37 T22
set_property -dict { PACKAGE_PIN U22  IOSTANDARD LVCMOS33 } [get_ports { hub75e_addr2[3] }]; # D2 → J1.38 U22
set_property -dict { PACKAGE_PIN AA14 IOSTANDARD LVCMOS33 } [get_ports { hub75e_addr2[4] }]; # E2 → J1.32 AA14 (L22N)

## --- 时钟控制 broadcast (Phase 1 + Phase 2 不变) ---
set_property -dict { PACKAGE_PIN Y18  IOSTANDARD LVCMOS33 } [get_ports { hub75e_dclk }];   # CLK  (J1.17 / GPIO1.17, MRCC)
set_property -dict { PACKAGE_PIN Y19  IOSTANDARD LVCMOS33 } [get_ports { hub75e_lat  }];   # LAT  (J1.14 / GPIO1.14, SRCC)
set_property -dict { PACKAGE_PIN AB20 IOSTANDARD LVCMOS33 } [get_ports { hub75e_oe   }];   # OE   (J1.12 / GPIO1.12, low=亮)

## --- 5-bit 行地址 broadcast ---
## 双模式 ADDR (reg_ctrl[4] 切换), 引脚位置不变, 接线时按 panel 类型选:
##   ABCDE 模式 (reg_ctrl[4]=0):  [0]=A [1]=B [2]=C [3]=D [4]=E
##   shift-reg 模式 (reg_ctrl[4]=1):
##     [0]=ADDR_CLK  [1]=ADDR_DAT  [2]=ADDR_EN  [3]/[4]=NC (panel 端接 GND)
set_property -dict { PACKAGE_PIN W18  IOSTANDARD LVCMOS33 } [get_ports { hub75e_addr[0] }]; # ABCDE: A    / SR: ADDR_CLK  (J1.25)
set_property -dict { PACKAGE_PIN W17  IOSTANDARD LVCMOS33 } [get_ports { hub75e_addr[1] }]; # ABCDE: B    / SR: ADDR_DAT  (J1.26)
set_property -dict { PACKAGE_PIN W16  IOSTANDARD LVCMOS33 } [get_ports { hub75e_addr[2] }]; # ABCDE: C    / SR: ADDR_EN   (J1.29, SRCC)
set_property -dict { PACKAGE_PIN AB19 IOSTANDARD LVCMOS33 } [get_ports { hub75e_addr[3] }]; # ABCDE: D    / SR: 不接       (J1.11)
set_property -dict { PACKAGE_PIN AA18 IOSTANDARD LVCMOS33 } [get_ports { hub75e_addr[4] }]; # ABCDE: E    / SR: 不接       (J1.18, MRCC)

## --- HUB75E IDC 16-pin 接线参考 ---
##   pin 1  R1   = J1.8   pin 2  G1   = J1.7
##   pin 3  B1   = J1.10  pin 4  GND  = J1 GND (排针 pin 1-4 任意)
##   pin 5  R2   = J1.9   pin 6  G2   = J1.6
##   pin 7  B2   = J1.5   pin 8  E    = J1.18 (1/32 scan), 1/16 时接 GND
##   pin 9  A    = J1.25  pin 10 B    = J1.26
##   pin 11 C    = J1.29  pin 12 D    = J1.11
##   pin 13 CLK  = J1.17  pin 14 LAT  = J1.14
##   pin 15 OE   = J1.12  pin 16 GND  = J1 GND
