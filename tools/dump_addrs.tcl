connect
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
set fb0 [mrd -value 0x10000000]
set fb1 [mrd -value 0x10000100]
set fb_mid [mrd -value 0x10100000]
set mag [mrd -value 0x1F000000]
set cnt [mrd -value 0x1F000004]
set mod [mrd -value 0x1A000000]
puts "fb_a0=[format 0x%08x $fb0] fbm=[format 0x%08x $fb_mid]"
puts "MAGIC=[format 0x%08x $mag] cnt=$cnt MOD=[format 0x%08x $mod]"
exit 0
