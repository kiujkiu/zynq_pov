# bd_4x_pov_project_batch.tcl — 扩展 BD 到 4× pov_project_batch IP 并行渲染
#
# 现状 (2026-05-09): BD 含 1× pov_project_batch_0, 走 axi_smc_pov_hp (NUM_SI=2)
# → HP1. 单 IP @ 150 MHz 能跑 ~2800 slice/sec, 距 720 slot × 30 Hz =
# 21600 slice/sec 还差 8×. 4× 并行 → ~11200 slice/sec, 仍不够, 但属阶段性目标.
# 真正满足 720@30Hz 还需 IP 内部 unroll (II→1) 或 dataflow.
#
# 跑法 (Windows Vivado 2024.2):
#   D:\Vivado\2024.2\bin\vivado.bat -mode batch \
#       -source D:\workspace\zynq_pov\tools\bd_4x_pov_project_batch.tcl \
#       -nojournal
#
# 修改概要:
#   1. 加 pov_project_batch_1/2/3 (vlnv povlab:user:pov_project_batch:1.0)
#   2. 把 axi_smc_pov_hp NUM_SI 从 2 → 8 (4 IP × {gmem0,gmem1})
#   3. 加 sc_pov_axilite (NUM_SI=1, NUM_MI=4): 复用现有 axi_smc/M03 给 4 IP 控制
#   4. 时钟 + 复位连到现有 FCLK_CLK3 + proc_sys_reset_pov
#   5. 重新 assign_bd_address → 4 IP s_axi_control 各自 64KB 窗口
#
# 资源估算: pov_project_batch 单 IP ~1.3K LUT / 350 FF / 2 BRAM / 3 DSP (Phase 4b
# 数据). 4× = ~5.2K LUT / 8 BRAM / 12 DSP, 7020 余量足够.
#
# 风险:
#   - validate_bd_design 报地址冲突 → 删除现有 segment 重 assign
#   - HP1 单端口被 4 IP × 2 接口争用 → DDR 带宽降级, 实际 < 4× 加速
#     (mitigation: 升级到 dual-HP 版本, 见 tools/bd_4x_pov_dual_hp.tcl 待写)

open_project D:/workspace/zynq_pov/02_hello_zynq/02_hello_zynq.xpr
# Avoid "Spawn failed" on update_compile_order — switch to manual mgmt mode
set_property source_mgmt_mode None [current_project]
catch { update_compile_order -fileset sources_1 }

set bd_file [get_files hello_zynq.bd]
open_bd_design $bd_file

# 1) Add 3 more IP instances
foreach idx {1 2 3} {
    if {[get_bd_cells -quiet pov_project_batch_$idx] eq ""} {
        create_bd_cell -type ip -vlnv povlab:user:pov_project_batch:1.0 \
            pov_project_batch_$idx
        puts "added pov_project_batch_$idx"
    }
}

# 2) Wire clock + reset for new IPs.
#    Vivado 自动 merge 当 connect_bd_net 把 new pin 加到 existing pin 所在 net.
foreach idx {1 2 3} {
    catch { connect_bd_net [get_bd_pins pov_project_batch_0/ap_clk] \
        [get_bd_pins pov_project_batch_$idx/ap_clk] }
    catch { connect_bd_net [get_bd_pins pov_project_batch_0/ap_rst_n] \
        [get_bd_pins pov_project_batch_$idx/ap_rst_n] }
}

# 3) Expand axi_smc_pov_hp from NUM_SI=2 → 8 (4 IP × {gmem0, gmem1})
#    Slot map: S00=IP0/gmem0, S01=IP0/gmem1, S02=IP1/gmem0 ... S07=IP3/gmem1
set_property CONFIG.NUM_SI 8 [get_bd_cells axi_smc_pov_hp]

# Disconnect existing IP0 mem (reconnect after to fixed slots — pattern below uses S00/S01 for IP0)
# (Vivado may or may not auto-keep — use explicit get_bd_intf_nets to be safe)

