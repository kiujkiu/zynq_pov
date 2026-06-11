# 无限循环 8 色, 每色 2 秒
# Ctrl-C 停止 (或 xsdb 进程被 kill)
connect
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1

set BASE 0x40010000

# Set FCLK1 = 60M (DCLK 30M, spec-compliant)
mwr -force $BASE 0
after 50
mwr -force 0xF8000180 0x00600500
after 50
mwr -force [expr {$BASE + 0x14}] 0x00000001
mwr -force [expr {$BASE + 0x8}]  127

# 8 色: BBGGRR (each 6-bit, dim 0x10)
set colors [list \
    "RED     0x00000010" \
    "GREEN   0x00001000" \
    "BLUE    0x00100000" \
    "YELLOW  0x00001010" \
    "MAGENTA 0x00100010" \
    "CYAN    0x00101000" \
    "WHITE   0x00101010" \
    "BLACK   0x00000000" \
]

puts "INFINITE 8-color cycle started. Ctrl-C / kill xsdb to stop."
set round 0
while {1} {
    incr round
    puts "--- round $round ---"
    foreach pair $colors {
        set name [lindex $pair 0]
        set val  [lindex $pair 1]
        mwr -force [expr {$BASE + 0x4}]  $val
        mwr -force [expr {$BASE + 0x10}] $val
        mwr -force $BASE 0x501
        puts "  $name  $val"
        after 2000
    }
}
