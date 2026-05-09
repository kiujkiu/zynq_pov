# run_mesh_slice_synth.tcl - 综合 mesh_slice_render IP (Phase 9.5 task G).
# 用法: cd hls_proj && cmd.exe /c "D:\Vitis\2024.2\bin\vitis-run.bat \
#         --mode hls --tcl run_mesh_slice_synth.tcl --work_dir ."
# 产物: proj_mesh_slice/solution1/impl/ip/*.zip → 拿去 Vivado IP Repo

open_project proj_mesh_slice
set_top mesh_slice_render
add_files mesh_slice.cpp     -cflags "-std=c++11"
add_files mesh_slice.h       -cflags "-std=c++11"
add_files mesh_slice_lut.h   -cflags "-std=c++11"
add_files -tb mesh_slice_tb.cpp -cflags "-std=c++11"

open_solution "solution1" -flow_target vivado
set_part {xc7z020clg484-2}
create_clock -period 6.67 -name default

puts "== C SIMULATION =="
csim_design

puts "== SYNTHESIS =="
csynth_design

puts "== EXPORT IP =="
export_design -format ip_catalog -output mesh_slice_ip.zip \
              -description "POV mesh cross-section slice render (two-phase, ARM 1.5ms/cell -> HLS expected 5-10x)" \
              -vendor povlab -library user -version 1.0 \
              -display_name "POV Mesh Slice Render"

puts "DONE."
exit 0
