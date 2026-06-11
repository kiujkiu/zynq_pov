connect
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
puts "--- panel 1 fb_top @ 0x4002C000 first 4 words ---"
mrd 0x4002C000 4
puts "--- panel 1 fb_bot @ 0x40028000 first 4 words ---"
mrd 0x40028000 4
puts "--- panel 2 fb_top @ 0x4003C000 first 4 words ---"
mrd 0x4003C000 4
puts "--- panel 2 fb_bot @ 0x40038000 first 4 words ---"
mrd 0x40038000 4
exit 0
