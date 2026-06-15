open_project 02_hello_zynq.xpr
# 关增量综合 (强制全综合, 不复用旧 dcp)
catch { set_property AUTO_INCREMENTAL_CHECKPOINT 0 [get_runs synth_1] }
catch { set_property AUTO_INCREMENTAL_CHECKPOINT 0 [get_runs impl_1] }
catch { set_property INCREMENTAL_CHECKPOINT "" [get_runs synth_1] }
catch { reset_property INCREMENTAL_CHECKPOINT [get_runs synth_1] }
catch { reset_property AUTO_INCREMENTAL_CHECKPOINT [get_runs synth_1] }
# 删 utils 里的增量参考 dcp
catch {
    foreach f [get_files -quiet *hello_zynq_wrapper.dcp] {
        if {[string match "*utils_1*" $f]} { remove_files $f }
    }
}
puts "\[INFO\] incremental synth disabled"
reset_run synth_1
reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_runs impl_1
set st [get_property STATUS [get_runs impl_1]]
puts "\[INFO\] impl_1 STATUS = $st"
puts "\[CHECK\] [exec grep -c {sensor_pulse} [get_property DIRECTORY [get_runs impl_1]]/hello_zynq_wrapper_io_placed.rpt]"
if {[string match "*write_bitstream Complete*" $st]} {
    write_hw_platform -fixed -include_bit -force -file [file normalize "../hello_plat/hw/hello_zynq.xsa"]
    puts "\[INFO\] no-incr xsa exported"
}
