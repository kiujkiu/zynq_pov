# bd_add_led_panel_drv.tcl — 添加 axi_gpio 驱动 HUB75 风格 LED panel
#
# 适配 panel: 3 RGB 数据组 + 1/8 scan (AIN/BIN/CIN) + DCLK + LAT + GCLK + SPI 4 线.
# 接线图: image-20260518-140625-dy36.jpg, XDC: led_pins.xdc.
#
# 实现: 单 axi_gpio_panel dual-channel
#   channel 1: 18-bit output → panel_gpio_tri_o[17:0]
#              bit 分配跟 led_panel.h LED_BIT_* 一致 (DCLK/LAT/GCLK/R1..B3/AIN/BIN/CIN/SPI*)
#   channel 2:  1-bit input  → panel_spi_miso_tri_i[0]
#              FPGA 读 panel SPI MISO (烧 flash 工具用)
#
# 跑法 (Windows):
#   D:\Vivado\2024.2\bin\vivado.bat -mode batch \
#     -source D:\claude_workspace\pov3d\zynq_pov\tools\bd_add_led_panel_drv.tcl -nojournal

open_project D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq/02_hello_zynq.xpr
set_property source_mgmt_mode None [current_project]
catch { update_compile_order -fileset sources_1 }

set bd_file [get_files hello_zynq.bd]
open_bd_design $bd_file

# 1) axi_gpio_panel: dual channel, ch1 18-bit OUT, ch2 1-bit IN
if {[get_bd_cells -quiet axi_gpio_panel] eq ""} {
    create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 axi_gpio_panel
}
set_property -dict [list \
    CONFIG.C_GPIO_WIDTH    {18} \
    CONFIG.C_ALL_OUTPUTS   {1}  \
    CONFIG.C_IS_DUAL       {1}  \
    CONFIG.C_GPIO2_WIDTH   {1}  \
    CONFIG.C_ALL_INPUTS_2  {1}  \
    CONFIG.C_ALL_OUTPUTS_2 {0}  \
    CONFIG.C_DOUT_DEFAULT  {0x00010000} \
] [get_bd_cells axi_gpio_panel]
# DOUT_DEFAULT bit 16 = SPI_CS 默认拉高 (deselect panel flash)

# 2) Wire clock + reset (跟 axi_smc 同域 = FCLK_CLK1, proc_sys_reset_0)
#    BD 现状: axi_smc 主 AXI-Lite 时钟是 FCLK_CLK1 (75 MHz), proc_sys_reset_0 同步它.
#    用 FCLK_CLK0 会导致 CLK_DOMAIN / FREQ_HZ mismatch.
catch { connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK1] \
    [get_bd_pins axi_gpio_panel/s_axi_aclk] }
catch { connect_bd_net [get_bd_pins proc_sys_reset_0/peripheral_aresetn] \
    [get_bd_pins axi_gpio_panel/s_axi_aresetn] }

# 3) AXI-Lite control via PS M_AXI_GP0 → axi_smc (现有 smartconnect)
#    BD 里主 AXI-Lite smartconnect 叫 axi_smc (无 _0 后缀); pov 走 sc_pov_axilite, HP 走 axi_smc_hp.
foreach cand {axi_smc axi_smc_0 ps7_0_axi_periph} {
    if {[get_bd_cells -quiet $cand] ne ""} {
        set smc $cand; break
    }
}
if {![info exists smc]} {
    error "no AXI-Lite interconnect found (looked for axi_smc / axi_smc_0 / ps7_0_axi_periph)"
}
puts "using interconnect: $smc"
set cur_mi [get_property CONFIG.NUM_MI [get_bd_cells $smc]]
set new_mi [expr {$cur_mi + 1}]
set_property CONFIG.NUM_MI $new_mi [get_bd_cells $smc]
set new_port [format "M%02d_AXI" $cur_mi]
catch { connect_bd_intf_net [get_bd_intf_pins $smc/$new_port] \
    [get_bd_intf_pins axi_gpio_panel/S_AXI] }

# 4) external ports — connect channel 1/2 GPIO to top-level ports
#    Vivado 把 axi_gpio 的 GPIO interface external 时, port 名自动派生 (panel_gpio_tri_o[17:0])
catch { create_bd_port -dir O -from 17 -to 0 panel_gpio_tri_o }
catch { create_bd_port -dir I -from 0  -to 0 panel_spi_miso_tri_i }

catch { connect_bd_net [get_bd_pins axi_gpio_panel/gpio_io_o] \
    [get_bd_ports panel_gpio_tri_o] }
catch { connect_bd_net [get_bd_pins axi_gpio_panel/gpio2_io_i] \
    [get_bd_ports panel_spi_miso_tri_i] }

# 5) Address map: 分配 axi_gpio_panel/S_AXI 一个 64K offset
catch { assign_bd_address [get_bd_addr_segs axi_gpio_panel/S_AXI/Reg] }

# 6) Save + generate
validate_bd_design
save_bd_design
generate_target all $bd_file

puts "DONE: axi_gpio_panel added.  Next:"
puts "  1) reset_run synth_1 + impl_1, write_bitstream"
puts "  2) export XSA, regen Vitis platform"
puts "  3) 在 xparameters.h 找 XPAR_AXI_GPIO_PANEL_BASEADDR, 替换 led_panel.c 的 LED_PANEL_GPIO_BASE"
exit 0
