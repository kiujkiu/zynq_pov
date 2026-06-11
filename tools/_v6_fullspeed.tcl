connect
after 800
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
mwr -force 0x4002001C 25590    ; # 2931 slice/s
after 500
set d1 [mrd -force -value 0x40020024]
set t1 [clock milliseconds]
after 2000
set d2 [mrd -force -value 0x40020024]
set t2 [clock milliseconds]
set s1 [expr {$d1 & 0xFFFF}]
set s2 [expr {$d2 & 0xFFFF}]
set err [expr {($d2 >> 28) & 0xF}]
puts "err_cnt=$err dma_state=[expr {($d2>>24)&0xF}]"
# slice 推进速率: (s2-s1+8k*n)/dt — slice 0..7 wrap 太快没法直接数, 看 STATUS 帧率
set f1 [mrd -force -value 0x4002000C]
after 2000
set f2 [mrd -force -value 0x4002000C]
set df [expr {(($f2>>16)-($f1>>16)) & 0xFFFF}]
puts "panel fps=[expr {$df/2}] (display 没被 DMA 拖慢 = 通过)"
exit 0
