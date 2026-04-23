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
