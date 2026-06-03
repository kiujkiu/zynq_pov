connect
after 500
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
puts "PS7 SLCR clock state:"
puts "  0xF8000170 FPGA0_CLK_CTRL = [mrd -force 0xF8000170 1]"
puts "  0xF8000180 FPGA1_CLK_CTRL = [mrd -force 0xF8000180 1]"
puts "  0xF8000190 FPGA2_CLK_CTRL = [mrd -force 0xF8000190 1]"
puts "  0xF80001A0 FPGA3_CLK_CTRL = [mrd -force 0xF80001A0 1]"
puts "  0xF800010C PLL_STATUS     = [mrd -force 0xF800010C 1]"
puts "  0xF8000128 DCI_CLK_CTRL   = [mrd -force 0xF8000128 1]"
puts ""
puts "VDMA park_ptr (which fb active now):"
puts "  0x43C10028 = [mrd -force 0x43C10028 1]"
puts ""
puts "Reading vsync count (8 quick samples to see if v_tc is actually clocking):"
for {set i 0} {$i < 8} {incr i} {
    after 100
    set frame_cnt [mrd -force 0x43C00024 1]
    set vtc_err  [mrd -force 0x43C00010 1]
    puts "  t=${i}: GEN_DET_STATUS=$frame_cnt  ERROR=$vtc_err"
}
exit 0
