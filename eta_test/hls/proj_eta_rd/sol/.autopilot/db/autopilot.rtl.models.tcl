set SynModuleInfo {
  {SRCNAME pov_eta_rd_Pipeline_FLAT MODELNAME pov_eta_rd_Pipeline_FLAT RTLNAME pov_eta_rd_pov_eta_rd_Pipeline_FLAT
    SUBMODULES {
      {MODELNAME pov_eta_rd_mul_10s_32s_32_3_1 RTLNAME pov_eta_rd_mul_10s_32s_32_3_1 BINDTYPE op TYPE mul IMPL auto LATENCY 2 ALLOW_PRAGMA 1}
      {MODELNAME pov_eta_rd_mul_20ns_7ns_26_4_1 RTLNAME pov_eta_rd_mul_20ns_7ns_26_4_1 BINDTYPE op TYPE mul IMPL auto LATENCY 3 ALLOW_PRAGMA 1}
      {MODELNAME pov_eta_rd_mul_16ns_7ns_21_1_1 RTLNAME pov_eta_rd_mul_16ns_7ns_21_1_1 BINDTYPE op TYPE mul IMPL auto LATENCY 0 ALLOW_PRAGMA 1}
      {MODELNAME pov_eta_rd_mac_muladd_21s_10s_8ns_29_4_1 RTLNAME pov_eta_rd_mac_muladd_21s_10s_8ns_29_4_1 BINDTYPE op TYPE all IMPL dsp_slice LATENCY 3}
      {MODELNAME pov_eta_rd_mac_muladd_21s_10s_25s_29_4_1 RTLNAME pov_eta_rd_mac_muladd_21s_10s_25s_29_4_1 BINDTYPE op TYPE all IMPL dsp_slice LATENCY 3}
      {MODELNAME pov_eta_rd_pov_eta_rd_Pipeline_FLAT_PV2_COS8_ROM_AUTO_1R RTLNAME pov_eta_rd_pov_eta_rd_Pipeline_FLAT_PV2_COS8_ROM_AUTO_1R BINDTYPE storage TYPE rom IMPL auto LATENCY 2 ALLOW_PRAGMA 1}
      {MODELNAME pov_eta_rd_pov_eta_rd_Pipeline_FLAT_PV2_SIN8_ROM_AUTO_1R RTLNAME pov_eta_rd_pov_eta_rd_Pipeline_FLAT_PV2_SIN8_ROM_AUTO_1R BINDTYPE storage TYPE rom IMPL auto LATENCY 2 ALLOW_PRAGMA 1}
      {MODELNAME pov_eta_rd_flow_control_loop_pipe_sequential_init RTLNAME pov_eta_rd_flow_control_loop_pipe_sequential_init BINDTYPE interface TYPE internal_upc_flow_control INSTNAME pov_eta_rd_flow_control_loop_pipe_sequential_init_U}
    }
  }
  {SRCNAME pov_eta_rd MODELNAME pov_eta_rd RTLNAME pov_eta_rd IS_TOP 1
    SUBMODULES {
      {MODELNAME pov_eta_rd_srem_32ns_11ns_32_36_seq_1 RTLNAME pov_eta_rd_srem_32ns_11ns_32_36_seq_1 BINDTYPE op TYPE srem IMPL auto_seq LATENCY 35 ALLOW_PRAGMA 1}
      {MODELNAME pov_eta_rd_vox_m_axi RTLNAME pov_eta_rd_vox_m_axi BINDTYPE interface TYPE adapter IMPL m_axi}
      {MODELNAME pov_eta_rd_control_s_axi RTLNAME pov_eta_rd_control_s_axi BINDTYPE interface TYPE interface_s_axilite}
    }
  }
}
