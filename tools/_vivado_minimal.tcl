open_project D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq/02_hello_zynq.xpr
launch_runs synth_1 -jobs 4
wait_on_runs synth_1
puts "synth_1: [get_property STATUS [get_runs synth_1]]"
close_project
