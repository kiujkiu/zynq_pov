# Enable PS QSPI peripheral in BD, validate, regen wrapper, regen bit, export XSA.
# Usage:
#   vivado -mode batch -source bd_enable_qspi.tcl
#
# Output: 02_hello_zynq.runs/impl_1/hello_zynq_wrapper.bit + new XSA

set proj_dir D:/workspace/zynq_pov/02_hello_zynq
set xsa_out  D:/workspace/zynq_pov/02_hello_zynq/02_hello_zynq.xsa

puts "BD-QSPI: opening project"
open_project $proj_dir/02_hello_zynq.xpr
# Avoid hierarchy auto-update messing with our top setting
set_property source_mgmt_mode None [current_project]

puts "BD-QSPI: opening BD design"
open_bd_design $proj_dir/02_hello_zynq.srcs/sources_1/bd/hello_zynq/hello_zynq.bd
current_bd_design hello_zynq

puts "BD-QSPI: current QSPI state BEFORE set_property:"
puts "  PCW_QSPI_PERIPHERAL_ENABLE = [get_property CONFIG.PCW_QSPI_PERIPHERAL_ENABLE [get_bd_cells processing_system7_0]]"

puts "BD-QSPI: enabling QSPI peripheral on processing_system7_0"
set_property -dict [list \
    CONFIG.PCW_QSPI_PERIPHERAL_ENABLE        {1} \
    CONFIG.PCW_QSPI_QSPI_IO                  {MIO 1 .. 6} \
    CONFIG.PCW_QSPI_GRP_SINGLE_SS_ENABLE     {1} \
    CONFIG.PCW_QSPI_GRP_SINGLE_SS_IO         {MIO 1} \
    CONFIG.PCW_QSPI_GRP_FBCLK_ENABLE         {0} \
    CONFIG.PCW_QSPI_PERIPHERAL_FREQMHZ       {200} \
    CONFIG.PCW_QSPI_PERIPHERAL_DIVISOR0      {5} \
    CONFIG.PCW_MIO_1_PULLUP                  {enabled} \
    CONFIG.PCW_MIO_1_IOTYPE                  {LVCMOS 3.3V} \
    CONFIG.PCW_MIO_1_SLEW                    {slow} \
    CONFIG.PCW_MIO_1_DIRECTION               {out} \
    CONFIG.PCW_MIO_2_PULLUP                  {disabled} \
    CONFIG.PCW_MIO_2_IOTYPE                  {LVCMOS 3.3V} \
    CONFIG.PCW_MIO_2_SLEW                    {slow} \
    CONFIG.PCW_MIO_2_DIRECTION               {inout} \
    CONFIG.PCW_MIO_3_PULLUP                  {disabled} \
    CONFIG.PCW_MIO_3_IOTYPE                  {LVCMOS 3.3V} \
    CONFIG.PCW_MIO_3_SLEW                    {slow} \
    CONFIG.PCW_MIO_3_DIRECTION               {inout} \
    CONFIG.PCW_MIO_4_PULLUP                  {disabled} \
    CONFIG.PCW_MIO_4_IOTYPE                  {LVCMOS 3.3V} \
    CONFIG.PCW_MIO_4_SLEW                    {slow} \
    CONFIG.PCW_MIO_4_DIRECTION               {inout} \
    CONFIG.PCW_MIO_5_PULLUP                  {disabled} \
    CONFIG.PCW_MIO_5_IOTYPE                  {LVCMOS 3.3V} \
    CONFIG.PCW_MIO_5_SLEW                    {slow} \
    CONFIG.PCW_MIO_5_DIRECTION               {inout} \
    CONFIG.PCW_MIO_6_PULLUP                  {disabled} \
    CONFIG.PCW_MIO_6_IOTYPE                  {LVCMOS 3.3V} \
    CONFIG.PCW_MIO_6_SLEW                    {slow} \
    CONFIG.PCW_MIO_6_DIRECTION               {out} \
] [get_bd_cells processing_system7_0]

