###############################################################################
# ICND2047 on MTR transboard P3 (panel 2) build
# worktree: D:/claude_workspace/pov3d/zynq_pov_icnd2047 (branch debug/icnd2047-mtr-p3)
# - 复用 v30 ICND2047 IP (hub75e_panel_seq_v2 = icnd2047_panel_seq.v)
# - 脚映射换成 icnd2047_p3.xdc (P3/panel2), disable 旧 hub75e_pins.xdc + led_pins.xdc
# - V15 不约束 (高阻, 安全红线)
# 跑法 (cmd.exe, 先 call settings64.bat):
#   cd /d D:\claude_workspace\pov3d\zynq_pov_icnd2047\02_hello_zynq
#   vivado -mode batch -source ..\tools\build_icnd_p3.tcl
###############################################################################
set WT "D:/claude_workspace/pov3d/zynq_pov_icnd2047"
open_project $WT/02_hello_zynq/02_hello_zynq.xpr
set_property source_mgmt_mode All [current_project]

# 1) ICND2047 IP verilog 入 sources_1
set icnd_src "$WT/02_hello_zynq/02_hello_zynq.srcs/sources_1/imports/hdl/icnd2047_panel_seq.v"
if {[lsearch -exact [get_files] $icnd_src] < 0} {
    add_files -norecurse $icnd_src
    puts "\[INFO\] added icnd2047_panel_seq.v"
}
update_compile_order -fileset sources_1

# 2) P3 XDC 入约束 + disable 冲突 XDC
foreach x {hub75e_pins.xdc led_pins.xdc} {
    set f [get_files -quiet $x]
    if {$f ne ""} { set_property is_enabled false $f ; puts "\[INFO\] disabled $x" }
}
set p3xdc "$WT/02_hello_zynq/02_hello_zynq.srcs/constrs_1/new/icnd2047_p3.xdc"
if {[lsearch -exact [get_files] $p3xdc] < 0} {
    add_files -fileset constrs_1 -norecurse $p3xdc
    puts "\[INFO\] added icnd2047_p3.xdc"
}
set_property is_enabled true [get_files icnd2047_p3.xdc]

# 3) sanity: 列出 enabled XDC + 确认 AB16 没被别的文件抢 / V15 没被约束
puts "===== enabled XDC ====="
foreach f [get_files -filter {FILE_TYPE==XDC}] {
    puts "  [get_property IS_ENABLED $f]  $f"
}

# 4) worktree fresh checkout 缺 .gen (gitignore) → 先重生成 BD 产物
#    (所有 .xci 都在 .srcs, 可重生成; 别 open_bd_design 会报 missing cell sc_pov_axilite)
#    wrapper 已提交 (imports/hdl/hello_zynq_wrapper.v) 且 BD 未改, 不重新 make_wrapper
# 让所有 BD 子 IP 全局综合 (generate_synth_checkpoint=false) → 不出 OOC .dcp,
# 跟顶层一起综合; 否则 fresh checkout 缺各 IP .dcp → SmartConnect 全 black box.
# 2024.2 这个 BD 没有独立 OOC synth run (runs 目录只有 synth_1), 所以必须走全局.
puts "===== 设所有 IP 全局综合 GENERATE_SYNTH_CHECKPOINT=0 (让 bd_*.v 进 compile order) ====="
foreach ip [get_ips] {
    catch { set_property GENERATE_SYNTH_CHECKPOINT 0 $ip }
    catch { puts "  $ip GSC=[get_property GENERATE_SYNTH_CHECKPOINT $ip]" }
}
reset_target -quiet all [get_files hello_zynq.bd]

# jesd204c bd_rule 初始化报错是 Vivado 无关IP的 spurious error (设计没用 jesd204c),
# 但实际 BD 块都生成了. catch 掉它, 改用"产物是否真生成"来判断成败.
catch { generate_target all [get_files hello_zynq.bd] } gt_err
puts "\[INFO\] generate_target 返回: $gt_err (jesd204c 报错可忽略)"
set bd_synth_v "$WT/02_hello_zynq/02_hello_zynq.gen/sources_1/bd/hello_zynq/synth/hello_zynq.v"
if {![file exists $bd_synth_v]} {
    error "BD synth HDL 未生成 ($bd_synth_v) — generate_target 真失败"
}
puts "\[INFO\] BD synth HDL OK: $bd_synth_v"
catch { export_ip_user_files -of_objects [get_files hello_zynq.bd] -no_script -sync -force -quiet }
update_compile_order -fileset sources_1
# ===== in-memory synth_design 流程 (不用 launch_runs!) =====
# memory feedback_hls_resynth_full_flow #3: batch launch_runs 不跑 OOC IP → SmartConnect 黑盒.
# synth_design 按 compile order 把整 BD (含 SmartConnect) 内联综合, 无 OOC 依赖, 无黑盒.
set PART [get_property PART [current_project]]
puts "\[INFO\] in-memory synth_design, part=$PART"
synth_design -top hello_zynq_wrapper -part $PART
write_checkpoint -force $WT/02_hello_zynq/_icnd_synth.dcp
report_utilization -file $WT/02_hello_zynq/_icnd_util.rpt
puts "\[INFO\] synth_design 完成"

opt_design
place_design
route_design
report_timing_summary -max_paths 5 -file $WT/02_hello_zynq/_icnd_timing.rpt

puts "===== 关键检查 ====="
catch { puts "hub75e_dclk PACKAGE_PIN = [get_property PACKAGE_PIN [get_ports hub75e_dclk]] (应 AB16)" }
catch { puts "WNS = [get_property SLACK [lindex [get_timing_paths -max_paths 1 -nworst 1 -setup] 0]] ns" }

set BIT $WT/02_hello_zynq/icnd_p3.bit
write_bitstream -force $BIT
puts "\[INFO\] ✅ bitstream -> $BIT"
