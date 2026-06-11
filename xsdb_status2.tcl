connect
after 500
targets -set -nocase -filter {name =~ "ARM*#0"}
for {set i 0} {$i < 5} {incr i} {
    set pc [rrd pc]
    puts "iter $i: $pc"
    after 200
}
exit 0
