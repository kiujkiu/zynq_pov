# Connect to running ARM, halt CPU, write panel_seq CMD register with marker_ROW + 12 DCLK
# This should make AA19 go high for ~12 DCLK if PL IP has row support
connect
after 500
targets -set -nocase -filter {name =~ "ARM*#0"}

# Don't stop CPU. Use -force to bypass memory map check
mwr -force 0x40010004 10000
puts "burst_reg = 10000"
mwr -force 0x40010000 0x020C0000
puts "Fired burst 10001 ROW(12 DCLK) on AA19"
after 5000

# Resume CPU
catch { con }
puts "ARM resumed"
exit 0
