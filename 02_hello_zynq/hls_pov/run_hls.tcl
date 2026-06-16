# run_hls.tcl - Vitis HLS 综合 pov_proj IP (主进程统一构建, 我不跑)
#
# 用法 (Windows, settings64 已 source):
#   cd D:\claude_workspace\pov3d\zynq_pov\02_hello_zynq\hls_pov
#   D:\Vitis\2024.2\bin\vitis_hls.bat -f run_hls.tcl
#
# 产物:
#   proj_povproj/sol1/syn/report/pov_proj_csynth.rpt   综合报告 (看 BRAM/DSP/II/Fmax)
#   pov_proj_ip.zip                                     IP 包 (灌 Vivado IP Repo)

open_project proj_povproj
set_top pov_proj
add_files pov_proj.cpp   -cflags "-std=c++11"
add_files pov_proj.h     -cflags "-std=c++11"
add_files cos_sin_q15.h  -cflags "-std=c++11"
# csim 用 host TB (需输入 bin 在工作目录, 见 _gen_tb_inputs.py). 可选, 较慢.
# add_files -tb pov_proj_tb.cpp -cflags "-std=c++11"

open_solution "sol1" -flow_target vivado
set_part {xc7z020clg484-2}
create_clock -period 6.67 -name default   ;# 150 MHz

# csim 可选 (要先在工作目录跑 _gen_tb_inputs.py 产 tb_*.bin):
# puts "== C SIM =="
# csim_design

puts "== SYNTHESIS =="
csynth_design

puts "== EXPORT IP =="
export_design -format ip_catalog -output pov_proj_ip.zip \
    -description "POV voxel->compact slice projector (architecture B, transform-LUT gather)" \
    -vendor povlab -library user -version 1.0 \
    -display_name "POV Proj (compact)"

puts "DONE. IP @ proj_povproj/sol1/impl/ip/  (zip: pov_proj_ip.zip)"
