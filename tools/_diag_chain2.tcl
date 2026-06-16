# 确认路线A: grid 用互质步进(1009)重扫 + 中心区块 + slice 非零. 板 live 只读.
connect
after 500
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
puts "magic=[format 0x%08X [mrd -force -value 0x16000000]] count=[mrd -force -value 0x16000004]"
# grid: 步进 1009 voxel (与128互质, vz 遍历), 抽 8000 个数非零
set gnz 0
for {set i 0} {$i < 8000} {incr i} {
    set a [expr {0x1C000000 + ($i*1009 % 2097152)*4}]
    if {[mrd -force -value $a] != 0} { incr gnz }
}
puts "grid 互质抽样 8000 voxel 非零: $gnz (>0 = ARM 体素化真填了 grid)"
# 中心区块 (vx=64,vy=64, vz 44..83 anime 有内容): idx (64*128+64)*128+vz
set cnz 0
for {set vz 40} {$vz < 88} {incr vz} {
    set idx [expr {(64*128+64)*128+$vz}]
    if {[mrd -force -value [expr {0x1C000000+$idx*4}]] != 0} { incr cnz }
}
puts "中心列 (64,64,vz40-88) 非零 voxel: $cnz"
# slice 非零总数
foreach s {0 180} {
    set base [expr {0x18000000 + $s*0x2000}]
    set nz 0
    foreach line [mrd -force $base 2048] { foreach t $line { if {[string match "*:" $t]} continue; if {$t ne "" && $t ne "00000000"} { incr nz } } }
    puts "slice $s 非零 word: $nz / 2048"
}
exit 0
