connect
after 200
targets -set -nocase -filter {name =~ "ARM*#0"}
stop
after 200
mwr 0x001181d4 30803
after 100
con
exit
