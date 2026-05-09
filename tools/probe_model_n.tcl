connect
after 200
targets -set -nocase -filter {name =~ "ARM*#0"}
# model_n 是 BSS 的全局变量, 找符号在 elf 里. 但 xsdb 不直接 nm,
# 用约定: model_n 在 .bss 区, 通过 elf 解析或 mrd 已知 addr.
# 暂用 /tmp/dl_helloworld_pid.txt 那种法. 这里直接 mrd MODEL_ADDR
# 第 0 个 PovPoint (16 bytes) 看是否有 sample p0 的内容
puts "model[0..3] @ 0x1A000000:"
puts [mrd 0x1A000000 4]
puts ""
# Also check first few mesh_verts
puts "mesh_verts[0..3] @ 0x12000000:"
puts [mrd 0x12000000 4]
puts ""
# CPU0 PC
puts "CPU0 PC = [rrd pc]"
exit
