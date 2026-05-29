## ============================================================================
## hub75e_pins.xdc — HUB75E LED panel Phase 1 引脚约束
##
## Target: FM6124 panel, 128x64 1/32 scan (or 1/16, ADDR bit E 配置开关)
## 占用 14 个 BANK 33 (GPIO1) IO. Phase 2 扩到 48 SDI + 8 broadcast = 56 IO
## (跨 BANK 33+35), 详见 HUB75E_PHASE1_HOWTO.md.
##
## 接线: panel HUB75E 标准 IDC 2x8 (16 pin)
## ============================================================================

## --- 6 RGB SDI (Phase 1 = panel HUB75 chain 0 上半下半 R1/G1/B1/R2/G2/B2) ---
## Phase 2 这 6 根 = chain c0 SDI, 不动. 多出来的 chain c1..c7 走其他 IO.
set_property -dict { PACKAGE_PIN AA22 IOSTANDARD LVCMOS33 } [get_ports { hub75e_rgb[0] }]; # R1 (J1.8  / GPIO1.8)
set_property -dict { PACKAGE_PIN AB22 IOSTANDARD LVCMOS33 } [get_ports { hub75e_rgb[1] }]; # G1 (J1.7  / GPIO1.7)
set_property -dict { PACKAGE_PIN AA21 IOSTANDARD LVCMOS33 } [get_ports { hub75e_rgb[2] }]; # B1 (J1.10 / GPIO1.10)
set_property -dict { PACKAGE_PIN AB21 IOSTANDARD LVCMOS33 } [get_ports { hub75e_rgb[3] }]; # R2 (J1.9  / GPIO1.9)
set_property -dict { PACKAGE_PIN Y20  IOSTANDARD LVCMOS33 } [get_ports { hub75e_rgb[4] }]; # G2 (J1.6  / GPIO1.6)
set_property -dict { PACKAGE_PIN Y21  IOSTANDARD LVCMOS33 } [get_ports { hub75e_rgb[5] }]; # B2 (J1.5  / GPIO1.5)

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
