connect
after 500
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
# Stop ARM via ARM*#0 target
targets -set -nocase -filter {name =~ "ARM*#0"}
catch { stop }
after 300
# Back to APU for AXI memory write
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
puts "writing pure R (0x0000003F) to panel BRAM..."
for {set i 0} {$i < 4096} {incr i} {
    mwr [expr {0x4002C000 + $i * 4}] 0x0000003F
    mwr [expr {0x40028000 + $i * 4}] 0x0000003F
}
puts "done. panel should be solid R now"
exit 0
