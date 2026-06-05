# Scan typical PS AXI ranges to find panel new base addr
connect
after 300
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
# Common addresses to test: 0x40000000-0x80000000 in 64K stride
for {set b 0x40000000} {$b < 0x80000000} {incr b 0x10000} {
    set rv [catch {mrd -force $b 1} out]
    if {$rv == 0 && [string match "*:* *" $out]} {
        # Got valid read; try writing CTRL=0 to detect panel (panel CTRL[0]=enable, mode=0)
        # Skip dangerous addresses
        puts "$b: $out"
    }
}
exit 0
