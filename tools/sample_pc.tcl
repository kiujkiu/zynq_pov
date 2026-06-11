connect
after 500
targets -set -nocase -filter {name =~ "ARM*#0"}
for {set i 0} {$i < 8} {incr i} {
    after 200
    catch { stop } _
    set p [lindex [rrd pc] 1]
    catch { con } _
    puts "pc[$i] = $p"
}
exit 0
