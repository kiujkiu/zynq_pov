# This script segment is generated automatically by AutoPilot

set name pov_eta_wr_mul_10s_32s_32_3_1
if {${::AESL::PGuard_rtl_comp_handler}} {
	::AP::rtl_comp_handler $name BINDTYPE {op} TYPE {mul} IMPL {auto} LATENCY 2 ALLOW_PRAGMA 1
}


set name pov_eta_wr_srem_32ns_11ns_32_36_1
if {${::AESL::PGuard_rtl_comp_handler}} {
	::AP::rtl_comp_handler $name BINDTYPE {op} TYPE {srem} IMPL {auto} LATENCY 35 ALLOW_PRAGMA 1
}


set name pov_eta_wr_mul_16ns_10ns_25_1_1
if {${::AESL::PGuard_rtl_comp_handler}} {
	::AP::rtl_comp_handler $name BINDTYPE {op} TYPE {mul} IMPL {auto} LATENCY 0 ALLOW_PRAGMA 1
}


if {${::AESL::PGuard_rtl_comp_handler}} {
	::AP::rtl_comp_handler pov_eta_wr_mac_muladd_10s_8s_25s_25_4_1 BINDTYPE {op} TYPE {all} IMPL {dsp_slice} LATENCY 3
}


if {${::AESL::PGuard_rtl_comp_handler}} {
	::AP::rtl_comp_handler pov_eta_wr_pov_eta_wr_Pipeline_SLICES_COLUMNS_COPY_COLUMN_PV2_COS8_ROM_AUTO_1R BINDTYPE {storage} TYPE {rom} IMPL {auto} LATENCY 2 ALLOW_PRAGMA 1
}


if {${::AESL::PGuard_rtl_comp_handler}} {
	::AP::rtl_comp_handler pov_eta_wr_pov_eta_wr_Pipeline_SLICES_COLUMNS_COPY_COLUMN_PV2_SIN8_ROM_AUTO_1R BINDTYPE {storage} TYPE {rom} IMPL {auto} LATENCY 2 ALLOW_PRAGMA 1
}


# clear list
if {${::AESL::PGuard_autoexp_gen}} {
    cg_default_interface_gen_dc_begin
    cg_default_interface_gen_bundle_begin
    AESL_LIB_XILADAPTER::native_axis_begin
}

# Direct connection:
if {${::AESL::PGuard_autoexp_gen}} {
eval "cg_default_interface_gen_dc { \
    id 13 \
    name out_r \
    type other \
    dir O \
    reset_level 1 \
    sync_rst true \
    corename dc_out_r \
    op interface \
    ports { m_axi_out_r_0_AWVALID { O 1 bit } m_axi_out_r_0_AWREADY { I 1 bit } m_axi_out_r_0_AWADDR { O 64 vector } m_axi_out_r_0_AWID { O 1 vector } m_axi_out_r_0_AWLEN { O 32 vector } m_axi_out_r_0_AWSIZE { O 3 vector } m_axi_out_r_0_AWBURST { O 2 vector } m_axi_out_r_0_AWLOCK { O 2 vector } m_axi_out_r_0_AWCACHE { O 4 vector } m_axi_out_r_0_AWPROT { O 3 vector } m_axi_out_r_0_AWQOS { O 4 vector } m_axi_out_r_0_AWREGION { O 4 vector } m_axi_out_r_0_AWUSER { O 1 vector } m_axi_out_r_0_WVALID { O 1 bit } m_axi_out_r_0_WREADY { I 1 bit } m_axi_out_r_0_WDATA { O 64 vector } m_axi_out_r_0_WSTRB { O 8 vector } m_axi_out_r_0_WLAST { O 1 bit } m_axi_out_r_0_WID { O 1 vector } m_axi_out_r_0_WUSER { O 1 vector } m_axi_out_r_0_ARVALID { O 1 bit } m_axi_out_r_0_ARREADY { I 1 bit } m_axi_out_r_0_ARADDR { O 64 vector } m_axi_out_r_0_ARID { O 1 vector } m_axi_out_r_0_ARLEN { O 32 vector } m_axi_out_r_0_ARSIZE { O 3 vector } m_axi_out_r_0_ARBURST { O 2 vector } m_axi_out_r_0_ARLOCK { O 2 vector } m_axi_out_r_0_ARCACHE { O 4 vector } m_axi_out_r_0_ARPROT { O 3 vector } m_axi_out_r_0_ARQOS { O 4 vector } m_axi_out_r_0_ARREGION { O 4 vector } m_axi_out_r_0_ARUSER { O 1 vector } m_axi_out_r_0_RVALID { I 1 bit } m_axi_out_r_0_RREADY { O 1 bit } m_axi_out_r_0_RDATA { I 64 vector } m_axi_out_r_0_RLAST { I 1 bit } m_axi_out_r_0_RID { I 1 vector } m_axi_out_r_0_RFIFONUM { I 9 vector } m_axi_out_r_0_RUSER { I 1 vector } m_axi_out_r_0_RRESP { I 2 vector } m_axi_out_r_0_BVALID { I 1 bit } m_axi_out_r_0_BREADY { O 1 bit } m_axi_out_r_0_BRESP { I 2 vector } m_axi_out_r_0_BID { I 1 vector } m_axi_out_r_0_BUSER { I 1 vector } } \
} "
}

