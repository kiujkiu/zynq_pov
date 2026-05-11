connect
after 200
targets -set -nocase -filter {name =~ "ARM*#0"}
puts "model_n @ 0x001181d4: [mrd -value 0x001181d4]"
puts "mesh_ready @ 0x00118254: [mrd -value 0x00118254]"
puts "mesh_n_verts @ 0x001181dc: [mrd -value 0x001181dc]"
puts "mesh_n_tris @ 0x00118250: [mrd -value 0x00118250]"
puts ""
puts "model[0] @ 0x1A000000: [mrd 0x1A000000 4]"
puts ""
puts "CPU0 PC: [rrd pc]"
# Don't reset — leave running
con
exit
