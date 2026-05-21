## PL LEDs - Bank 34 active high
set_property -dict { PACKAGE_PIN P20  IOSTANDARD LVCMOS33 } [get_ports { led_tri_o[0] }];
set_property -dict { PACKAGE_PIN P21  IOSTANDARD LVCMOS33 } [get_ports { led_tri_o[1] }];

## HDMI TX - Native TMDS on Bank 34 (VCCO = 3.3V)
set_property -dict { PACKAGE_PIN N22  IOSTANDARD TMDS_33 } [get_ports { hdmi_tmds_clk_p }];
set_property -dict { PACKAGE_PIN P22  IOSTANDARD TMDS_33 } [get_ports { hdmi_tmds_clk_n }];
set_property -dict { PACKAGE_PIN M21  IOSTANDARD TMDS_33 } [get_ports { hdmi_tmds_data_p[0] }];
set_property -dict { PACKAGE_PIN M22  IOSTANDARD TMDS_33 } [get_ports { hdmi_tmds_data_n[0] }];
set_property -dict { PACKAGE_PIN L21  IOSTANDARD TMDS_33 } [get_ports { hdmi_tmds_data_p[1] }];
set_property -dict { PACKAGE_PIN L22  IOSTANDARD TMDS_33 } [get_ports { hdmi_tmds_data_n[1] }];
set_property -dict { PACKAGE_PIN J21  IOSTANDARD TMDS_33 } [get_ports { hdmi_tmds_data_p[2] }];
set_property -dict { PACKAGE_PIN J22  IOSTANDARD TMDS_33 } [get_ports { hdmi_tmds_data_n[2] }];

## LED panel - GPIO1 connector / BANK 33 (VCCO = 3.3V, LVCMOS33)
## J1 = panel side FPC/排针, GPIO1 = 鹿小班 2×40 排针
## 接线图来源: image-20260518-140625-dy36.jpg, SCH 映射来自 reference_lxb_gpio1_pinout.md
##
## panel_gpio_tri_o[N] bit assignment (单 32-bit axi_gpio output, all output):
##   bit  0  DCLK         (J1.10 → GPIO1.17 → Y18  IO_L12P_T1_MRCC_33  主时钟必 MRCC)
##   bit  1  LAT          (J1.12 → GPIO1.14 → Y19  IO_L11P_T1_SRCC_33  跟 DCLK 同 byte)
##   bit  2  GCLK         (J1.14 → GPIO1.13 → AA19 IO_L11N_T1_SRCC_33  ICND1069 内置 PLL 可能 NC)
##   bit  3  R1           (J1.24 → GPIO1.8  → AA22 IO_L7P_T1_33)
##   bit  4  G1           (J1.25 → GPIO1.7  → AB22 IO_L7N_T1_33)
##   bit  5  B1           (J1.22 → GPIO1.10 → AA21 IO_L8P_T1_33)
##   bit  6  R2           (J1.23 → GPIO1.9  → AB21 IO_L8N_T1_33)
##   bit  7  G2           (J1.20 → GPIO1.6  → Y20  IO_L9P_T1_DQS_33   DQS 当 GPIO 用)
##   bit  8  B2           (J1.21 → GPIO1.5  → Y21  IO_L9N_T1_DQS_33   DQS 当 GPIO 用)
##   bit  9  R3           (J1.18 → GPIO1.11 → AB19 IO_L10P_T1_33)
##   bit 10  G3           (J1.19 → GPIO1.18 → AA18 IO_L12N_T1_MRCC_33  接线图标"—"那行即 G3, user 确认 2026-05-18)
##   bit 11  B3           (J1.16 → GPIO1.12 → AB20 IO_L10N_T1_33)
##   bit 12  AIN  行 A    (J1.28 → GPIO1.25 → W18  IO_L13N_T2_MRCC_33  扫描慢)
##   bit 13  BIN  行 B    (J1.27 → GPIO1.26 → W17  IO_L13P_T2_MRCC_33  扫描慢)
##   bit 14  CIN  行 C    (J1.26 → GPIO1.29 → W16  IO_L14P_T2_SRCC_33  扫描慢)
##   bit 15  SPI_CLK      (J1.11 → GPIO1.27 → AA17 IO_L17P_T2_33      panel flash 配置)
##   bit 16  SPI_CS       (J1.15 → GPIO1.28 → AB17 IO_L17N_T2_33)
##   bit 17  SPI_MOSI     (J1.13 → GPIO1.16 → AA16 IO_L18P_T2_33)
##   bit 18  SPI_MISO_IN  (J1.9  → GPIO1.15 → AB16 IO_L18N_T2_33      FPGA 输入)
##
## 注意 SPI_MISO 是 FPGA 输入，axi_gpio 可以做双向 (channel-2 input) 或独立 axi_gpio_in
## 暂统一一个 32-bit output GPIO + SPI_MISO 走第二个 1-bit input GPIO

