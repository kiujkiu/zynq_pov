# PL 已 disable. 不动 bit, 直接走 PL register 切几个 mode 看效果.
connect
after 500
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
after 200

proc try_mode {label tunit ctrl wait_s} {
    puts ""
    puts "=== $label  TUNIT=$tunit CTRL=$ctrl ==="
    mwr 0x40020014 $tunit
    mwr 0x40020000 $ctrl
    after 300
    puts "STATUS = [mrd 0x4002000C]"
    after [expr {$wait_s * 1000}]
}

# CTRL bits: [0]=en [3:1]=mode [4]=addr_sr [5]=use_fb [12:8]=addr_bits

# mode 7 FULL WHITE
try_mode "FULL_WHITE_t16" 16 0x50F 6

# mode 6 GRADIENT
try_mode "GRADIENT_t32"   32 0x50D 8

# mode 1 HSTRIPE 8-color by row
try_mode "HSTRIPE_t32"    32 0x503 6

# mode 2 VSTRIPE 8-color by col
try_mode "VSTRIPE_t32"    32 0x505 6

# mode 3 CHECKER
try_mode "CHECKER_t32"    32 0x507 6

# back to disable
puts ""
puts "=== DISABLE (panel goes dark) ==="
mwr 0x40020000 0
after 300

exit 0
