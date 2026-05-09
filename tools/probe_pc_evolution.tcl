connect
after 500
targets -set -nocase -filter {name =~ "ARM*#0"}
puts "=== Sample PC at intervals ==="
for {set i 0} {$i < 10} {incr i} {
    stop
    after 100
    puts "T=$i: PC=[rrd pc]"
    con
    after 500
}
stop
after 100
puts "Final PC=[rrd pc]"
puts ""
puts "Disassemble around final PC (16 instrs):"
catch { disassemble [rrd pc] 16 }
exit
