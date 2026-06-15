# 高速采样: 连一次, 紧循环狂读 slice_idx, 记录 min/max/变化次数, 抓手转的短暂窗口
connect
after 500
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
set c0 [mrd -force -value 0x4002002C]
set smin 99999
set smax -1
set changes 0
set prev -1
set revmin 4294967295
for {set i 0} {$i < 4000} {incr i} {
    set dbg [mrd -force -value 0x40020024]
    set s [expr {$dbg & 0xFFFF}]
    if {$s != $prev} { incr changes; set prev $s }
    if {$s < $smin} { set smin $s }
    if {$s > $smax} { set smax $s }
    set rp [mrd -force -value 0x40020028]
    if {$rp < $revmin} { set revmin $rp }
}
set c1 [mrd -force -value 0x4002002C]
puts "RESULT: slice min=$smin max=$smax changes=$changes  | sens_cnt $c0 -> $c1 (+[expr {$c1-$c0}])  | rev_period_min=$revmin"
exit 0
