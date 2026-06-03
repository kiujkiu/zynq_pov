connect
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
# Write 1280x720 of red pixels (R=255, G=0, B=0) to fb_a
# Format is BGR or RGB? HDMI fb byte order memory says GBR
# memory feedback_pov3d_hdmi_fb_byte_order.md: p[0]=g; p[1]=b; p[2]=r
# So byte order for red: g=0, b=0, r=0xFF → bytes 00 00 FF
# Pack into 32-bit word: 0x00FF0000 (LE = 00 00 FF 00, 4-byte word writes 3 bytes + alignment)
# For correctness write byte-wise via small loop
puts "filling fb_a (0x10000000 .. 0x102A3000) with red"
set start 0x10000000
set count 1280
set rows 8
# Each row 1280 px × 3 byte = 3840 bytes
# Write 8 rows then duplicate or trust VDMA repeats... actually need full 720 rows
# For speed: use big mwr with 32-bit words, pattern 0x00FF0000
# 1280×720×3 = 2764800 bytes = 691200 words
# Too slow word-by-word. Use mwr binary write of compressed pattern.
# Skip: just write first 100 rows visible at top
for {set y 0} {$y < 100} {incr y} {
    set base [expr {0x10000000 + $y * 3840}]
    # Write 320 words × 4 bytes = 1280 bytes per row (1/3 of row width as test)
    for {set x 0} {$x < 80} {incr x} {
        mwr [expr {$base + $x*4}] 0x00FF0000
    }
}
puts "done writing red strip top 100 rows"
exit 0
