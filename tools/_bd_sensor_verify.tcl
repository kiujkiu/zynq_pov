open_project 02_hello_zynq.xpr
open_bd_design [get_files hello_zynq.bd]
# 干净重建 external port 连接
set ipin [get_bd_pins hub75e_panel_seq_0/sensor_pulse]
# 删现有 net + port 重来
set oldnet [get_bd_nets -quiet -of_objects $ipin]
if {$oldnet ne ""} { delete_bd_objs $oldnet }
catch { delete_bd_objs [get_bd_ports -quiet sensor_pulse] }
create_bd_port -dir I sensor_pulse
connect_bd_net [get_bd_ports sensor_pulse] $ipin
validate_bd_design
save_bd_design
# 强制 regen
reset_target all [get_files hello_zynq.bd]
generate_target all [get_files hello_zynq.bd]
make_wrapper -files [get_files hello_zynq.bd] -top -force
update_compile_order -fileset sources_1
# 关键: dump 生成后 BD HDL 里 sensor 接什么
puts "=========== SENSOR HDL CHECK ==========="
set hdldir "D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq/02_hello_zynq.gen/sources_1/bd/hello_zynq"
foreach f [glob -nocomplain $hdldir/synth/*.v $hdldir/hdl/*.v $hdldir/ip/*/synth/*.v] {
    set fp [open $f r]; set txt [read $fp]; close $fp
    if {[string match "*sensor_pulse*" $txt]} {
        puts "FOUND sensor_pulse in: [file tail $f]"
    }
}
puts "========================================"
