connect
after 500
targets -set -nocase -filter {name =~ "ARM*#0"}
puts "PC=[rrd pc]"
puts ""
puts "OCM @ 0x00000000 (BootROM expects FSBL loaded here):"
puts [mrd 0x00000000 8]
puts ""
puts "OCM @ 0x00100000 (alt FSBL load, also DDR start) :"
puts [mrd 0x00100000 8]
puts ""
puts "DDR @ 0x10000000 (BOOT.bin staging area I used):"
puts [mrd 0x10000000 8]
puts ""
puts "REBOOT_STATUS reg @ 0xF8000258 (boot result):"
puts [mrd -value 0xF8000258]
puts ""
puts "BOOT_MODE reg:"
puts [mrd -value 0xF8000A1C]
exit
