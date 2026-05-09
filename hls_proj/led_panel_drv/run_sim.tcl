#-----------------------------------------------------------------------------
# run_sim.tcl  --  Vivado xsim driver for led_panel_drv testbench
#
# Usage (Windows cmd, from this folder):
#   xvlog led_panel_drv.v led_panel_drv_tb.v
#   xelab -debug typical led_panel_drv_tb -s led_panel_drv_sim
#   xsim led_panel_drv_sim -tclbatch run_sim.tcl
#
# Or, single shot:
#   xsim led_panel_drv_sim -tclbatch run_sim.tcl -log xsim.log
#-----------------------------------------------------------------------------

# Run to completion (testbench has $finish after assertions)
run all
quit
