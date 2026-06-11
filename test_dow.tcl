connect
after 500
targets -set -nocase -filter {name =~ "ARM*#0"}
puts "help dow:"
puts [help dow]
exit 0
