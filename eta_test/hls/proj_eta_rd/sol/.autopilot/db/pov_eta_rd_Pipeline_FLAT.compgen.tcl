# This script segment is generated automatically by AutoPilot

set name pov_eta_rd_mul_10s_32s_32_3_1
if {${::AESL::PGuard_rtl_comp_handler}} {
	::AP::rtl_comp_handler $name BINDTYPE {op} TYPE {mul} IMPL {auto} LATENCY 2 ALLOW_PRAGMA 1
}


set name pov_eta_rd_mul_20ns_7ns_26_4_1
if {${::AESL::PGuard_rtl_comp_handler}} {
	::AP::rtl_comp_handler $name BINDTYPE {op} TYPE {mul} IMPL {auto} LATENCY 3 ALLOW_PRAGMA 1
}


set name pov_eta_rd_mul_16ns_7ns_21_1_1
if {${::AESL::PGuard_rtl_comp_handler}} {
	::AP::rtl_comp_handler $name BINDTYPE {op} TYPE {mul} IMPL {auto} LATENCY 0 ALLOW_PRAGMA 1
}


if {${::AESL::PGuard_rtl_comp_handler}} {
	::AP::rtl_comp_handler pov_eta_rd_mac_muladd_21s_10s_8ns_29_4_1 BINDTYPE {op} TYPE {all} IMPL {dsp_slice} LATENCY 3
}


if {${::AESL::PGuard_rtl_comp_handler}} {
	::AP::rtl_comp_handler pov_eta_rd_mac_muladd_21s_10s_25s_29_4_1 BINDTYPE {op} TYPE {all} IMPL {dsp_slice} LATENCY 3
}


if {${::AESL::PGuard_rtl_comp_handler}} {
	::AP::rtl_comp_handler pov_eta_rd_pov_eta_rd_Pipeline_FLAT_PV2_COS8_ROM_AUTO_1R BINDTYPE {storage} TYPE {rom} IMPL {auto} LATENCY 2 ALLOW_PRAGMA 1
}


if {${::AESL::PGuard_rtl_comp_handler}} {
	::AP::rtl_comp_handler pov_eta_rd_pov_eta_rd_Pipeline_FLAT_PV2_SIN8_ROM_AUTO_1R BINDTYPE {storage} TYPE {rom} IMPL {auto} LATENCY 2 ALLOW_PRAGMA 1
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
    id 14 \
    name vox \
    type other \
    dir I \
    reset_level 1 \
    sync_rst true \
    corename dc_vox \
    op interface \
    ports { m_axi_vox_0_AWVALID { O 1 bit } m_axi_vox_0_AWREADY { I 1 bit } m_axi_vox_0_AWADDR { O 64 vector } m_axi_vox_0_AWID { O 1 vector } m_axi_vox_0_AWLEN { O 32 vector } m_axi_vox_0_AWSIZE { O 3 vector } m_axi_vox_0_AWBURST { O 2 vector } m_axi_vox_0_AWLOCK { O 2 vector } m_axi_vox_0_AWCACHE { O 4 vector } m_axi_vox_0_AWPROT { O 3 vector } m_axi_vox_0_AWQOS { O 4 vector } m_axi_vox_0_AWREGION { O 4 vector } m_axi_vox_0_AWUSER { O 1 vector } m_axi_vox_0_WVALID { O 1 bit } m_axi_vox_0_WREADY { I 1 bit } m_axi_vox_0_WDATA { O 64 vector } m_axi_vox_0_WSTRB { O 8 vector } m_axi_vox_0_WLAST { O 1 bit } m_axi_vox_0_WID { O 1 vector } m_axi_vox_0_WUSER { O 1 vector } m_axi_vox_0_ARVALID { O 1 bit } m_axi_vox_0_ARREADY { I 1 bit } m_axi_vox_0_ARADDR { O 64 vector } m_axi_vox_0_ARID { O 1 vector } m_axi_vox_0_ARLEN { O 32 vector } m_axi_vox_0_ARSIZE { O 3 vector } m_axi_vox_0_ARBURST { O 2 vector } m_axi_vox_0_ARLOCK { O 2 vector } m_axi_vox_0_ARCACHE { O 4 vector } m_axi_vox_0_ARPROT { O 3 vector } m_axi_vox_0_ARQOS { O 4 vector } m_axi_vox_0_ARREGION { O 4 vector } m_axi_vox_0_ARUSER { O 1 vector } m_axi_vox_0_RVALID { I 1 bit } m_axi_vox_0_RREADY { O 1 bit } m_axi_vox_0_RDATA { I 64 vector } m_axi_vox_0_RLAST { I 1 bit } m_axi_vox_0_RID { I 1 vector } m_axi_vox_0_RFIFONUM { I 10 vector } m_axi_vox_0_RUSER { I 1 vector } m_axi_vox_0_RRESP { I 2 vector } m_axi_vox_0_BVALID { I 1 bit } m_axi_vox_0_BREADY { O 1 bit } m_axi_vox_0_BRESP { I 2 vector } m_axi_vox_0_BID { I 1 vector } m_axi_vox_0_BUSER { I 1 vector } } \
} "
}