# Direct connection:
if {${::AESL::PGuard_autoexp_gen}} {
eval "cg_default_interface_gen_dc { \
    id 14 \
    name vox \
    type other \
    dir I \
    reset_level 1 \
    sync_rst true \
    corename dc_vox \
    op interface \
    ports { m_axi_vox_0_AWVALID { O 1 bit } m_axi_vox_0_AWREADY { I 1 bit } m_axi_vox_0_AWADDR { O 64 vector } m_axi_vox_0_AWID { O 1 vector } m_axi_vox_0_AWLEN { O 32 vector } m_axi_vox_0_AWSIZE { O 3 vector } m_axi_vox_0_AWBURST { O 2 vector } m_axi_vox_0_AWLOCK { O 2 vector } m_axi_vox_0_AWCACHE { O 4 vector } m_axi_vox_0_AWPROT { O 3 vector } m_axi_vox_0_AWQOS { O 4 vector } m_axi_vox_0_AWREGION { O 4 vector } m_axi_vox_0_AWUSER { O 1 vector } m_axi_vox_0_WVALID { O 1 bit } m_axi_vox_0_WREADY { I 1 bit } m_axi_vox_0_WDATA { O 64 vector } m_axi_vox_0_WSTRB { O 8 vector } m_axi_vox_0_WLAST { O 1 bit } m_axi_vox_0_WID { O 1 vector } m_axi_vox_0_WUSER { O 1 vector } m_axi_vox_0_ARVALID { O 1 bit } m_axi_vox_0_ARREADY { I 1 bit } m_axi_vox_0_ARADDR { O 64 vector } m_axi_vox_0_ARID { O 1 vector } m_axi_vox_0_ARLEN { O 32 vector } m_axi_vox_0_ARSIZE { O 3 vector } m_axi_vox_0_ARBURST { O 2 vector } m_axi_vox_0_ARLOCK { O 2 vector } m_axi_vox_0_ARCACHE { O 4 vector } m_axi_vox_0_ARPROT { O 3 vector } m_axi_vox_0_ARQOS { O 4 vector } m_axi_vox_0_ARREGION { O 4 vector } m_axi_vox_0_ARUSER { O 1 vector } m_axi_vox_0_RVALID { I 1 bit } m_axi_vox_0_RREADY { O 1 bit } m_axi_vox_0_RDATA { I 64 vector } m_axi_vox_0_RLAST { I 1 bit } m_axi_vox_0_RID { I 1 vector } m_axi_vox_0_RFIFONUM { I 11 vector } m_axi_vox_0_RUSER { I 1 vector } m_axi_vox_0_RRESP { I 2 vector } m_axi_vox_0_BVALID { I 1 bit } m_axi_vox_0_BREADY { O 1 bit } m_axi_vox_0_BRESP { I 2 vector } m_axi_vox_0_BID { I 1 vector } m_axi_vox_0_BUSER { I 1 vector } } \
} "
}

# Direct connection:
if {${::AESL::PGuard_autoexp_gen}} {
eval "cg_default_interface_gen_dc { \
    id 15 \
    name mul_ln14 \
    type other \
    dir I \
    reset_level 1 \
    sync_rst true \
    corename dc_mul_ln14 \
    op interface \
    ports { mul_ln14 { I 45 vector } } \
} "
}

# Direct connection:
if {${::AESL::PGuard_autoexp_gen}} {
eval "cg_default_interface_gen_dc { \
    id 16 \
    name sext_ln46 \
    type other \
    dir I \
    reset_level 1 \
    sync_rst true \
    corename dc_sext_ln46 \
    op interface \
    ports { sext_ln46 { I 61 vector } } \
} "
}

