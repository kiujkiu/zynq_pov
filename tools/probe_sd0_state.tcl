connect
after 200
targets -set -nocase -filter {name =~ "ARM*#0"}
puts "=== SD0 controller @ 0xE0100000 ==="
puts "Present State Reg (0x24): [mrd -value 0xE0100024]"
puts "  bit16 = SD_CARD_INSERT"
puts "  bit17 = SD_CARD_STABLE"
puts "  bit18 = SD_CARD_DETECT_PIN_LEVEL"
puts "  bit19 = WP_PIN_LEVEL"
puts ""
puts "Host Control 1 (0x28): [mrd -value 0xE0100028]"
puts "Power Control  (0x29 byte): [mrd -value 0xE0100029]"
puts "Clock Control  (0x2C): [mrd -value 0xE010002C]"
puts ""
puts "Software Reset (0x2F byte): [mrd -value 0xE010002F]"
puts ""
puts "Capabilities  (0x40): [mrd -value 0xE0100040]"
con
exit
