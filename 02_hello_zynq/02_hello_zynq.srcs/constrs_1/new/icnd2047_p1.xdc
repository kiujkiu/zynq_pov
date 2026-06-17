## ICND2047 panel on MTR transboard P1 (= panel 1) pin map
## v30 IP (hub75e_panel_seq_v2) top-level ports -> P1/panel1 sites
## Source: reference_mtr_board_v01 (LKS_FOC.SchDoc, 2026-06-12 verified)
## 用前必须 disable icnd2047_p3.xdc + hub75e_pins.xdc + led_pins.xdc
## 目的: 把屏换到 P1 验证 P3 的 B2 开路是接线问题还是 panel 本身

## --- 6 RGB SDI ---
set_property -dict {PACKAGE_PIN AB15 IOSTANDARD LVCMOS33 DRIVE 8 SLEW SLOW} [get_ports {hub75e_rgb[0]}] ;# R1 AB15
set_property -dict {PACKAGE_PIN AB14 IOSTANDARD LVCMOS33 DRIVE 8 SLEW SLOW} [get_ports {hub75e_rgb[1]}] ;# G1 AB14
set_property -dict {PACKAGE_PIN AA13 IOSTANDARD LVCMOS33 DRIVE 8 SLEW SLOW} [get_ports {hub75e_rgb[2]}] ;# B1 AA13
set_property -dict {PACKAGE_PIN Y13  IOSTANDARD LVCMOS33 DRIVE 8 SLEW SLOW} [get_ports {hub75e_rgb[3]}] ;# R2 Y13
set_property -dict {PACKAGE_PIN W13  IOSTANDARD LVCMOS33 DRIVE 8 SLEW SLOW} [get_ports {hub75e_rgb[4]}] ;# G2 W13
set_property -dict {PACKAGE_PIN V13  IOSTANDARD LVCMOS33 DRIVE 8 SLEW SLOW} [get_ports {hub75e_rgb[5]}] ;# B2 V13

## --- control ---
set_property -dict {PACKAGE_PIN W16  IOSTANDARD LVCMOS33 DRIVE 8 SLEW SLOW} [get_ports {hub75e_dclk}]   ;# CLK W16
set_property -dict {PACKAGE_PIN AA14 IOSTANDARD LVCMOS33 DRIVE 8 SLEW SLOW} [get_ports {hub75e_lat}]     ;# LAT AA14
set_property -dict {PACKAGE_PIN Y14  IOSTANDARD LVCMOS33 DRIVE 8 SLEW SLOW} [get_ports {hub75e_oe}]      ;# OE  Y14 (low=亮)

## --- ABCDE row select -> P1 A..E ---
set_property -dict {PACKAGE_PIN W18  IOSTANDARD LVCMOS33 DRIVE 8 SLEW SLOW} [get_ports {hub75e_addr[0]}] ;# A W18
set_property -dict {PACKAGE_PIN AB17 IOSTANDARD LVCMOS33 DRIVE 8 SLEW SLOW} [get_ports {hub75e_addr[1]}] ;# B AB17
set_property -dict {PACKAGE_PIN AA17 IOSTANDARD LVCMOS33 DRIVE 8 SLEW SLOW} [get_ports {hub75e_addr[2]}] ;# C AA17
set_property -dict {PACKAGE_PIN Y16  IOSTANDARD LVCMOS33 DRIVE 8 SLEW SLOW} [get_ports {hub75e_addr[3]}] ;# D Y16
set_property -dict {PACKAGE_PIN W17  IOSTANDARD LVCMOS33 DRIVE 8 SLEW SLOW} [get_ports {hub75e_addr[4]}] ;# E W17