# Direct connection:
if {${::AESL::PGuard_autoexp_gen}} {
eval "cg_default_interface_gen_dc { \
    id 15 \
    name mul_ln65 \
    type other \
    dir I \
    reset_level 1 \
    sync_rst true \
    corename dc_mul_ln65 \
    op interface \
    ports { mul_ln65 { I 26 vector } } \
} "
}

# Direct connection:
if {${::AESL::PGuard_autoexp_gen}} {
eval "cg_default_interface_gen_dc { \
    id 16 \
    name zext_ln52 \
    type other \
    dir I \
    reset_level 1 \
    sync_rst true \
    corename dc_zext_ln52 \
    op interface \
    ports { zext_ln52 { I 3 vector } } \
} "
}

# Direct connection:
if {${::AESL::PGuard_autoexp_gen}} {
eval "cg_default_interface_gen_dc { \
    id 17 \
    name zext_ln59 \
    type other \
    dir I \
    reset_level 1 \
    sync_rst true \
    corename dc_zext_ln59 \
    op interface \
    ports { zext_ln59 { I 20 vector } } \
} "
}

# Direct connection:
if {${::AESL::PGuard_autoexp_gen}} {
eval "cg_default_interface_gen_dc { \
    id 18 \
    name zext_ln56 \
    type other \
    dir I \
    reset_level 1 \
    sync_rst true \
    corename dc_zext_ln56 \
    op interface \
    ports { zext_ln56 { I 10 vector } } \
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
    id 22 \
    name acc_out \
    type other \
    dir O \
    reset_level 1 \
    sync_rst true \
    corename dc_acc_out \
    op interface \
    ports { acc_out { O 64 vector } acc_out_ap_vld { O 1 bit } } \
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
set InstName pov_eta_rd_flow_control_loop_pipe_sequential_init_U
set CompName pov_eta_rd_flow_control_loop_pipe_sequential_init
set name flow_control_loop_pipe_sequential_init
if {${::AESL::PGuard_autocg_gen} && ${::AESL::PGuard_autocg_ipmgen}} {
if {[info proc ::AESL_LIB_VIRTEX::xil_gen_UPC_flow_control] == "::AESL_LIB_VIRTEX::xil_gen_UPC_flow_control"} {
eval "::AESL_LIB_VIRTEX::xil_gen_UPC_flow_control { \
    name ${name} \
    prefix pov_eta_rd_ \
}"
} else {
puts "@W \[IMPL-107\] Cannot find ::AESL_LIB_VIRTEX::xil_gen_UPC_flow_control, check your platform lib"
}
}


if {${::AESL::PGuard_rtl_comp_handler}} {
	::AP::rtl_comp_handler $CompName BINDTYPE interface TYPE internal_upc_flow_control INSTNAME $InstName
}


