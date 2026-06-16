# run_hls_full.tcl - Vitis HLS 综合 pov_render_full IP (路线 B1, 主进程统一构建, 我不跑)
#
# 用法 (Windows, settings64 已 source):
#   cd D:\claude_workspace\pov3d\zynq_pov\02_hello_zynq\hls_pov
#   D:\Vitis\2024.2\bin\vitis_hls.bat -f run_hls_full.tcl
#
# 产物:
#   proj_full/sol1/syn/report/pov_render_full_csynth.rpt   综合报告 (BRAM/DSP/II/Fmax)
#   pov_render_full_ip.zip                                 IP 包 (灌 Vivado IP Repo)

open_project proj_full
set_top pov_render_full
add_files pov_render_full.cpp  -cflags "-std=c++11"
add_files pov_render_full.h    -cflags "-std=c++11"
add_files cos_sin_q15.h        -cflags "-std=c++11"
# csim 用 host TB (需 tools/anime_points.bin + transform_lut.bin). 可选, 较慢.
# add_files -tb pov_render_full_tb.cpp -cflags "-std=c++11"

open_solution "sol1" -flow_target vivado
set_part {xc7z020clg484-2}
create_clock -period 6.67 -name default   ;# 150 MHz

# csim 可选:
# puts "== C SIM =="
# csim_design

puts "== SYNTHESIS =="
csynth_design

puts "== EXPORT IP =="
export_design -format ip_catalog -output pov_render_full_ip.zip \
    -description "POV B1: point-cloud -> clear+scatter voxelize -> compact-slice gather" \
    -vendor povlab -library user -version 1.0 \
    -display_name "POV Render Full (B1)"

puts "DONE. IP @ proj_full/sol1/impl/ip/  (zip: pov_render_full_ip.zip)"
