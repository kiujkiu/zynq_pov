connect
after 500
targets -set -nocase -filter {name =~ "ARM*#0"}
# model_n at 0x0011c25c per nm
puts "model_n:"
puts [mrd 0x0011c25c 1]
puts "rx_pts_done @ symbol:"
exit 0
