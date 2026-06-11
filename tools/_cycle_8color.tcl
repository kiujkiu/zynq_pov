# 8 色循环, 每色 3 秒, 5 圈
connect
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1

set BASE 0x40010000
mwr -force 0xF8000180 0x00500500
after 200
mwr -force $BASE 0
after 100
mwr -force [expr {$BASE + 0x14}] 0x00000001
mwr -force [expr {$BASE + 0x8}] 127

# COLOR fmt: 0x00_BB_GG_RR  (each 6-bit)
set colors [list \
    "RED     0x0000003F" \
    "GREEN   0x00003F00" \
    "BLUE    0x003F0000" \
    "YELLOW  0x00003F3F" \
    "MAGENTA 0x003F003F" \
    "CYAN    0x003F3F00" \
    "WHITE   0x003F3F3F" \
    "BLACK   0x00000000" \
]

for {set round 0} {$round < 5} {incr round} {
    puts "--- round [expr {$round+1}] ---"
    foreach pair $colors {
        set name [lindex $pair 0]
        set val  [lindex $pair 1]
        mwr -force [expr {$BASE + 0x4}]  $val
        mwr -force [expr {$BASE + 0x10}] $val
        mwr -force $BASE 0x501
        puts "  $name  $val"
        after 3000
    }
}
puts "done"
exit 0
