## ICND2047 panel on MTR transboard P3 (= panel 2) pin map
## v30 IP (hub75e_panel_seq_v2) top-level ports -> P3/panel2 sites
## Source: reference_mtr_board_v01 (LKS_FOC.SchDoc, 2026-06-12 verified)
## NOTE: 用前必须 disable hub75e_pins.xdc (旧直连脚) + led_pins.xdc (抢 AB16)
## NOTE: V15 故意不约束 (高阻) — 安全红线, OE2 驱低会跟 U1 DIR 10R 上拉打架 ~330mA

## --- 6 RGB SDI (solid-white 测 fps 顺序无所谓; 出图再按 panel 色序调) ---
set_property -dict {PACKAGE_PIN Y20  IOSTANDARD LVCMOS33 DRIVE 8 SLEW SLOW} [get_ports {hub75e_rgb[0]}] ;# R1' Y20
set_property -dict {PACKAGE_PIN Y21  IOSTANDARD LVCMOS33 DRIVE 8 SLEW SLOW} [get_ports {hub75e_rgb[1]}] ;# G1' Y21
set_property -dict {PACKAGE_PIN AA22 IOSTANDARD LVCMOS33 DRIVE 8 SLEW SLOW} [get_ports {hub75e_rgb[2]}] ;# B1' AA22
set_property -dict {PACKAGE_PIN AB22 IOSTANDARD LVCMOS33 DRIVE 8 SLEW SLOW} [get_ports {hub75e_rgb[3]}] ;# R2' AB22
set_property -dict {PACKAGE_PIN AA21 IOSTANDARD LVCMOS33 DRIVE 8 SLEW SLOW} [get_ports {hub75e_rgb[4]}] ;# G2' AA21
set_property -dict {PACKAGE_PIN AB21 IOSTANDARD LVCMOS33 DRIVE 8 SLEW SLOW} [get_ports {hub75e_rgb[5]}] ;# B2' AB21

## --- control ---
set_property -dict {PACKAGE_PIN AB16 IOSTANDARD LVCMOS33 DRIVE 8 SLEW SLOW} [get_ports {hub75e_dclk}]   ;# CLK' AB16
set_property -dict {PACKAGE_PIN AA18 IOSTANDARD LVCMOS33 DRIVE 8 SLEW SLOW} [get_ports {hub75e_lat}]     ;# LAT' AA18
set_property -dict {PACKAGE_PIN Y18  IOSTANDARD LVCMOS33 DRIVE 8 SLEW SLOW} [get_ports {hub75e_oe}]      ;# OE'  Y18 (low=亮)

## --- ABCDE row select -> P3 A'..E' (ICND2047 IP S_ADDR_ABCDE 驱动给行管) ---
set_property -dict {PACKAGE_PIN AB19 IOSTANDARD LVCMOS33 DRIVE 8 SLEW SLOW} [get_ports {hub75e_addr[0]}] ;# A' AB19
set_property -dict {PACKAGE_PIN Y19  IOSTANDARD LVCMOS33 DRIVE 8 SLEW SLOW} [get_ports {hub75e_addr[1]}] ;# B' Y19
set_property -dict {PACKAGE_PIN AA19 IOSTANDARD LVCMOS33 DRIVE 8 SLEW SLOW} [get_ports {hub75e_addr[2]}] ;# C' AA19
set_property -dict {PACKAGE_PIN AA16 IOSTANDARD LVCMOS33 DRIVE 8 SLEW SLOW} [get_ports {hub75e_addr[3]}] ;# D' AA16
set_property -dict {PACKAGE_PIN AB20 IOSTANDARD LVCMOS33 DRIVE 8 SLEW SLOW} [get_ports {hub75e_addr[4]}] ;# E' AB20
