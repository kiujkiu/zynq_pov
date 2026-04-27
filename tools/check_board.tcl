puts "CHECK: connect"
connect
puts "CHECK: target list ---"
puts [targets]
puts "CHECK: ----"
# try to set ARM#0 and read PC
if {[catch {targets -set -nocase -filter {name =~ "ARM*#0"}} err]} {
    puts "CHECK: cannot set ARM#0: $err"
} else {
    puts "CHECK: ARM#0 selected"
    if {[catch {set pc [rrd pc]} err]} {
        puts "CHECK: rrd pc failed: $err"
    } else {
        puts "CHECK: PC = $pc"
    }
    # peek state
    if {[catch {set st [state]} err]} {
        puts "CHECK: state failed: $err"
    } else {
        puts "CHECK: state = $st"
    }
}
exit 0
