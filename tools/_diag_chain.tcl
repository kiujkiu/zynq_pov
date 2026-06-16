# 诊断全芯片链: 点云头 + grid 中心 + slice 非零扫描 (板 live, 只读)
connect
after 500
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
puts "magic=[format 0x%08X [mrd -force -value 0x16000000]] count=[mrd -force -value 0x16000004]"
# grid 中心区 voxel (64,64,64): idx=((64*128+64)*128+64)=1056832, *4=0x40A100
puts "grid center voxels @0x1C40A000: [mrd -force 0x1C40A000 8]"
# 扫 grid: 抽样 4096 voxel (每 512 取一个), 数非零
set gnz 0
for {set i 0} {$i < 4096} {incr i} {
    set a [expr {0x1C000000 + $i*512*4}]
    if {[mrd -force -value $a] != 0} { incr gnz }
}
puts "grid 抽样 4096 voxel 非零: $gnz"
# slice0 + slice180 整片非零 word 数
foreach s {0 90 180 270} {
    set base [expr {0x18000000 + $s*0x2000}]
    set nz 0
    set vals [mrd -force $base 2048]
    foreach line $vals { foreach tok $line { if {[string match "*:" $tok]} continue; if {$tok ne "" && $tok ne "00000000"} { incr nz } } }
    puts "slice $s 非零 word: $nz / 2048"
}
exit 0
