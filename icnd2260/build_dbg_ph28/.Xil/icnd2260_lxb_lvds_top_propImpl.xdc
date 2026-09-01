set_property SRC_FILE_INFO {cfile:D:/claude_workspace/pov3d/zynq_pov/icnd2260/xdc/lxb_icnd2260_lvds_pins.xdc rfile:../../xdc/lxb_icnd2260_lvds_pins.xdc id:1} [current_design]
set_property src_info {type:XDC file:1 line:17 export:INPUT save:INPUT read:READ} [current_design]
set_property -dict { PACKAGE_PIN M19 IOSTANDARD LVCMOS33 } [get_ports { clk50 }];
set_property src_info {type:XDC file:1 line:22 export:INPUT save:INPUT read:READ} [current_design]
set_property -dict { PACKAGE_PIN AA21 IOSTANDARD LVDS_25 } [get_ports { clk_p }]; # L8P_33  J1.25 L_CKIP
set_property src_info {type:XDC file:1 line:23 export:INPUT save:INPUT read:READ} [current_design]
set_property -dict { PACKAGE_PIN AB21 IOSTANDARD LVDS_25 } [get_ports { clk_n }]; # L8N_33  J1.26 L_CKIN
set_property src_info {type:XDC file:1 line:25 export:INPUT save:INPUT read:READ} [current_design]
set_property -dict { PACKAGE_PIN AA22 IOSTANDARD LVDS_25 } [get_ports { b_p }];   # L7P_33  J1.28
set_property src_info {type:XDC file:1 line:26 export:INPUT save:INPUT read:READ} [current_design]
set_property -dict { PACKAGE_PIN AB22 IOSTANDARD LVDS_25 } [get_ports { b_n }];   # L7N_33  J1.29
set_property src_info {type:XDC file:1 line:28 export:INPUT save:INPUT read:READ} [current_design]
set_property -dict { PACKAGE_PIN Y20  IOSTANDARD LVDS_25 } [get_ports { g_p }];   # L9P_33  J1.31
set_property src_info {type:XDC file:1 line:29 export:INPUT save:INPUT read:READ} [current_design]
set_property -dict { PACKAGE_PIN Y21  IOSTANDARD LVDS_25 } [get_ports { g_n }];   # L9N_33  J1.32
set_property src_info {type:XDC file:1 line:31 export:INPUT save:INPUT read:READ} [current_design]
set_property -dict { PACKAGE_PIN V22  IOSTANDARD LVDS_25 } [get_ports { r_p }];   # L3P_33  J1.34
set_property src_info {type:XDC file:1 line:32 export:INPUT save:INPUT read:READ} [current_design]
set_property -dict { PACKAGE_PIN W22  IOSTANDARD LVDS_25 } [get_ports { r_n }];   # L3N_33  J1.35
set_property src_info {type:XDC file:1 line:35 export:INPUT save:INPUT read:READ} [current_design]
set_property -dict { PACKAGE_PIN AA18 IOSTANDARD LVCMOS25 DRIVE 8 SLEW FAST } [get_ports { sync }]; # L12N_33 J1.23 I_SYNC
set_property src_info {type:XDC file:1 line:36 export:INPUT save:INPUT read:READ} [current_design]
set_property -dict { PACKAGE_PIN AA13 IOSTANDARD LVCMOS25 DRIVE 8 } [get_ports { dclk }];           # L23N_33 J1.21 (LVDS 模式恒 0)
set_property src_info {type:XDC file:1 line:41 export:INPUT save:INPUT read:READ} [current_design]
set_property -dict { PACKAGE_PIN AB15 IOSTANDARD LVCMOS25 PULLUP TRUE } [get_ports { ack }];        # L24N_33 J1.22 ACK_O
set_property src_info {type:XDC file:1 line:42 export:INPUT save:INPUT read:READ} [current_design]
set_property -dict { PACKAGE_PIN V14  IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW } [get_ports { en_3v8 }];
set_property src_info {type:XDC file:1 line:43 export:INPUT save:INPUT read:READ} [current_design]
set_property -dict { PACKAGE_PIN V15  IOSTANDARD LVCMOS25 DRIVE 8 SLEW SLOW } [get_ports { en_2v8 }];
set_property src_info {type:XDC file:1 line:46 export:INPUT save:INPUT read:READ} [current_design]
set_property -dict { PACKAGE_PIN P20 IOSTANDARD LVCMOS33 } [get_ports { led[0] }];
set_property src_info {type:XDC file:1 line:47 export:INPUT save:INPUT read:READ} [current_design]
set_property -dict { PACKAGE_PIN P21 IOSTANDARD LVCMOS33 } [get_ports { led[1] }];
set_property src_info {type:XDC file:1 line:63 export:INPUT save:INPUT read:READ} [current_design]
if {![info exists BITCLK_NS]}     { set BITCLK_NS 24.0 }
set_property src_info {type:XDC file:1 line:64 export:INPUT save:INPUT read:READ} [current_design]
if {![info exists MARGIN]}        { set MARGIN     1.0 }
set_property src_info {type:XDC file:1 line:65 export:INPUT save:INPUT read:READ} [current_design]
if {![info exists CLK_PHASE_DEG]} { set CLK_PHASE_DEG 90 }
