connect
after 800
targets -set -nocase -filter {name =~ "ARM*#0"}
catch { stop }
puts "FROZEN"
exit 0
