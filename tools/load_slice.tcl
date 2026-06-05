# Load single slice (slice_top.bin + slice_bot.bin) to PL BRAM + 配 use_fb mode
# 假设之前已 extract_slice.py 生成 slice_top.bin / slice_bot.bin (16 KB each)
connect
after 300
targets -set -nocase -filter {name =~ "ARM*#0"}
catch { stop }
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1

# disable panel during BRAM write
mwr -force 0x40020000 0
after 200

# panel_slice_gen layout: y 0..31 = head 16KB → goes to bot bank 0x4002C000 (panel 物理拼接反)
# y 32..63 = next 16KB → goes to top bank 0x40028000
puts "load slice_top.bin → 0x4002C000..."
mwr -bin -file "D:/claude_workspace/pov3d/zynq_pov/slice_top.bin" -size w 0x4002C000 4096
puts "load slice_bot.bin → 0x40028000..."
mwr -bin -file "D:/claude_workspace/pov3d/zynq_pov/slice_bot.bin" -size w 0x40028000 4096

# Re-enable panel: 3-bit BCM, t_unit=8, use_fb, overlap
mwr -force 0x40020008 127       ; # width_max=127 → 128 col
mwr -force 0x40020014 0x00000308 ; # planes_n=3, t_unit=8
mwr -force 0x40020000 0x561     ; # en | mode 0 | addr_bits=5 | use_fb | overlap
after 300
puts "CTRL [mrd -force 0x40020000 1]"
puts "TUNIT [mrd -force 0x40020014 1]"
puts "STATUS [mrd -force 0x4002000C 1]"
exit 0
