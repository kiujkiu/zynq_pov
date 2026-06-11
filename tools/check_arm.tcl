connect
after 500
targets -set -nocase -filter {name =~ "ARM*#0"}
catch { stop }
puts "ARM PC:"
puts [rrd pc]
puts "ARM SP:"
puts [rrd sp]
puts "ARM status:"
puts [state]
catch { con }
exit 0
