# run_hls.tcl - 批处理 Vitis HLS 综合脚本
#
# 用法:
#   cd D:\workspace\zynq_pov\hls_proj
#   D:\Vitis\2024.2\bin\vitis_hls.bat -f run_hls.tcl
#
# 产物:
#   proj_pov/solution1/syn/report/pov_project_csynth.rpt   综合报告
#   proj_pov/solution1/impl/ip/*.zip                       IP 打包 (拿去 Vivado IP Repo)

open_project proj_pov
set_top pov_project
add_files pov_project.cpp   -cflags "-std=c++11"
add_files pov_project.h     -cflags "-std=c++11"
add_files cos_sin_lut.h     -cflags "-std=c++11"
add_files -tb testbench.cpp -cflags "-std=c++11"

open_solution "solution1" -flow_target vivado
# XC7Z020-CLG484-2 (Zynq-7020 -2 speed)
set_part {xc7z020clg484-2}
# 150 MHz 目标时钟 (= 6.67 ns 周期)
create_clock -period 6.67 -name default

# csim - run testbench in software (verifies algorithm)
puts "== C SIMULATION =="
csim_design
# If csim fails, exit
# (csim_design returns status via Tcl; we can wrap in catch later)

puts "== SYNTHESIS =="
csynth_design

# Optional: co-simulation (C + RTL). Takes longer.
# cosim_design

puts "== EXPORT RTL AS IP =="
export_design -format ip_catalog -output pov_project_ip.zip \
              -description "POV 3D projection engine" \
              -vendor povlab -library user -version 1.0 \
              -display_name "POV Project Engine"

puts "DONE. See proj_pov/solution1/impl/ for IP package."
exit 0
