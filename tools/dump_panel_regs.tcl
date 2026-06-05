# Dump all panel registers + cycle COLOR manually to isolate R-only issue
connect
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
set BASE 0x40010000
puts "===== current regs ====="
puts "CTRL    [mrd -force $BASE 1]"
puts "COLOR_T [mrd -force [expr {$BASE + 0x4}] 1]"
puts "PARAM   [mrd -force [expr {$BASE + 0x8}] 1]"
puts "STATUS  [mrd -force [expr {$BASE + 0xC}] 1]"
puts "COLOR_B [mrd -force [expr {$BASE + 0x10}] 1]"
puts "TUNIT   [mrd -force [expr {$BASE + 0x14}] 1]"

# Try set pure RED then read back
puts "===== test write+read COLOR ====="
mwr -force [expr {$BASE + 0x4}] 0x0000003F
mwr -force [expr {$BASE + 0x10}] 0x0000003F
after 100
puts "after write 0x3F (R only): COLOR_T [mrd -force [expr {$BASE + 0x4}] 1]"
puts "                           COLOR_B [mrd -force [expr {$BASE + 0x10}] 1]"

mwr -force [expr {$BASE + 0x4}] 0x00003F00
mwr -force [expr {$BASE + 0x10}] 0x00003F00
after 100
puts "after write 0x3F00 (G only): COLOR_T [mrd -force [expr {$BASE + 0x4}] 1]"

mwr -force [expr {$BASE + 0x4}] 0x003F0000
mwr -force [expr {$BASE + 0x10}] 0x003F0000
after 100
puts "after write 0x3F0000 (B only): COLOR_T [mrd -force [expr {$BASE + 0x4}] 1]"

# Leave at pure GREEN for waveform check
mwr -force [expr {$BASE + 0x4}] 0x00003F00
mwr -force [expr {$BASE + 0x10}] 0x00003F00
puts "FINAL: COLOR set to 0x00003F00 (pure GREEN), only G[15:8] bit 0-5 set"
puts "expected: panel.1/panel.5 (G chip via AA22/AB21) → high duty"
puts "          panel.2/panel.6 (R chip via AB22/Y20)  → 0"
puts "          panel.3/panel.7 (B chip via AA21/Y21)  → 0"
exit 0