# Reconnect IP0 (idempotent — Vivado dedupes)
catch {
    connect_bd_intf_net [get_bd_intf_pins pov_project_batch_0/m_axi_gmem0] \
        [get_bd_intf_pins axi_smc_pov_hp/S00_AXI]
    connect_bd_intf_net [get_bd_intf_pins pov_project_batch_0/m_axi_gmem1] \
        [get_bd_intf_pins axi_smc_pov_hp/S01_AXI]
}
# Connect IP1/2/3 (catch — already connected on idempotent re-run)
foreach idx {1 2 3} {
    set s0 [format "S%02d_AXI" [expr {$idx * 2}]]
    set s1 [format "S%02d_AXI" [expr {$idx * 2 + 1}]]
    catch { connect_bd_intf_net [get_bd_intf_pins pov_project_batch_$idx/m_axi_gmem0] \
        [get_bd_intf_pins axi_smc_pov_hp/$s0] }
    catch { connect_bd_intf_net [get_bd_intf_pins pov_project_batch_$idx/m_axi_gmem1] \
        [get_bd_intf_pins axi_smc_pov_hp/$s1] }
}
# Clock for new SI ports — same axi_clk as IP0 (Vivado auto-merge net).
foreach idx {0 1 2 3 4 5 6 7} {
    set p [format "S%02d_ACLK" $idx]
    catch { connect_bd_net [get_bd_pins pov_project_batch_0/ap_clk] \
                            [get_bd_pins axi_smc_pov_hp/$p] }
    set p2 [format "S%02d_ARESETN" $idx]
    catch { connect_bd_net [get_bd_pins pov_project_batch_0/ap_rst_n] \
                            [get_bd_pins axi_smc_pov_hp/$p2] }
}

# 4) Add Smartconnect for s_axi_control fan-out (1→4)
if {[get_bd_cells -quiet sc_pov_axilite] eq ""} {
    create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 sc_pov_axilite
    set_property CONFIG.NUM_SI 1  [get_bd_cells sc_pov_axilite]
    set_property CONFIG.NUM_MI 4  [get_bd_cells sc_pov_axilite]
    set_property CONFIG.NUM_CLKS 1 [get_bd_cells sc_pov_axilite]
    # Slave from axi_smc/M03 (where IP0/s_axi_control was directly connected)
    # → reroute via sc_pov_axilite
    # Step 1: disconnect old direct path
    set old_link [get_bd_intf_nets -quiet -of [get_bd_intf_pins pov_project_batch_0/s_axi_control]]
    if {$old_link ne ""} { delete_bd_objs $old_link }
    # Step 2: connect axi_smc/M03 → sc_pov_axilite/S00
    connect_bd_intf_net [get_bd_intf_pins axi_smc/M03_AXI] \
        [get_bd_intf_pins sc_pov_axilite/S00_AXI]
    # Step 3: connect M00..M03 → IP0..IP3/s_axi_control
    foreach idx {0 1 2 3} {
        set m [format "M%02d_AXI" $idx]
        connect_bd_intf_net [get_bd_intf_pins sc_pov_axilite/$m] \
            [get_bd_intf_pins pov_project_batch_$idx/s_axi_control]
    }
    # Clk + rst — sc_pov_axilite NUM_CLKS=1, 单 aclk + aresetn pin.
    # IP control 端用 IP0/ap_clk 同时钟域 (FCLK_CLK3), smartconnect 内部跨 clk OK.
    catch { connect_bd_net [get_bd_pins pov_project_batch_0/ap_clk] \
                            [get_bd_pins sc_pov_axilite/aclk] }
    catch { connect_bd_net [get_bd_pins pov_project_batch_0/ap_rst_n] \
                            [get_bd_pins sc_pov_axilite/aresetn] }
}

# 5) Address assignments — give each IP a 64KB control window
foreach idx {1 2 3} {
    set seg [get_bd_addr_segs -quiet pov_project_batch_$idx/s_axi_control/Reg]
    if {$seg ne ""} { assign_bd_address $seg }
}
# Re-validate map
foreach idx {0 1 2 3} {
    foreach mem {gmem0 gmem1} {
        # Allow IP to address full DDR (0x0..0x1FFFFFFF for 512MB)
        catch {
            set as [get_bd_addr_spaces pov_project_batch_$idx/Data_m_axi_$mem]
            assign_bd_address -target_address_space $as \
                [get_bd_addr_segs processing_system7_0/S_AXI_HP1/HP1_DDR_LOWOCM]
        }
    }
}

# 6) Validate, save, regenerate wrapper
validate_bd_design
save_bd_design
generate_target all $bd_file

# 7) Run synth + impl + bit. reset_run before launch (existing run state stale).
catch { reset_run synth_1 }
catch { reset_run impl_1 }
launch_runs synth_1 -jobs 4
wait_on_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

# 8) Export new XSA
write_hw_platform -fixed -include_bit \
    -force [pwd]/02_hello_zynq.xsa
puts "DONE: 4-IP batch IP integrated. XSA at 02_hello_zynq.xsa"
exit 0
