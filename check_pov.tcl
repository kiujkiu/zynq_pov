connect
after 500
targets -set -nocase -filter {name =~ "ARM*#0"}
# These are PL AXI-Lite slave regs, can't be read from xsdb if PS blocks
# But try anyway with -force
puts "POV_BASE = 0x43C20000"
puts "BATCH_MODEL_LO (offset 0x10):"
puts [mrd -force 0x43C20010 1]
puts "BATCH_NUM_POINTS (offset 0x1c):"
puts [mrd -force 0x43C2001c 1]
exit 0
