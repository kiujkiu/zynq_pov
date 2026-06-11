connect
after 200
targets -set -nocase -filter {name =~ "ARM*#0"}
stop
after 200
puts "ARM halted"
exit 0
