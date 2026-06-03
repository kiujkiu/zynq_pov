connect
after 500
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
puts "v_tc @ 0x43C00000 registers:"
puts "  CTRL (0x000)        = [mrd -force 0x43C00000 1]"
puts "  GLB_IRQ_EN (0x004)  = [mrd -force 0x43C00004 1]"
puts "  ERROR (0x010)       = [mrd -force 0x43C00010 1]"
puts "  GENERATOR_ENABLE (0x00C) = [mrd -force 0x43C0000C 1]"
puts "  GEN_HSIZE (0x060)   = [mrd -force 0x43C00060 1]"
puts "  GEN_VSIZE (0x064)   = [mrd -force 0x43C00064 1]"
puts "  GEN_ACTIVE (0x068)  = [mrd -force 0x43C00068 1]"
puts "  GEN_H_SYNC (0x070)  = [mrd -force 0x43C00070 1]"
puts "  GEN_V_BLANK_H (0x074) = [mrd -force 0x43C00074 1]"
puts "  GEN_V_SYNC_V (0x078) = [mrd -force 0x43C00078 1]"
exit 0
