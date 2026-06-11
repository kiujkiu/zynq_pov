connect
after 500
targets -set -nocase -filter {name =~ "ARM*#0"}
for {set i 0} {$i < 8} {incr i} {
    set pc [rrd pc]
    puts "PC iter $i: $pc"
    after 100
}
exit 0
