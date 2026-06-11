connect
after 500
targets -set -nocase -filter {name =~ "ARM*#0"}
stop
puts "Halt ARM. Writing solid red pattern to fb_A entire frame..."
# Write a solid red (or some recognizable) pattern. ARM stays halted.
# fb_A is 720*3840 = 2764800 bytes. Use 16-byte aligned write.
# 0xFF000000 LE bytes: 00 00 00 FF → mostly black with red byte every 4
# Better: 0x00FF0000 in HDMI GBR maps to G=255, B=0, R=0 = bright green
# Or use 0xFFFFFFFF for white everywhere.
# Use values to fill 256 words of 0xFFFFFFFF starting at top-left
# Note: writes are at 4-byte boundary, so 256 words = 1024 bytes = ~341 px
# Better to write a larger region. Let's do 4096 words at top of fb.
mwr 0x10000000 0xFFFFFFFF 65536
# Verify
puts "fb_A row 0: [mrd 0x10000000 4]"
puts "fb_A row 50 (0x1002EE00): [mrd 0x1002EE00 4]"
puts "Leaving ARM HALTED - capture HDMI now"
exit 0
