connect
after 200
targets -set -nocase -filter {name =~ "ARM*#0"}
catch { stop }
rrd pc
puts "---backtrace---"
catch { bt }
exit 0
