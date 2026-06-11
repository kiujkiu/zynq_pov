connect
after 500
targets -set -nocase -filter {name =~ "ARM*#0"}
puts "VDMA DMACR    (0x43c10000):"
puts [mrd 0x43c10000 1]
puts "VDMA DMASR    (0x43c10004):"
puts [mrd 0x43c10004 1]
puts "VDMA PARK_PTR (0x43c10028):"
puts [mrd 0x43c10028 1]
puts "VDMA FB1 ADDR (0x43c1005c):"
puts [mrd 0x43c1005c 1]
puts "VDMA FB2 ADDR (0x43c10060):"
puts [mrd 0x43c10060 1]
puts "VDMA HSIZE    (0x43c10054):"
puts [mrd 0x43c10054 1]
puts "VDMA FRMDLY_STRIDE (0x43c10058):"
puts [mrd 0x43c10058 1]
puts "VDMA VSIZE    (0x43c10050):"
puts [mrd 0x43c10050 1]
puts "--- Sample fb_A and fb_B rows ---"
puts "fb_A row 0 col 322: 0x10000000 + 322*3 = 0x100003C6"
puts [mrd 0x100003C0 8]
puts "fb_A row 100 col 322: 0x10000000 + 100*3840 + 322*3 = 0x1005EFC6"
puts [mrd 0x1005EFC0 8]
puts "fb_B row 0 col 322: 0x14000000 + 322*3 = 0x140003C6"
puts [mrd 0x140003C0 8]
puts "fb_B row 100 col 322 = 0x1405EFC6"
puts [mrd 0x1405EFC0 8]
exit 0
