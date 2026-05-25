# bd_add_led_panel_seq.tcl - 加 led_panel_seq IP (PL 端 ICND1069 时序生成器)
#
# 解决 ARM bit-bang DCLK 极限 1.67 MHz, 低于 chip 4 MHz min DCLK 的问题.
# PL 端用 7.5 MHz 精确 DCLK + 严格 LE 计数, 让 ICND1069 PLL 能锁.
#
# BD 改动:
#   1) 加 led_panel_seq Verilog 模块 (module reference)
#   2) AXI-Lite 接 axi_smc (跟 axi_gpio_panel 同 interconnect)
#   3) 输出 dclk_out / le_out / sdi_out[8:0] 接 wrapper port
#   4) 不动 axi_gpio_panel (它的 bit 0/1/3-11 在 XDC 解除映射就行)
#
# XDC 改动 (脚本写完后手动改 led_pins.xdc):
#   删: panel_gpio_tri_o[0]/[1]/[3..11] 的 LOC
#   加: panel_seq_dclk/le/sdi[0..8] 的 LOC

open_project D:/workspace/zynq_pov/02_hello_zynq/02_hello_zynq.xpr
# 切自动 compile order, 不然 module reference 加不进 BD
set_property source_mgmt_mode All [current_project]

# 1) 加 Verilog 文件
set v_file "D:/workspace/zynq_pov/02_hello_zynq/02_hello_zynq.srcs/sources_1/imports/hdl/led_panel_seq.v"
if {[lsearch [get_files] $v_file] < 0} {
    add_files -norecurse $v_file
}
update_compile_order -fileset sources_1

set bd_file [get_files hello_zynq.bd]
open_bd_design $bd_file

# 2) 加 module reference 到 BD
if {[get_bd_cells -quiet led_panel_seq_0] eq ""} {
    create_bd_cell -type module -reference led_panel_seq led_panel_seq_0
}

# 3) 时钟 + 复位 (FCLK_CLK1 = 75 MHz, 跟 axi_gpio_panel 同域)
catch { connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK1] \
    [get_bd_pins led_panel_seq_0/s_axi_aclk] }
catch { connect_bd_net [get_bd_pins proc_sys_reset_0/peripheral_aresetn] \
    [get_bd_pins led_panel_seq_0/s_axi_aresetn] }

# 4) AXI-Lite 接 axi_smc (跟 axi_gpio_panel 同 interconnect)
foreach cand {axi_smc axi_smc_0 ps7_0_axi_periph} {
    if {[get_bd_cells -quiet $cand] ne ""} {
        set smc $cand; break
    }
}
if {![info exists smc]} { error "no AXI-Lite interconnect found" }
puts "using interconnect: $smc"

set cur_mi [get_property CONFIG.NUM_MI [get_bd_cells $smc]]
set new_mi [expr {$cur_mi + 1}]
set_property CONFIG.NUM_MI $new_mi [get_bd_cells $smc]
set new_port [format "M%02d_AXI" $cur_mi]
catch { connect_bd_intf_net [get_bd_intf_pins $smc/$new_port] \
    [get_bd_intf_pins led_panel_seq_0/S_AXI] }

# 5) 创建新 wrapper port 给 PL 端 panel 信号
catch { create_bd_port -dir O panel_seq_dclk }
catch { create_bd_port -dir O panel_seq_le }
catch { create_bd_port -dir O -from 8 -to 0 panel_seq_sdi }

catch { connect_bd_net [get_bd_pins led_panel_seq_0/dclk_out] \
    [get_bd_ports panel_seq_dclk] }
catch { connect_bd_net [get_bd_pins led_panel_seq_0/le_out] \
    [get_bd_ports panel_seq_le] }
catch { connect_bd_net [get_bd_pins led_panel_seq_0/sdi_out] \
    [get_bd_ports panel_seq_sdi] }

# 6) 地址映射
catch { assign_bd_address [get_bd_addr_segs led_panel_seq_0/S_AXI/reg0] }

# 7) 保存 + generate
validate_bd_design
save_bd_design
generate_target all $bd_file
make_wrapper -files [get_files hello_zynq.bd] -top -import -force

puts "DONE: led_panel_seq added."
puts "  New ports: panel_seq_dclk, panel_seq_le, panel_seq_sdi[8:0]"
puts "  Next: update led_pins.xdc (remove LOC for old DCLK/LE/SDI bits,"
puts "        add LOC for new panel_seq_* ports), then synth+impl+bit+XSA"
exit 0
