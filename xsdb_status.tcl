connect
after 500
targets
targets -set -nocase -filter {name =~ "ARM*#0"}
set pc [rrd pc]
puts "pc=$pc"
state
exit 0
