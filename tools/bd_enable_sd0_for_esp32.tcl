# bd_enable_sd0_for_esp32.tcl
#
# 启用 PS SD0 peripheral (MIO40-47) 让 Zynq 通过 SDIO 跟 ESP32-C5 slave 通信.
# ESP32 firmware pov_bridge.bin 暴露 WiFi/TCP 数据为 SDIO IO card.
#
# !!! 风险 !!!
# 鹿小班 LXB-ZYNQ7000 板: SD0 (MIO40-47) 物理跟板载 microSD slot 共用.
# 启用此 IP 后, microSD 失效, microSD 启动/数据访问也不再可用.
# 仅在 ESP32-C5 通信模式下运行此 tcl. 用回 microSD 模式时手工恢复.
#
# 用法 (从 Windows Vivado):
#   vivado -mode batch -source bd_enable_sd0_for_esp32.tcl
# 注释 user: 综合/导出 XSA + 重生成 Vitis BSP 才能拿到 XSdPs driver.
# 这一步不在 tcl 里自动 run, 由 user 决定 (avoid 长时间无人值守 launch_runs).

set proj_dir "D:/workspace/zynq_pov/02_hello_zynq"
set proj_xpr "$proj_dir/02_hello_zynq.xpr"
set bd_name  "hello_zynq"

puts "=== Opening project ==="
open_project $proj_xpr
open_bd_design [get_files ${bd_name}.bd]

puts "=== Enable SD0 on MIO40-45 (CMD/CLK/D0..D3) ==="
# PCW 字段说明 (Zynq PS configuration):
#   PCW_SD0_PERIPHERAL_ENABLE = 1     使能 SD0
#   PCW_SD0_SD0_IO            = MIO 40 .. 45   data/cmd/clk bank
#   PCW_SD0_GRP_CD_ENABLE     = 1     card-detect enable
#   PCW_SD0_GRP_CD_IO         = MIO 46
#   PCW_SD0_GRP_WP_ENABLE     = 1     write-protect enable (实际 ESP32 不用, 但板上接了)
#   PCW_SD0_GRP_WP_IO         = MIO 47
#   PCW_SD0_GRP_POW_ENABLE    = 0
#   PCW_SDIO_PERIPHERAL_FREQMHZ = 50  (default; 板载 OK)
#   PCW_SDIO_PERIPHERAL_CLKSRC  = IO PLL

set_property -dict [list \
    CONFIG.PCW_SD0_PERIPHERAL_ENABLE     {1} \
    CONFIG.PCW_SD0_SD0_IO                {MIO 40 .. 45} \
    CONFIG.PCW_SD0_GRP_CD_ENABLE         {1} \
    CONFIG.PCW_SD0_GRP_CD_IO             {MIO 46} \
    CONFIG.PCW_SD0_GRP_WP_ENABLE         {1} \
    CONFIG.PCW_SD0_GRP_WP_IO             {MIO 47} \
    CONFIG.PCW_SD0_GRP_POW_ENABLE        {0} \
    CONFIG.PCW_SDIO_PERIPHERAL_FREQMHZ   {50} \
    CONFIG.PCW_SDIO_PERIPHERAL_CLKSRC    {IO PLL} \
    CONFIG.PCW_SDIO_PERIPHERAL_VALID     {1} \
] [get_bd_cells /processing_system7_0]

puts "=== Validate & save ==="
catch {validate_bd_design} e
puts "validate: $e"
save_bd_design

puts "=== Regenerate outputs ==="
generate_target all [get_files ${bd_name}.bd] -force

# Auto-run synth + impl + bitstream + XSA export (Claude does this for user).
puts "=== reset + launch synth + impl + bitstream ==="
catch { reset_run synth_1 }
catch { reset_run impl_1 }
launch_runs synth_1 -jobs 4
wait_on_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

puts "=== export XSA ==="
# Use absolute path to avoid pwd ambiguity (cf. prior bug写到错路径).
write_hw_platform -fixed -include_bit -force "$proj_dir/hello_zynq_wrapper.xsa"

puts "=== DONE. New XSA at $proj_dir/hello_zynq_wrapper.xsa ==="
puts "=== Next: Vitis refresh hello_plat from new XSA, BSP gets xsdps driver. ==="
close_project
exit 0
