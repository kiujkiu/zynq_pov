connect
after 500
targets -set -nocase -filter {name =~ "ARM*#0"}
stop
after 100
puts "ARM halted at:"
set pc [rrd pc]
puts $pc
puts ""
puts "POV_AP_CTRL (with -force):"
puts [mrd -force 0x43C20000 1]
puts "POV_AP_CTRL read AGAIN (might clear bits):"
puts [mrd -force 0x43C20000 1]
puts ""
puts "Ring slot 0 head 32 bytes after halt:"
puts [mrd 0x12000000 8]
puts ""
puts "Test: fire AP_CTRL=1 manually and wait, see if HLS responds"
mwr -force 0x43C20000 0x1
after 10
puts "After fire, AP_CTRL = [mrd -force 0x43C20000 1]"
# Wait up to 1 sec
for {set i 0} {$i < 100} {incr i} {
    after 10
    set v [mrd -force 0x43C20000 1]
    if {[regexp {([0-9A-F]+):\s+([0-9A-F]+)} $v match addr val]} {
        set hex 0x$val
        if {[expr {$hex & 2}]} {
            puts "ap_done detected at iter $i, AP_CTRL=$val"
            break
        }
    }
}
puts "Final AP_CTRL: [mrd -force 0x43C20000 1]"
puts "Ring slot 0 after fire:"
puts [mrd 0x12000000 8]
con
exit 0
