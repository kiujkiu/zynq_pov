###############################################################################
# ICND2047 P3 — GUI build 用的"只准备文件"脚本 (不 launch_runs)
# 用法:
#   1. Vivado GUI 打开 D:\claude_workspace\pov3d\zynq_pov_icnd2047\02_hello_zynq\02_hello_zynq.xpr
#      (开工程时若弹"out-of-date / regenerate"全部选 Yes/OK)
#   2. Tcl Console 里:  source ../tools/setup_icnd_p3.tcl
#   3. 左边 Flow Navigator 点 "Generate Bitstream" (弹窗问要不要先 synth/impl 选 Yes)
#   4. 完成后 bit 在 02_hello_zynq.runs/impl_1/hello_zynq_wrapper.bit
# 为什么 GUI: fresh-checkout worktree 缺 OOC IP 综合产物, GUI 的 Generate Bitstream
#            会自动创建+跑各 IP 的 OOC synth run; batch launch_runs 不会, 一直 black box.
###############################################################################
set WT "D:/claude_workspace/pov3d/zynq_pov_icnd2047"

# 1) ICND2047 IP verilog 入 sources_1
set icnd_src "$WT/02_hello_zynq/02_hello_zynq.srcs/sources_1/imports/hdl/icnd2047_panel_seq.v"
if {[lsearch -exact [get_files] $icnd_src] < 0} {
    add_files -norecurse $icnd_src
    puts "\[setup\] added icnd2047_panel_seq.v"
}
update_compile_order -fileset sources_1

# 2) disable 冲突 XDC (旧直连脚 + led_pins 抢 AB16) + 加 P3 XDC
foreach x {hub75e_pins.xdc led_pins.xdc} {
    set f [get_files -quiet $x]
    if {$f ne ""} { set_property is_enabled false $f ; puts "\[setup\] disabled $x" }
}
set p3xdc "$WT/02_hello_zynq/02_hello_zynq.srcs/constrs_1/new/icnd2047_p3.xdc"
if {[lsearch -exact [get_files] $p3xdc] < 0} {
    add_files -fileset constrs_1 -norecurse $p3xdc
    puts "\[setup\] added icnd2047_p3.xdc"
}
set_property is_enabled true [get_files icnd2047_p3.xdc]

# 3) 重生成 BD 产物 (fresh checkout 缺 .gen). jesd204c 报错可忽略.
catch { generate_target all [get_files hello_zynq.bd] }

puts "==================================================================="
puts " setup 完成. enabled XDC:"
foreach f [get_files -filter {FILE_TYPE==XDC}] {
    puts "   [get_property IS_ENABLED $f]  [file tail $f]"
}
puts " 现在点 Flow Navigator 的 'Generate Bitstream' (弹窗选 Yes 先跑 synth/impl)"
puts " 完成后烧: runs/impl_1/hello_zynq_wrapper.bit ; 测 fps: source tools/v30_test_p3.tcl"
puts "==================================================================="
