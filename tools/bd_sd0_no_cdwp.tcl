# bd_sd0_no_cdwp.tcl — Disable SD0 Card-Detect and Write-Protect.
#
# Without microSD physically inserted, MIO46 (CD) reads "no card" → Arasan
# SDHC controller blocks CMD0. SDHCI HC1 bit 7+6 override does NOT take
# effect on Zynq-7000 PS SDIO (PRES.CARD_INSERTED stays 0).
#
# Fix: disable CD/WP at PCW level → controller assumes card always present
# and ignores MIO46/47. MIO40-45 remain SDIO CMD/CLK/D0..D3 for the ESP32
# bridge.
#
# Run from Windows Vivado:
#   D:\Xilinx\Vivado\2024.2\bin\vivado.bat -mode batch -source bd_sd0_no_cdwp.tcl

set proj_dir "D:/workspace/zynq_pov/02_hello_zynq"
set proj_xpr "$proj_dir/02_hello_zynq.xpr"
set bd_name  "hello_zynq"

puts "=== Opening project ==="
open_project $proj_xpr
open_bd_design [get_files ${bd_name}.bd]

puts "=== Disable SD0 CD/WP, keep CMD/CLK/D0..D3 on MIO40-45 ==="
set_property -dict [list \
    CONFIG.PCW_SD0_PERIPHERAL_ENABLE     {1} \
    CONFIG.PCW_SD0_SD0_IO                {MIO 40 .. 45} \
    CONFIG.PCW_SD0_GRP_CD_ENABLE         {0} \
    CONFIG.PCW_SD0_GRP_WP_ENABLE         {0} \
    CONFIG.PCW_SD0_GRP_POW_ENABLE        {0} \
    CONFIG.PCW_SDIO_PERIPHERAL_FREQMHZ   {50} \
    CONFIG.PCW_SDIO_PERIPHERAL_CLKSRC    {IO PLL} \
] [get_bd_cells processing_system7_0]

puts "=== Validate BD ==="
validate_bd_design
save_bd_design

puts "=== Generate output products ==="
generate_target -force all [get_files ${bd_name}.bd]

puts "=== Reset synth/impl runs ==="
reset_run synth_1
reset_run impl_1

puts "=== Launch synth + impl ==="
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1

if {[get_property STATUS [get_runs impl_1]] eq "write_bitstream Complete!"} {
    puts "=== Bitstream complete, exporting XSA ==="
    open_run impl_1
    write_hw_platform -fixed -force -include_bit \
        "$proj_dir/02_hello_zynq.xsa"
    puts "XSA exported"
} else {
    puts "ERROR: impl_1 failed"
    exit 1
}

close_project
puts "=== bd_sd0_no_cdwp.tcl done ==="