set_property -dict { PACKAGE_PIN Y18  IOSTANDARD LVCMOS33 } [get_ports { panel_gpio_tri_o[0]  }];  # DCLK
set_property -dict { PACKAGE_PIN Y19  IOSTANDARD LVCMOS33 } [get_ports { panel_gpio_tri_o[1]  }];  # LAT
set_property -dict { PACKAGE_PIN AA19 IOSTANDARD LVCMOS33 } [get_ports { panel_gpio_tri_o[2]  }];  # GCLK
set_property -dict { PACKAGE_PIN AA22 IOSTANDARD LVCMOS33 } [get_ports { panel_gpio_tri_o[3]  }];  # R1
set_property -dict { PACKAGE_PIN AB22 IOSTANDARD LVCMOS33 } [get_ports { panel_gpio_tri_o[4]  }];  # G1
set_property -dict { PACKAGE_PIN AA21 IOSTANDARD LVCMOS33 } [get_ports { panel_gpio_tri_o[5]  }];  # B1
set_property -dict { PACKAGE_PIN AB21 IOSTANDARD LVCMOS33 } [get_ports { panel_gpio_tri_o[6]  }];  # R2
set_property -dict { PACKAGE_PIN Y20  IOSTANDARD LVCMOS33 } [get_ports { panel_gpio_tri_o[7]  }];  # G2
set_property -dict { PACKAGE_PIN Y21  IOSTANDARD LVCMOS33 } [get_ports { panel_gpio_tri_o[8]  }];  # B2
set_property -dict { PACKAGE_PIN AB19 IOSTANDARD LVCMOS33 } [get_ports { panel_gpio_tri_o[9]  }];  # R3
set_property -dict { PACKAGE_PIN AA18 IOSTANDARD LVCMOS33 } [get_ports { panel_gpio_tri_o[10] }];  # G3
set_property -dict { PACKAGE_PIN AB20 IOSTANDARD LVCMOS33 } [get_ports { panel_gpio_tri_o[11] }];  # B3
set_property -dict { PACKAGE_PIN W18  IOSTANDARD LVCMOS33 } [get_ports { panel_gpio_tri_o[12] }];  # AIN
set_property -dict { PACKAGE_PIN W17  IOSTANDARD LVCMOS33 } [get_ports { panel_gpio_tri_o[13] }];  # BIN
set_property -dict { PACKAGE_PIN W16  IOSTANDARD LVCMOS33 } [get_ports { panel_gpio_tri_o[14] }];  # CIN
set_property -dict { PACKAGE_PIN AA17 IOSTANDARD LVCMOS33 } [get_ports { panel_gpio_tri_o[15] }];  # SPI_CLK
set_property -dict { PACKAGE_PIN AB17 IOSTANDARD LVCMOS33 } [get_ports { panel_gpio_tri_o[16] }];  # SPI_CS
set_property -dict { PACKAGE_PIN AA16 IOSTANDARD LVCMOS33 } [get_ports { panel_gpio_tri_o[17] }];  # SPI_MOSI

## SPI_MISO 走单独的 1-bit input axi_gpio channel
set_property -dict { PACKAGE_PIN AB16 IOSTANDARD LVCMOS33 } [get_ports { panel_spi_miso_tri_i[0] }];  # SPI_MISO