# Direct connection:
if {${::AESL::PGuard_autoexp_gen}} {
eval "cg_default_interface_gen_dc { \
    id 17 \
    name phase \
    type other \
    dir I \
    reset_level 1 \
    sync_rst true \
    corename dc_phase \
    op interface \
    ports { phase { I 32 vector } } \
} "
}

# Direct connection:
if {${::AESL::PGuard_autoexp_gen}} {
eval "cg_default_interface_gen_dc { \
    id 18 \
    name zext_ln18 \
    type other \
    dir I \
    reset_level 1 \
    sync_rst true \
    corename dc_zext_ln18 \
    op interface \
    ports { zext_ln18 { I 31 vector } } \
} "
}

# Direct connection:
if {${::AESL::PGuard_autoexp_gen}} {
eval "cg_default_interface_gen_dc { \
    id 19 \
    name axis_off_q8 \
    type other \
    dir I \
    reset_level 1 \
    sync_rst true \
    corename dc_axis_off_q8 \
    op interface \
    ports { axis_off_q8 { I 32 vector } } \
} "
}

# Direct connection:
if {${::AESL::PGuard_autoexp_gen}} {
eval "cg_default_interface_gen_dc { \
    id 20 \
    name voxel \
    type other \
    dir I \
    reset_level 1 \
    sync_rst true \
    corename dc_voxel \
    op interface \
    ports { voxel { I 64 vector } } \
} "
}

# Direct connection:
if {${::AESL::PGuard_autoexp_gen}} {
eval "cg_default_interface_gen_dc { \
    id 21 \
    name mirror_u \
    type other \
    dir I \
    reset_level 1 \
    sync_rst true \
    corename dc_mirror_u \
    op interface \
    ports { mirror_u { I 32 vector } } \
} "
}

# Direct connection:
if {${::AESL::PGuard_autoexp_gen}} {
eval "cg_default_interface_gen_dc { \
    id -1 \
    name ap_ctrl \
    type ap_ctrl \
    reset_level 1 \
    sync_rst true \
    corename ap_ctrl \
    op interface \
    ports { ap_start { I 1 bit } ap_ready { O 1 bit } ap_done { O 1 bit } ap_idle { O 1 bit } } \
} "
}


# Adapter definition:
set PortName ap_clk
set DataWd 1 
if {${::AESL::PGuard_autoexp_gen}} {
if {[info proc cg_default_interface_gen_clock] == "cg_default_interface_gen_clock"} {
eval "cg_default_interface_gen_clock { \
    id -2 \
    name ${PortName} \
    reset_level 1 \
    sync_rst true \
    corename apif_ap_clk \
    data_wd ${DataWd} \
    op interface \
}"
} else {
puts "@W \[IMPL-113\] Cannot find bus interface model in the library. Ignored generation of bus interface for '${PortName}'"
}
}


# Adapter definition:
set PortName ap_rst
set DataWd 1 
if {${::AESL::PGuard_autoexp_gen}} {
if {[info proc cg_default_interface_gen_reset] == "cg_default_interface_gen_reset"} {
eval "cg_default_interface_gen_reset { \
    id -3 \
    name ${PortName} \
    reset_level 1 \
    sync_rst true \
    corename apif_ap_rst \
    data_wd ${DataWd} \
    op interface \
}"
} else {
puts "@W \[IMPL-114\] Cannot find bus interface model in the library. Ignored generation of bus interface for '${PortName}'"
}
}



# merge
if {${::AESL::PGuard_autoexp_gen}} {
    cg_default_interface_gen_dc_end
    cg_default_interface_gen_bundle_end
    AESL_LIB_XILADAPTER::native_axis_end
}


# flow_control definition:
set InstName pov_eta_wr_flow_control_loop_pipe_sequential_init_U
set CompName pov_eta_wr_flow_control_loop_pipe_sequential_init
set name flow_control_loop_pipe_sequential_init
if {${::AESL::PGuard_autocg_gen} && ${::AESL::PGuard_autocg_ipmgen}} {
if {[info proc ::AESL_LIB_VIRTEX::xil_gen_UPC_flow_control] == "::AESL_LIB_VIRTEX::xil_gen_UPC_flow_control"} {
eval "::AESL_LIB_VIRTEX::xil_gen_UPC_flow_control { \
    name ${name} \
    prefix pov_eta_wr_ \
}"
} else {
puts "@W \[IMPL-107\] Cannot find ::AESL_LIB_VIRTEX::xil_gen_UPC_flow_control, check your platform lib"
}
}


if {${::AESL::PGuard_rtl_comp_handler}} {
	::AP::rtl_comp_handler $CompName BINDTYPE interface TYPE internal_upc_flow_control INSTNAME $InstName
}


