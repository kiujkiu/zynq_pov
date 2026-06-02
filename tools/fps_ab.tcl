# Measure fps in both modes via STATUS frame_count delta
connect
after 300
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1

proc measure_fps {label ctrl} {
    mwr 0x40020000 $ctrl
    after 500
    set s0 [mrd -value 0x4002000C]
    after 1000
    set s1 [mrd -value 0x4002000C]
    set f0 [expr {($s0 >> 16) & 0xFFFF}]
    set f1 [expr {($s1 >> 16) & 0xFFFF}]
    set delta [expr {($f1 - $f0) & 0xFFFF}]
    puts "$label CTRL=[format 0x%x $ctrl] fps=$delta (STATUS=[format 0x%08x $s1])"
}

# TUNIT preserved from outside (don't overwrite)

measure_fps "SERIAL " 0x521
measure_fps "OVERLAP" 0x561
measure_fps "SERIAL " 0x521 ; # repeat to check stability
measure_fps "OVERLAP" 0x561

exit 0