# Force MIO_TREE_PERIPHERALS: pin 0..53 strings separated by '#'
# MIO 1-6 = Quad SPI Flash, MIO 40-45/47 = SD 0 (unchanged), rest unassigned
set mio_tree "unassigned"
for {set i 1} {$i <= 6} {incr i}  { append mio_tree "#Quad SPI Flash" }
for {set i 7} {$i <= 39} {incr i} { append mio_tree "#unassigned" }
for {set i 40} {$i <= 45} {incr i} { append mio_tree "#SD 0" }
append mio_tree "#unassigned"               ;# MIO 46
append mio_tree "#SD 0"                     ;# MIO 47
for {set i 48} {$i <= 53} {incr i} { append mio_tree "#unassigned" }
puts "BD-QSPI: setting PCW_MIO_TREE_PERIPHERALS:"
puts "  $mio_tree"
set_property -dict [list \
    CONFIG.PCW_MIO_TREE_PERIPHERALS $mio_tree \
] [get_bd_cells processing_system7_0]

puts "BD-QSPI: state AFTER set_property:"
puts "  PCW_QSPI_PERIPHERAL_ENABLE = [get_property CONFIG.PCW_QSPI_PERIPHERAL_ENABLE [get_bd_cells processing_system7_0]]"
puts "  PCW_QSPI_QSPI_IO = [get_property CONFIG.PCW_QSPI_QSPI_IO [get_bd_cells processing_system7_0]]"
puts "  PCW_MIO_1_PULLUP = [get_property CONFIG.PCW_MIO_1_PULLUP [get_bd_cells processing_system7_0]]"
puts "  PCW_MIO_1_IOTYPE = [get_property CONFIG.PCW_MIO_1_IOTYPE [get_bd_cells processing_system7_0]]"

puts "BD-QSPI: BEFORE validate, MIO_TREE = [get_property CONFIG.PCW_MIO_TREE_PERIPHERALS [get_bd_cells processing_system7_0]]"
puts "BD-QSPI: validating BD"
validate_bd_design
puts "BD-QSPI: AFTER validate, MIO_TREE = [get_property CONFIG.PCW_MIO_TREE_PERIPHERALS [get_bd_cells processing_system7_0]]"
puts "BD-QSPI: AFTER validate, MIO_1 PERIPHERAL = [get_property CONFIG.PCW_MIO_1_PERIPHERAL [get_bd_cells processing_system7_0]]"

puts "BD-QSPI: saving BD"
save_bd_design

puts "BD-QSPI: regenerate IP output products + wrapper"
generate_target all [get_files $proj_dir/02_hello_zynq.srcs/sources_1/bd/hello_zynq/hello_zynq.bd]
set wrapper_path [make_wrapper -files [get_files $proj_dir/02_hello_zynq.srcs/sources_1/bd/hello_zynq/hello_zynq.bd] -top -force]
puts "  wrapper: $wrapper_path"
catch {add_files -norecurse $wrapper_path}
# Skip update_compile_order due to a Vivado batch-mode bug ("Spawn failed:
# Invalid argument"). Manually set top + ensure file enabled.
set_property top hello_zynq_wrapper [current_fileset]
puts "  top: [get_property top [current_fileset]]"

# Reset runs to force re-synthesis with new BD
puts "BD-QSPI: resetting synth/impl runs"
reset_run synth_1
reset_run impl_1

puts "BD-QSPI: launching synthesis"
catch {launch_runs synth_1 -jobs 4} synthlog
puts "  synth launch result: $synthlog"
catch {wait_on_run synth_1} waitlog
puts "  synth wait result: [get_property STATUS [get_runs synth_1]]"

puts "BD-QSPI: launching impl + bit"
catch {launch_runs impl_1 -to_step write_bitstream -jobs 4} implog
puts "  impl launch result: $implog"
catch {wait_on_run impl_1} waitlog2
puts "  impl wait result: [get_property STATUS [get_runs impl_1]]"

puts "BD-QSPI: regenerating handoff before XSA export"
catch {generate_target -force {synthesis simulation implementation} \
    [get_files $proj_dir/02_hello_zynq.srcs/sources_1/bd/hello_zynq/hello_zynq.bd]}
puts "BD-QSPI: exporting XSA (with bit)"
write_hw_platform -fixed -include_bit -force -file $xsa_out

puts "BD-QSPI: copying bit to hello_plat sdt"
file copy -force \
    $proj_dir/02_hello_zynq.runs/impl_1/hello_zynq_wrapper.bit \
    $proj_dir/vitis_ws/hello_plat/hw/sdt/hello_zynq_wrapper.bit

puts "BD-QSPI: done. XSA -> $xsa_out"
close_project
exit
