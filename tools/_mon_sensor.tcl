# 监控 sensor: 连续读 sens_cnt(0x2C) + rev_period(0x28) + slice_idx, 看脉冲是否到达 FPGA
connect
after 500
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
for {set i 0} {$i < 16} {incr i} {
    set cnt [mrd -force -value 0x4002002C]
    set rev [mrd -force -value 0x40020028]
    set dbg [mrd -force -value 0x40020024]
    set slice [expr {$dbg & 0xFFFF}]
    puts "[format %2d $i]: sens_cnt=$cnt  rev_period=$rev  slice=$slice"
    after 600
}
exit 0
