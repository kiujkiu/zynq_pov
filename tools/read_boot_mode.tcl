connect
after 500
targets -set -nocase -filter {name =~ "ARM*#0"}
# Don't reset — preserve power-on latched BOOT_MODE register
set v [mrd -value 0xF8000A1C]
puts ""
puts "BOOT_MODE register (0xF8000A1C) = [format 0x%08X $v]"
set bm [expr {$v & 0xF}]
puts "Boot mode pins MIO[5:3] = [format 0x%X [expr {$bm & 0x7}]]  (bit3 JTAG = [expr {($v >> 3) & 1}])"
switch [expr {$bm & 0x7}] {
  0 { puts "= JTAG"  }
  1 { puts "= Quad-SPI 24-bit"  }
  2 { puts "= NAND 8-bit"  }
  4 { puts "= NOR"  }
  6 { puts "= SD"  }
  7 { puts "= JTAG cascade"  }
  default { puts "= reserved/unknown"  }
}
exit
