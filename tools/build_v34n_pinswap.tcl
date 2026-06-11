# v34n: 仅 XDC pin-swap (panel1↔panel2 全部引脚互换), RTL/BD 不变
# 只重跑 impl (synth 结果仍有效), ~5 min
open_project 02_hello_zynq.xpr
puts "\[INFO\] project opened, impl-only rebuild for pin swap"

reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_runs impl_1

set imp_status [get_property STATUS [get_runs impl_1]]
puts "\[INFO\] impl_1 STATUS = $imp_status"
if {[string match "*write_bitstream Complete*" $imp_status]} {
    write_hw_platform -fixed -include_bit -force -file [file normalize "../hello_plat/hw/hello_zynq.xsa"]
    puts "\[INFO\] v34n pin-swap xsa exported"
} else {
    puts "\[ERROR\] impl_1 未完成: $imp_status"
}
