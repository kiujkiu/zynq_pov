connect
after 200
targets -set -nocase -filter {name =~ "ARM*#0"}
puts "g_initialized @ 0x00413584: [mrd -value 0x00413584]"
puts "g_rca         @ 0x00413580: [mrd -value 0x00413580]"
puts "sdio_bridge_active @ 0x0011c300: [mrd -value 0x0011c300]"
puts ""
puts "SD0 Present State (0xE0100024): [mrd -value 0xE0100024]"
puts "SD0 Host Ctrl 1   (0xE0100028): [mrd -value 0xE0100028]"
con
exit
