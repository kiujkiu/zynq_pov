connect
after 400
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
puts "CTRL(0x00) = [format 0x%08X [mrd -force -value 0x40020000]]"
puts "ANGLE_PERIOD(0x1C) = [mrd -force -value 0x4002001C]"
puts "N_SLICES(0x20) = [mrd -force -value 0x40020020]"
for {set i 0} {$i < 10} {incr i} {
    set d [mrd -force -value 0x40020024]
    puts "  slice=[expr {$d & 0xFFFF}]  locked=[expr {($d>>23)&1}]  sens_cnt=[mrd -force -value 0x4002002C]"
}
exit 0
