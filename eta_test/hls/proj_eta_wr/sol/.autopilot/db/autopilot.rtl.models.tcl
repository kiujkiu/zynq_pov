set SynModuleInfo {
  {SRCNAME pov_eta_wr_Pipeline_SLICES_COLUMNS_COPY_COLUMN MODELNAME pov_eta_wr_Pipeline_SLICES_COLUMNS_COPY_COLUMN RTLNAME pov_eta_wr_pov_eta_wr_Pipeline_SLICES_COLUMNS_COPY_COLUMN
    SUBMODULES {
      {MODELNAME pov_eta_wr_mul_10s_32s_32_3_1 RTLNAME pov_eta_wr_mul_10s_32s_32_3_1 BINDTYPE op TYPE mul IMPL auto LATENCY 2 ALLOW_PRAGMA 1}
      {MODELNAME pov_eta_wr_srem_32ns_11ns_32_36_1 RTLNAME pov_eta_wr_srem_32ns_11ns_32_36_1 BINDTYPE op TYPE srem IMPL auto LATENCY 35 ALLOW_PRAGMA 1}
      {MODELNAME pov_eta_wr_mul_16ns_10ns_25_1_1 RTLNAME pov_eta_wr_mul_16ns_10ns_25_1_1 BINDTYPE op TYPE mul IMPL auto LATENCY 0 ALLOW_PRAGMA 1}
      {MODELNAME pov_eta_wr_mac_muladd_10s_8s_25s_25_4_1 RTLNAME pov_eta_wr_mac_muladd_10s_8s_25s_25_4_1 BINDTYPE op TYPE all IMPL dsp_slice LATENCY 3}
      {MODELNAME pov_eta_wr_pov_eta_wr_Pipeline_SLICES_COLUMNS_COPY_COLUMN_PV2_COS8_ROM_AUTO_1R RTLNAME pov_eta_wr_pov_eta_wr_Pipeline_SLICES_COLUMNS_COPY_COLUMN_PV2_COS8_ROM_AUTO_1R BINDTYPE storage TYPE rom IMPL auto LATENCY 2 ALLOW_PRAGMA 1}
      {MODELNAME pov_eta_wr_pov_eta_wr_Pipeline_SLICES_COLUMNS_COPY_COLUMN_PV2_SIN8_ROM_AUTO_1R RTLNAME pov_eta_wr_pov_eta_wr_Pipeline_SLICES_COLUMNS_COPY_COLUMN_PV2_SIN8_ROM_AUTO_1R BINDTYPE storage TYPE rom IMPL auto LATENCY 2 ALLOW_PRAGMA 1}
      {MODELNAME pov_eta_wr_flow_control_loop_pipe_sequential_init RTLNAME pov_eta_wr_flow_control_loop_pipe_sequential_init BINDTYPE interface TYPE internal_upc_flow_control INSTNAME pov_eta_wr_flow_control_loop_pipe_sequential_init_U}
    }
  }
  {SRCNAME pov_eta_wr MODELNAME pov_eta_wr RTLNAME pov_eta_wr IS_TOP 1
    SUBMODULES {
      {MODELNAME pov_eta_wr_vox_m_axi RTLNAME pov_eta_wr_vox_m_axi BINDTYPE interface TYPE adapter IMPL m_axi}
      {MODELNAME pov_eta_wr_out_r_m_axi RTLNAME pov_eta_wr_out_r_m_axi BINDTYPE interface TYPE adapter IMPL m_axi}
      {MODELNAME pov_eta_wr_control_s_axi RTLNAME pov_eta_wr_control_s_axi BINDTYPE interface TYPE interface_s_axilite}
    }
  }
}
