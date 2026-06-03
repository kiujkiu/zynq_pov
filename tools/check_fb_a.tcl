connect
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
puts "fb_a (0x10000000) first 32 bytes:"
mrd 0x10000000 8
puts "fb_a + 0x1000:"
mrd 0x10001000 4
puts "ANIME_MAGIC + count:"
mrd 0x1F000000 2
puts "MODEL_ADDR first:"
mrd 0x1A000000 4
exit 0
