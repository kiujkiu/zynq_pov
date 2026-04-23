## Ethernet RGMII + MDIO PHY - pins from 鹿小班 HelloZynqPS_Linux_ETH reference XDC
## Bank 35 (typical, 3.3V)

set_property -dict { PACKAGE_PIN G21 IOSTANDARD LVCMOS33 } [get_ports MDIO_PHY_0_mdc];
set_property -dict { PACKAGE_PIN H22 IOSTANDARD LVCMOS33 } [get_ports MDIO_PHY_0_mdio_io];

set_property -dict { PACKAGE_PIN A22 IOSTANDARD LVCMOS33 } [get_ports {RGMII_0_rd[0]}];
set_property -dict { PACKAGE_PIN A18 IOSTANDARD LVCMOS33 } [get_ports {RGMII_0_rd[1]}];
set_property -dict { PACKAGE_PIN A19 IOSTANDARD LVCMOS33 } [get_ports {RGMII_0_rd[2]}];
set_property -dict { PACKAGE_PIN B20 IOSTANDARD LVCMOS33 } [get_ports {RGMII_0_rd[3]}];
set_property -dict { PACKAGE_PIN A21 IOSTANDARD LVCMOS33 } [get_ports RGMII_0_rx_ctl];
set_property -dict { PACKAGE_PIN B19 IOSTANDARD LVCMOS33 } [get_ports RGMII_0_rxc];

set_property -dict { PACKAGE_PIN E21 IOSTANDARD LVCMOS33 SLEW FAST } [get_ports {RGMII_0_td[0]}];
set_property -dict { PACKAGE_PIN F21 IOSTANDARD LVCMOS33 SLEW FAST } [get_ports {RGMII_0_td[1]}];
set_property -dict { PACKAGE_PIN F22 IOSTANDARD LVCMOS33 SLEW FAST } [get_ports {RGMII_0_td[2]}];
set_property -dict { PACKAGE_PIN G20 IOSTANDARD LVCMOS33 SLEW FAST } [get_ports {RGMII_0_td[3]}];
set_property -dict { PACKAGE_PIN G22 IOSTANDARD LVCMOS33 SLEW FAST } [get_ports RGMII_0_tx_ctl];
set_property -dict { PACKAGE_PIN D21 IOSTANDARD LVCMOS33 SLEW FAST } [get_ports RGMII_0_txc];

## RGMII RX clock constraint (125 MHz = 8ns period for gigabit)
create_clock -period 8.000 -name RGMII_0_rxc -waveform {0.000 4.000} [get_ports RGMII_0_rxc];

## Async clock group (gmii_to_rgmii internal clocks vs other PL clocks)
set_clock_groups -logically_exclusive \
    -group [get_clocks -include_generated_clocks {gmii_clk_25m_out gmii_clk_2_5m_out}] \
    -group [get_clocks -include_generated_clocks gmii_clk_125m_out];

## PHY hardware reset (tied high, matching vendor PL UDP loopback ref)
set_property -dict { PACKAGE_PIN H17  IOSTANDARD LVCMOS33 } [get_ports eth_rstn];
