connect
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
puts "VDMA MM2S CR (0x43C10000) = [mrd 0x43C10000]"
puts "VDMA MM2S SR (0x43C10004) = [mrd 0x43C10004]"
puts "VDMA MM2S Park (0x43C10028) = [mrd 0x43C10028]"
puts "VDMA MM2S Vsize (0x43C10050) = [mrd 0x43C10050]"
puts "VDMA MM2S Hsize (0x43C10054) = [mrd 0x43C10054]"
puts "VDMA MM2S Stride (0x43C10058) = [mrd 0x43C10058]"
puts "VDMA MM2S StartAddr0 (0x43C1005C) = [mrd 0x43C1005C]"
exit 0
