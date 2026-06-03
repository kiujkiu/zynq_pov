connect
after 500
targets -set -nocase -filter {name =~ "ARM*#0"}
catch { con }
puts "ARM resumed"
exit 0
