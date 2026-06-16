## ============================================================================
## hub75e_pins_mtr_v01.xdc — MTR_BOARD V0.1 转接板版引脚 (备用, 默认不启用)
## 启用: Vivado 里 disable hub75e_pins.xdc + enable 本文件 + 重 impl
## 映射源: LKS_FOC.SchDoc 网络级 trace (memory reference_mtr_board_v01.md)
## ⚠ V15 (L19N) 接转接板 U1 DIR 上拉, 必须不约束 (高阻)
## ============================================================================
## Panel 1
set_property -dict { PACKAGE_PIN AB15 IOSTANDARD LVCMOS33 } [get_ports { hub75e_rgb[0] }]; # R1  J1.20 L24N
set_property -dict { PACKAGE_PIN AB14 IOSTANDARD LVCMOS33 } [get_ports { hub75e_rgb[1] }]; # G1  J1.19 L24P
set_property -dict { PACKAGE_PIN AA13 IOSTANDARD LVCMOS33 } [get_ports { hub75e_rgb[2] }]; # B1  J1.22 L23N
set_property -dict { PACKAGE_PIN Y13  IOSTANDARD LVCMOS33 } [get_ports { hub75e_rgb[3] }]; # R2  J1.21 L23P
set_property -dict { PACKAGE_PIN W13  IOSTANDARD LVCMOS33 } [get_ports { hub75e_rgb[4] }]; # G2  J1.24 L20N
set_property -dict { PACKAGE_PIN V13  IOSTANDARD LVCMOS33 } [get_ports { hub75e_rgb[5] }]; # B2  J1.23 L20P
set_property -dict { PACKAGE_PIN W16  IOSTANDARD LVCMOS33 } [get_ports { hub75e_dclk }];   # CLK J1.29 L14P
set_property -dict { PACKAGE_PIN AA14 IOSTANDARD LVCMOS33 } [get_ports { hub75e_lat  }];   # LAT J1.32 L22N
set_property -dict { PACKAGE_PIN Y14  IOSTANDARD LVCMOS33 } [get_ports { hub75e_oe   }];   # OE  J1.31 L22P
set_property -dict { PACKAGE_PIN W18  IOSTANDARD LVCMOS33 } [get_ports { hub75e_addr[0] }]; # A J1.25 L13N
set_property -dict { PACKAGE_PIN AB17 IOSTANDARD LVCMOS33 } [get_ports { hub75e_addr[1] }]; # B J1.28 L17N
set_property -dict { PACKAGE_PIN AA17 IOSTANDARD LVCMOS33 } [get_ports { hub75e_addr[2] }]; # C J1.27 L17P
set_property -dict { PACKAGE_PIN Y16  IOSTANDARD LVCMOS33 } [get_ports { hub75e_addr[3] }]; # D J1.30 L14N
set_property -dict { PACKAGE_PIN W17  IOSTANDARD LVCMOS33 } [get_ports { hub75e_addr[4] }]; # E J1.26 L13P
## Panel 2
set_property -dict { PACKAGE_PIN Y20  IOSTANDARD LVCMOS33 } [get_ports { hub75e_rgb2[0] }]; # R1' J1.6  L9P
set_property -dict { PACKAGE_PIN Y21  IOSTANDARD LVCMOS33 } [get_ports { hub75e_rgb2[1] }]; # G1' J1.5  L9N
set_property -dict { PACKAGE_PIN AA22 IOSTANDARD LVCMOS33 } [get_ports { hub75e_rgb2[2] }]; # B1' J1.8  L7P
set_property -dict { PACKAGE_PIN AB22 IOSTANDARD LVCMOS33 } [get_ports { hub75e_rgb2[3] }]; # R2' J1.7  L7N
set_property -dict { PACKAGE_PIN AA21 IOSTANDARD LVCMOS33 } [get_ports { hub75e_rgb2[4] }]; # G2' J1.10 L8P
set_property -dict { PACKAGE_PIN AB21 IOSTANDARD LVCMOS33 } [get_ports { hub75e_rgb2[5] }]; # B2' J1.9  L8N
set_property -dict { PACKAGE_PIN AB16 IOSTANDARD LVCMOS33 } [get_ports { hub75e_dclk2 }];   # CLK' J1.15 L18N
set_property -dict { PACKAGE_PIN AA18 IOSTANDARD LVCMOS33 } [get_ports { hub75e_lat2  }];   # LAT' J1.18 L12N
set_property -dict { PACKAGE_PIN Y18  IOSTANDARD LVCMOS33 } [get_ports { hub75e_oe2   }];   # OE'  J1.17 L12P
set_property -dict { PACKAGE_PIN AB19 IOSTANDARD LVCMOS33 } [get_ports { hub75e_addr2[0] }]; # A' J1.11 L10P
set_property -dict { PACKAGE_PIN Y19  IOSTANDARD LVCMOS33 } [get_ports { hub75e_addr2[1] }]; # B' J1.14 L11P
set_property -dict { PACKAGE_PIN AA19 IOSTANDARD LVCMOS33 } [get_ports { hub75e_addr2[2] }]; # C' J1.13 L11N
set_property -dict { PACKAGE_PIN AA16 IOSTANDARD LVCMOS33 } [get_ports { hub75e_addr2[3] }]; # D' J1.16 L18P
set_property -dict { PACKAGE_PIN AB20 IOSTANDARD LVCMOS33 } [get_ports { hub75e_addr2[4] }]; # E' J1.12 L10N
## 光电开关 (转接板 RC+10k 上拉在板上, FPGA 端不再上拉)
set_property -dict { PACKAGE_PIN V14  IOSTANDARD LVCMOS33 PULLTYPE PULLUP } [get_ports { panel_spi_miso_tri_i[0] }];   # SPIN_SYNC J1.34 L19P (workaround: 复用已验证 input port)
