# 单次读全部调试寄存器
connect
after 400
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
set d24 [mrd -force -value 0x40020024]
set d28 [mrd -force -value 0x40020028]
set d2c [mrd -force -value 0x4002002C]
set d30 [mrd -force -value 0x40020030]
puts "0x24 dma_status = [format 0x%08X $d24]  (slice_idx=[expr {$d24 & 0xFFFF}], locked=[expr {($d24>>23)&1}])"
puts "0x28 rev_period = $d28"
puts "0x2C sens_dbg   = [format 0x%08X $d2c]  (raw_lvl=[expr {($d2c>>31)&1}], pulse_cnt=[expr {$d2c & 0xFFFF}])"
puts "0x30 trk_dbg    = [format 0x%08X $d30]  (locked_ever=[expr {($d30>>31)&1}], slice_max=[expr {$d30 & 0xFFFF}])"
exit 0
