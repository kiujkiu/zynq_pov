# 角度跟踪测试: sensor_en=1, 持续读 rev_period + locked + slice_idx
# 用法: 接好光电开关到转接板 P4, 跑这个, 手动挡光/转动看数值变化
connect
after 800
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
# 假设切片已加载+DMA在跑 (CTRL 已是 0x45E1 之类). 只切 sensor_en (bit15)
set ctrl [mrd -force -value 0x40020000]
set ctrl [expr {$ctrl | 0x8000}]   ; # set bit15 sensor_en
mwr -force 0x40020000 $ctrl
puts "sensor_en=1, CTRL=[format 0x%X $ctrl]. 手动挡光/转动光电开关..."
puts "时间   slice  locked  rev_period(cyc)  转速(rps@85.7M)"
for {set i 0} {$i < 40} {incr i} {
    set d [mrd -force -value 0x40020024]
    set rp [mrd -force -value 0x40020028]
    set slice [expr {$d & 0xFFFF}]
    set lk [expr {($d >> 23) & 1}]
    set rps "—"
    if {$rp > 0} { set rps [format %.2f [expr {85714285.0 / $rp}]] }
    puts "[format %3d $i]    [format %4d $slice]   $lk      $rp     $rps"
    after 500
}
disconnect
