set moduleName pov_eta_rd_Pipeline_FLAT
set isTopModule 0
set isCombinational 0
set isDatapathOnly 0
set isPipelined 1
set pipeline_type loop_auto_rewind
set FunctionProtocol ap_ctrl_hs
set isOneStateSeq 0
set ProfileFlag 0
set StallSigGenFlag 0
set isEnableWaveformDebug 1
set hasInterrupt 0
set DLRegFirstOffset 0
set DLRegItemOffset 0
set svuvm_can_support 1
set cdfgNum 4
set C_modelName {pov_eta_rd_Pipeline_FLAT}
set C_modelType { void 0 }
set ap_memory_interface_dict [dict create]
set C_modelArgList {
	{ vox int 64 regular {axi_master 0}  }
	{ mul_ln65 int 26 regular  }
	{ zext_ln52 int 3 regular  }
	{ zext_ln59 int 20 regular  }
	{ zext_ln56 int 10 regular  }
	{ axis_off_q8 int 32 regular  }
	{ voxel int 64 regular  }
	{ mirror_u int 32 regular  }
	{ acc_out int 64 regular {pointer 1}  }
}
set hasAXIMCache 0
set l_AXIML2Cache [list]
set AXIMCacheInstDict [dict create]
set C_modelArgMapList {[ 
	{ "Name" : "vox", "interface" : "axi_master", "bitwidth" : 64, "direction" : "READONLY", "bitSlice":[ {"cElement": [{"cName": "voxel","offset": { "type": "dynamic","port_name": "voxel","bundle": "control"},"direction": "READONLY"}]}]} , 
 	{ "Name" : "mul_ln65", "interface" : "wire", "bitwidth" : 26, "direction" : "READONLY"} , 
 	{ "Name" : "zext_ln52", "interface" : "wire", "bitwidth" : 3, "direction" : "READONLY"} , 
 	{ "Name" : "zext_ln59", "interface" : "wire", "bitwidth" : 20, "direction" : "READONLY"} , 
 	{ "Name" : "zext_ln56", "interface" : "wire", "bitwidth" : 10, "direction" : "READONLY"} , 
 	{ "Name" : "axis_off_q8", "interface" : "wire", "bitwidth" : 32, "direction" : "READONLY"} , 
 	{ "Name" : "voxel", "interface" : "wire", "bitwidth" : 64, "direction" : "READONLY"} , 
 	{ "Name" : "mirror_u", "interface" : "wire", "bitwidth" : 32, "direction" : "READONLY"} , 
 	{ "Name" : "acc_out", "interface" : "wire", "bitwidth" : 64, "direction" : "WRITEONLY"} ]}
# RTL Port declarations: 
set portNum 61
set portList { 
	{ ap_clk sc_in sc_logic 1 clock -1 } 
	{ ap_rst sc_in sc_logic 1 reset -1 active_high_sync } 
	{ ap_start sc_in sc_logic 1 start -1 } 
	{ ap_done sc_out sc_logic 1 predone -1 } 
	{ ap_idle sc_out sc_logic 1 done -1 } 
	{ ap_ready sc_out sc_logic 1 ready -1 } 
	{ m_axi_vox_0_AWVALID sc_out sc_logic 1 signal 0 } 
	{ m_axi_vox_0_AWREADY sc_in sc_logic 1 signal 0 } 
	{ m_axi_vox_0_AWADDR sc_out sc_lv 64 signal 0 } 
	{ m_axi_vox_0_AWID sc_out sc_lv 1 signal 0 } 
	{ m_axi_vox_0_AWLEN sc_out sc_lv 32 signal 0 } 
	{ m_axi_vox_0_AWSIZE sc_out sc_lv 3 signal 0 } 
	{ m_axi_vox_0_AWBURST sc_out sc_lv 2 signal 0 } 
	{ m_axi_vox_0_AWLOCK sc_out sc_lv 2 signal 0 } 
	{ m_axi_vox_0_AWCACHE sc_out sc_lv 4 signal 0 } 
	{ m_axi_vox_0_AWPROT sc_out sc_lv 3 signal 0 } 
	{ m_axi_vox_0_AWQOS sc_out sc_lv 4 signal 0 } 
	{ m_axi_vox_0_AWREGION sc_out sc_lv 4 signal 0 } 
	{ m_axi_vox_0_AWUSER sc_out sc_lv 1 signal 0 } 
	{ m_axi_vox_0_WVALID sc_out sc_logic 1 signal 0 } 
	{ m_axi_vox_0_WREADY sc_in sc_logic 1 signal 0 } 
	{ m_axi_vox_0_WDATA sc_out sc_lv 64 signal 0 } 
	{ m_axi_vox_0_WSTRB sc_out sc_lv 8 signal 0 } 
	{ m_axi_vox_0_WLAST sc_out sc_logic 1 signal 0 } 
	{ m_axi_vox_0_WID sc_out sc_lv 1 signal 0 } 
	{ m_axi_vox_0_WUSER sc_out sc_lv 1 signal 0 } 
	{ m_axi_vox_0_ARVALID sc_out sc_logic 1 signal 0 } 
	{ m_axi_vox_0_ARREADY sc_in sc_logic 1 signal 0 } 
	{ m_axi_vox_0_ARADDR sc_out sc_lv 64 signal 0 } 
	{ m_axi_vox_0_ARID sc_out sc_lv 1 signal 0 } 
	{ m_axi_vox_0_ARLEN sc_out sc_lv 32 signal 0 } 
	{ m_axi_vox_0_ARSIZE sc_out sc_lv 3 signal 0 } 
	{ m_axi_vox_0_ARBURST sc_out sc_lv 2 signal 0 } 
	{ m_axi_vox_0_ARLOCK sc_out sc_lv 2 signal 0 } 
	{ m_axi_vox_0_ARCACHE sc_out sc_lv 4 signal 0 } 
	{ m_axi_vox_0_ARPROT sc_out sc_lv 3 signal 0 } 
	{ m_axi_vox_0_ARQOS sc_out sc_lv 4 signal 0 } 
	{ m_axi_vox_0_ARREGION sc_out sc_lv 4 signal 0 } 
	{ m_axi_vox_0_ARUSER sc_out sc_lv 1 signal 0 } 
	{ m_axi_vox_0_RVALID sc_in sc_logic 1 signal 0 } 
	{ m_axi_vox_0_RREADY sc_out sc_logic 1 signal 0 } 
	{ m_axi_vox_0_RDATA sc_in sc_lv 64 signal 0 } 
	{ m_axi_vox_0_RLAST sc_in sc_logic 1 signal 0 } 
	{ m_axi_vox_0_RID sc_in sc_lv 1 signal 0 } 
	{ m_axi_vox_0_RFIFONUM sc_in sc_lv 10 signal 0 } 
	{ m_axi_vox_0_RUSER sc_in sc_lv 1 signal 0 } 
	{ m_axi_vox_0_RRESP sc_in sc_lv 2 signal 0 } 
	{ m_axi_vox_0_BVALID sc_in sc_logic 1 signal 0 } 
	{ m_axi_vox_0_BREADY sc_out sc_logic 1 signal 0 } 
	{ m_axi_vox_0_BRESP sc_in sc_lv 2 signal 0 } 
	{ m_axi_vox_0_BID sc_in sc_lv 1 signal 0 } 
	{ m_axi_vox_0_BUSER sc_in sc_lv 1 signal 0 } 
	{ mul_ln65 sc_in sc_lv 26 signal 1 } 
	{ zext_ln52 sc_in sc_lv 3 signal 2 } 
	{ zext_ln59 sc_in sc_lv 20 signal 3 } 
	{ zext_ln56 sc_in sc_lv 10 signal 4 } 
	{ axis_off_q8 sc_in sc_lv 32 signal 5 } 
	{ voxel sc_in sc_lv 64 signal 6 } 
	{ mirror_u sc_in sc_lv 32 signal 7 } 
	{ acc_out sc_out sc_lv 64 signal 8 } 
	{ acc_out_ap_vld sc_out sc_logic 1 outvld 8 } 
}
set NewPortList {[ 
	{ "name": "ap_clk", "direction": "in", "datatype": "sc_logic", "bitwidth":1, "type": "clock", "bundle":{"name": "ap_clk", "role": "default" }} , 
 	{ "name": "ap_rst", "direction": "in", "datatype": "sc_logic", "bitwidth":1, "type": "reset", "bundle":{"name": "ap_rst", "role": "default" }} , 
 	{ "name": "ap_start", "direction": "in", "datatype": "sc_logic", "bitwidth":1, "type": "start", "bundle":{"name": "ap_start", "role": "default" }} , 
 	{ "name": "ap_done", "direction": "out", "datatype": "sc_logic", "bitwidth":1, "type": "predone", "bundle":{"name": "ap_done", "role": "default" }} , 
 	{ "name": "ap_idle", "direction": "out", "datatype": "sc_logic", "bitwidth":1, "type": "done", "bundle":{"name": "ap_idle", "role": "default" }} , 
 	{ "name": "ap_ready", "direction": "out", "datatype": "sc_logic", "bitwidth":1, "type": "ready", "bundle":{"name": "ap_ready", "role": "default" }} , 
 	{ "name": "m_axi_vox_0_AWVALID", "direction": "out", "datatype": "sc_logic", "bitwidth":1, "type": "signal", "bundle":{"name": "vox", "role": "0_AWVALID" }} , 
 	{ "name": "m_axi_vox_0_AWREADY", "direction": "in", "datatype": "sc_logic", "bitwidth":1, "type": "signal", "bundle":{"name": "vox", "role": "0_AWREADY" }} , 
 	{ "name": "m_axi_vox_0_AWADDR", "direction": "out", "datatype": "sc_lv", "bitwidth":64, "type": "signal", "bundle":{"name": "vox", "role": "0_AWADDR" }} , 
 	{ "name": "m_axi_vox_0_AWID", "direction": "out", "datatype": "sc_lv", "bitwidth":1, "type": "signal", "bundle":{"name": "vox", "role": "0_AWID" }} , 
 	{ "name": "m_axi_vox_0_AWLEN", "direction": "out", "datatype": "sc_lv", "bitwidth":32, "type": "signal", "bundle":{"name": "vox", "role": "0_AWLEN" }} , 
 	{ "name": "m_axi_vox_0_AWSIZE", "direction": "out", "datatype": "sc_lv", "bitwidth":3, "type": "signal", "bundle":{"name": "vox", "role": "0_AWSIZE" }} , 
 	{ "name": "m_axi_vox_0_AWBURST", "direction": "out", "datatype": "sc_lv", "bitwidth":2, "type": "signal", "bundle":{"name": "vox", "role": "0_AWBURST" }} , 
 	{ "name": "m_axi_vox_0_AWLOCK", "direction": "out", "datatype": "sc_lv", "bitwidth":2, "type": "signal", "bundle":{"name": "vox", "role": "0_AWLOCK" }} , 
 	{ "name": "m_axi_vox_0_AWCACHE", "direction": "out", "datatype": "sc_lv", "bitwidth":4, "type": "signal", "bundle":{"name": "vox", "role": "0_AWCACHE" }} , 
 	{ "name": "m_axi_vox_0_AWPROT", "direction": "out", "datatype": "sc_lv", "bitwidth":3, "type": "signal", "bundle":{"name": "vox", "role": "0_AWPROT" }} , 
 	{ "name": "m_axi_vox_0_AWQOS", "direction": "out", "datatype": "sc_lv", "bitwidth":4, "type": "signal", "bundle":{"name": "vox", "role": "0_AWQOS" }} , 
 	{ "name": "m_axi_vox_0_AWREGION", "direction": "out", "datatype": "sc_lv", "bitwidth":4, "type": "signal", "bundle":{"name": "vox", "role": "0_AWREGION" }} , 
 	{ "name": "m_axi_vox_0_AWUSER", "direction": "out", "datatype": "sc_lv", "bitwidth":1, "type": "signal", "bundle":{"name": "vox", "role": "0_AWUSER" }} , 
 	{ "name": "m_axi_vox_0_WVALID", "direction": "out", "datatype": "sc_logic", "bitwidth":1, "type": "signal", "bundle":{"name": "vox", "role": "0_WVALID" }} , 
 	{ "name": "m_axi_vox_0_WREADY", "direction": "in", "datatype": "sc_logic", "bitwidth":1, "type": "signal", "bundle":{"name": "vox", "role": "0_WREADY" }} , 
 	{ "name": "m_axi_vox_0_WDATA", "direction": "out", "datatype": "sc_lv", "bitwidth":64, "type": "signal", "bundle":{"name": "vox", "role": "0_WDATA" }} , 
 	{ "name": "m_axi_vox_0_WSTRB", "direction": "out", "datatype": "sc_lv", "bitwidth":8, "type": "signal", "bundle":{"name": "vox", "role": "0_WSTRB" }} , 
 	{ "name": "m_axi_vox_0_WLAST", "direction": "out", "datatype": "sc_logic", "bitwidth":1, "type": "signal", "bundle":{"name": "vox", "role": "0_WLAST" }} , 
 	{ "name": "m_axi_vox_0_WID", "direction": "out", "datatype": "sc_lv", "bitwidth":1, "type": "signal", "bundle":{"name": "vox", "role": "0_WID" }} , 
 	{ "name": "m_axi_vox_0_WUSER", "direction": "out", "datatype": "sc_lv", "bitwidth":1, "type": "signal", "bundle":{"name": "vox", "role": "0_WUSER" }} , 
 	{ "name": "m_axi_vox_0_ARVALID", "direction": "out", "datatype": "sc_logic", "bitwidth":1, "type": "signal", "bundle":{"name": "vox", "role": "0_ARVALID" }} , 
 	{ "name": "m_axi_vox_0_ARREADY", "direction": "in", "datatype": "sc_logic", "bitwidth":1, "type": "signal", "bundle":{"name": "vox", "role": "0_ARREADY" }} , 
 	{ "name": "m_axi_vox_0_ARADDR", "direction": "out", "datatype": "sc_lv", "bitwidth":64, "type": "signal", "bundle":{"name": "vox", "role": "0_ARADDR" }} , 
 	{ "name": "m_axi_vox_0_ARID", "direction": "out", "datatype": "sc_lv", "bitwidth":1, "type": "signal", "bundle":{"name": "vox", "role": "0_ARID" }} , 
 	{ "name": "m_axi_vox_0_ARLEN", "direction": "out", "datatype": "sc_lv", "bitwidth":32, "type": "signal", "bundle":{"name": "vox", "role": "0_ARLEN" }} , 
 	{ "name": "m_axi_vox_0_ARSIZE", "direction": "out", "datatype": "sc_lv", "bitwidth":3, "type": "signal", "bundle":{"name": "vox", "role": "0_ARSIZE" }} , 
 	{ "name": "m_axi_vox_0_ARBURST", "direction": "out", "datatype": "sc_lv", "bitwidth":2, "type": "signal", "bundle":{"name": "vox", "role": "0_ARBURST" }} , 
 	{ "name": "m_axi_vox_0_ARLOCK", "direction": "out", "datatype": "sc_lv", "bitwidth":2, "type": "signal", "bundle":{"name": "vox", "role": "0_ARLOCK" }} , 
 	{ "name": "m_axi_vox_0_ARCACHE", "direction": "out", "datatype": "sc_lv", "bitwidth":4, "type": "signal", "bundle":{"name": "vox", "role": "0_ARCACHE" }} , 
 	{ "name": "m_axi_vox_0_ARPROT", "direction": "out", "datatype": "sc_lv", "bitwidth":3, "type": "signal", "bundle":{"name": "vox", "role": "0_ARPROT" }} , 
 	{ "name": "m_axi_vox_0_ARQOS", "direction": "out", "datatype": "sc_lv", "bitwidth":4, "type": "signal", "bundle":{"name": "vox", "role": "0_ARQOS" }} , 
 	{ "name": "m_axi_vox_0_ARREGION", "direction": "out", "datatype": "sc_lv", "bitwidth":4, "type": "signal", "bundle":{"name": "vox", "role": "0_ARREGION" }} , 
 	{ "name": "m_axi_vox_0_ARUSER", "direction": "out", "datatype": "sc_lv", "bitwidth":1, "type": "signal", "bundle":{"name": "vox", "role": "0_ARUSER" }} , 
 	{ "name": "m_axi_vox_0_RVALID", "direction": "in", "datatype": "sc_logic", "bitwidth":1, "type": "signal", "bundle":{"name": "vox", "role": "0_RVALID" }} , 
 	{ "name": "m_axi_vox_0_RREADY", "direction": "out", "datatype": "sc_logic", "bitwidth":1, "type": "signal", "bundle":{"name": "vox", "role": "0_RREADY" }} , 
 	{ "name": "m_axi_vox_0_RDATA", "direction": "in", "datatype": "sc_lv", "bitwidth":64, "type": "signal", "bundle":{"name": "vox", "role": "0_RDATA" }} , 
 	{ "name": "m_axi_vox_0_RLAST", "direction": "in", "datatype": "sc_logic", "bitwidth":1, "type": "signal", "bundle":{"name": "vox", "role": "0_RLAST" }} , 
 	{ "name": "m_axi_vox_0_RID", "direction": "in", "datatype": "sc_lv", "bitwidth":1, "type": "signal", "bundle":{"name": "vox", "role": "0_RID" }} , 
 	{ "name": "m_axi_vox_0_RFIFONUM", "direction": "in", "datatype": "sc_lv", "bitwidth":10, "type": "signal", "bundle":{"name": "vox", "role": "0_RFIFONUM" }} , 
 	{ "name": "m_axi_vox_0_RUSER", "direction": "in", "datatype": "sc_lv", "bitwidth":1, "type": "signal", "bundle":{"name": "vox", "role": "0_RUSER" }} , 
 	{ "name": "m_axi_vox_0_RRESP", "direction": "in", "datatype": "sc_lv", "bitwidth":2, "type": "signal", "bundle":{"name": "vox", "role": "0_RRESP" }} , 
 	{ "name": "m_axi_vox_0_BVALID", "direction": "in", "datatype": "sc_logic", "bitwidth":1, "type": "signal", "bundle":{"name": "vox", "role": "0_BVALID" }} , 
 	{ "name": "m_axi_vox_0_BREADY", "direction": "out", "datatype": "sc_logic", "bitwidth":1, "type": "signal", "bundle":{"name": "vox", "role": "0_BREADY" }} , 
 	{ "name": "m_axi_vox_0_BRESP", "direction": "in", "datatype": "sc_lv", "bitwidth":2, "type": "signal", "bundle":{"name": "vox", "role": "0_BRESP" }} , 
 	{ "name": "m_axi_vox_0_BID", "direction": "in", "datatype": "sc_lv", "bitwidth":1, "type": "signal", "bundle":{"name": "vox", "role": "0_BID" }} , 
 	{ "name": "m_axi_vox_0_BUSER", "direction": "in", "datatype": "sc_lv", "bitwidth":1, "type": "signal", "bundle":{"name": "vox", "role": "0_BUSER" }} , 
 	{ "name": "mul_ln65", "direction": "in", "datatype": "sc_lv", "bitwidth":26, "type": "signal", "bundle":{"name": "mul_ln65", "role": "default" }} , 
 	{ "name": "zext_ln52", "direction": "in", "datatype": "sc_lv", "bitwidth":3, "type": "signal", "bundle":{"name": "zext_ln52", "role": "default" }} , 
 	{ "name": "zext_ln59", "direction": "in", "datatype": "sc_lv", "bitwidth":20, "type": "signal", "bundle":{"name": "zext_ln59", "role": "default" }} , 
 	{ "name": "zext_ln56", "direction": "in", "datatype": "sc_lv", "bitwidth":10, "type": "signal", "bundle":{"name": "zext_ln56", "role": "default" }} , 
 	{ "name": "axis_off_q8", "direction": "in", "datatype": "sc_lv", "bitwidth":32, "type": "signal", "bundle":{"name": "axis_off_q8", "role": "default" }} , 
 	{ "name": "voxel", "direction": "in", "datatype": "sc_lv", "bitwidth":64, "type": "signal", "bundle":{"name": "voxel", "role": "default" }} , 
 	{ "name": "mirror_u", "direction": "in", "datatype": "sc_lv", "bitwidth":32, "type": "signal", "bundle":{"name": "mirror_u", "role": "default" }} , 
 	{ "name": "acc_out", "direction": "out", "datatype": "sc_lv", "bitwidth":64, "type": "signal", "bundle":{"name": "acc_out", "role": "default" }} , 
 	{ "name": "acc_out_ap_vld", "direction": "out", "datatype": "sc_logic", "bitwidth":1, "type": "outvld", "bundle":{"name": "acc_out", "role": "ap_vld" }}  ]}

set RtlHierarchyInfo {[
	{"ID" : "0", "Level" : "0", "Path" : "`AUTOTB_DUT_INST", "Parent" : "", "Child" : ["1", "2", "3", "4", "5", "6", "7", "8", "9"],
		"CDFG" : "pov_eta_rd_Pipeline_FLAT",
		"Protocol" : "ap_ctrl_hs",
		"ControlExist" : "1", "ap_start" : "1", "ap_ready" : "1", "ap_done" : "1", "ap_continue" : "0", "ap_idle" : "1", "real_start" : "0",
		"Pipeline" : "None", "UnalignedPipeline" : "0", "RewindPipeline" : "0", "ProcessNetwork" : "0",
		"II" : "0",
		"VariableLatency" : "1", "ExactLatency" : "-1", "EstimateLatencyMin" : "10502", "EstimateLatencyMax" : "6252254",
		"Combinational" : "0",
		"Datapath" : "0",
		"ClockEnable" : "0",
		"HasSubDataflow" : "0",
		"InDataflowNetwork" : "0",
		"HasNonBlockingOperation" : "0",
		"IsBlackBox" : "0",
		"Port" : [
			{"Name" : "vox", "Type" : "MAXI", "Direction" : "I",
				"BlockSignal" : [
					{"Name" : "vox_blk_n_AR", "Type" : "RtlSignal"},
					{"Name" : "vox_blk_n_R", "Type" : "RtlSignal"}]},
			{"Name" : "mul_ln65", "Type" : "None", "Direction" : "I"},
			{"Name" : "zext_ln52", "Type" : "None", "Direction" : "I"},
			{"Name" : "zext_ln59", "Type" : "None", "Direction" : "I"},
			{"Name" : "zext_ln56", "Type" : "None", "Direction" : "I"},
			{"Name" : "axis_off_q8", "Type" : "None", "Direction" : "I"},
			{"Name" : "voxel", "Type" : "None", "Direction" : "I"},
			{"Name" : "mirror_u", "Type" : "None", "Direction" : "I"},
			{"Name" : "acc_out", "Type" : "Vld", "Direction" : "O"},
			{"Name" : "PV2_COS8", "Type" : "Memory", "Direction" : "I"},
			{"Name" : "PV2_SIN8", "Type" : "Memory", "Direction" : "I"}],
		"Loop" : [
			{"Name" : "FLAT", "PipelineType" : "UPC",
				"LoopDec" : {"FSMBitwidth" : "1", "FirstState" : "ap_ST_fsm_pp0_stage0", "FirstStateIter" : "ap_enable_reg_pp0_iter0", "FirstStateBlock" : "ap_block_pp0_stage0_subdone", "LastState" : "ap_ST_fsm_pp0_stage0", "LastStateIter" : "ap_enable_reg_pp0_iter25", "LastStateBlock" : "ap_block_pp0_stage0_subdone", "QuitState" : "ap_ST_fsm_pp0_stage0", "QuitStateIter" : "ap_enable_reg_pp0_iter25", "QuitStateBlock" : "ap_block_pp0_stage0_subdone", "OneDepthLoop" : "0", "has_ap_ctrl" : "1", "has_continue" : "0"}}]},
	{"ID" : "1", "Level" : "1", "Path" : "`AUTOTB_DUT_INST.PV2_COS8_U", "Parent" : "0"},
	{"ID" : "2", "Level" : "1", "Path" : "`AUTOTB_DUT_INST.PV2_SIN8_U", "Parent" : "0"},
	{"ID" : "3", "Level" : "1", "Path" : "`AUTOTB_DUT_INST.mul_10s_32s_32_3_1_U1", "Parent" : "0"},
	{"ID" : "4", "Level" : "1", "Path" : "`AUTOTB_DUT_INST.mul_10s_32s_32_3_1_U2", "Parent" : "0"},
	{"ID" : "5", "Level" : "1", "Path" : "`AUTOTB_DUT_INST.mul_20ns_7ns_26_4_1_U3", "Parent" : "0"},
	{"ID" : "6", "Level" : "1", "Path" : "`AUTOTB_DUT_INST.mul_16ns_7ns_21_1_1_U4", "Parent" : "0"},
	{"ID" : "7", "Level" : "1", "Path" : "`AUTOTB_DUT_INST.mac_muladd_21s_10s_8ns_29_4_1_U5", "Parent" : "0"},
	{"ID" : "8", "Level" : "1", "Path" : "`AUTOTB_DUT_INST.mac_muladd_21s_10s_25s_29_4_1_U6", "Parent" : "0"},
	{"ID" : "9", "Level" : "1", "Path" : "`AUTOTB_DUT_INST.flow_control_loop_pipe_sequential_init_U", "Parent" : "0"}]}


set ArgLastReadFirstWriteLatency {
	pov_eta_rd_Pipeline_FLAT {
		vox {Type I LastRead 24 FirstWrite -1}
		mul_ln65 {Type I LastRead 0 FirstWrite -1}
		zext_ln52 {Type I LastRead 0 FirstWrite -1}
		zext_ln59 {Type I LastRead 0 FirstWrite -1}
		zext_ln56 {Type I LastRead 0 FirstWrite -1}
		axis_off_q8 {Type I LastRead 0 FirstWrite -1}
		voxel {Type I LastRead 0 FirstWrite -1}
		mirror_u {Type I LastRead 0 FirstWrite -1}
		acc_out {Type O LastRead -1 FirstWrite 24}
		PV2_COS8 {Type I LastRead -1 FirstWrite -1}
		PV2_SIN8 {Type I LastRead -1 FirstWrite -1}}}

set hasDtUnsupportedChannel 0

set PerformanceInfo {[
	{"Name" : "Latency", "Min" : "10502", "Max" : "6252254"}
	, {"Name" : "Interval", "Min" : "10502", "Max" : "6252254"}
]}

set PipelineEnableSignalInfo {[
	{"Pipeline" : "0", "EnableSignal" : "ap_enable_pp0"}
]}

set Spec2ImplPortList { 
	 { m_axi {  { m_axi_vox_0_AWVALID VALID 1 1 }  { m_axi_vox_0_AWREADY READY 0 1 }  { m_axi_vox_0_AWADDR ADDR 1 64 }  { m_axi_vox_0_AWID ID 1 1 }  { m_axi_vox_0_AWLEN SIZE 1 32 }  { m_axi_vox_0_AWSIZE BURST 1 3 }  { m_axi_vox_0_AWBURST LOCK 1 2 }  { m_axi_vox_0_AWLOCK CACHE 1 2 }  { m_axi_vox_0_AWCACHE PROT 1 4 }  { m_axi_vox_0_AWPROT QOS 1 3 }  { m_axi_vox_0_AWQOS REGION 1 4 }  { m_axi_vox_0_AWREGION USER 1 4 }  { m_axi_vox_0_AWUSER DATA 1 1 }  { m_axi_vox_0_WVALID VALID 1 1 }  { m_axi_vox_0_WREADY READY 0 1 }  { m_axi_vox_0_WDATA FIFONUM 1 64 }  { m_axi_vox_0_WSTRB STRB 1 8 }  { m_axi_vox_0_WLAST LAST 1 1 }  { m_axi_vox_0_WID ID 1 1 }  { m_axi_vox_0_WUSER DATA 1 1 }  { m_axi_vox_0_ARVALID VALID 1 1 }  { m_axi_vox_0_ARREADY READY 0 1 }  { m_axi_vox_0_ARADDR ADDR 1 64 }  { m_axi_vox_0_ARID ID 1 1 }  { m_axi_vox_0_ARLEN SIZE 1 32 }  { m_axi_vox_0_ARSIZE BURST 1 3 }  { m_axi_vox_0_ARBURST LOCK 1 2 }  { m_axi_vox_0_ARLOCK CACHE 1 2 }  { m_axi_vox_0_ARCACHE PROT 1 4 }  { m_axi_vox_0_ARPROT QOS 1 3 }  { m_axi_vox_0_ARQOS REGION 1 4 }  { m_axi_vox_0_ARREGION USER 1 4 }  { m_axi_vox_0_ARUSER DATA 1 1 }  { m_axi_vox_0_RVALID VALID 0 1 }  { m_axi_vox_0_RREADY READY 1 1 }  { m_axi_vox_0_RDATA FIFONUM 0 64 }  { m_axi_vox_0_RLAST LAST 0 1 }  { m_axi_vox_0_RID ID 0 1 }  { m_axi_vox_0_RFIFONUM LEN 0 10 }  { m_axi_vox_0_RUSER DATA 0 1 }  { m_axi_vox_0_RRESP RESP 0 2 }  { m_axi_vox_0_BVALID VALID 0 1 }  { m_axi_vox_0_BREADY READY 1 1 }  { m_axi_vox_0_BRESP RESP 0 2 }  { m_axi_vox_0_BID ID 0 1 }  { m_axi_vox_0_BUSER DATA 0 1 } } }
	mul_ln65 { ap_none {  { mul_ln65 in_data 0 26 } } }
	zext_ln52 { ap_none {  { zext_ln52 in_data 0 3 } } }
	zext_ln59 { ap_none {  { zext_ln59 in_data 0 20 } } }
	zext_ln56 { ap_none {  { zext_ln56 in_data 0 10 } } }
	axis_off_q8 { ap_none {  { axis_off_q8 in_data 0 32 } } }
	voxel { ap_none {  { voxel in_data 0 64 } } }
	mirror_u { ap_none {  { mirror_u in_data 0 32 } } }
	acc_out { ap_vld {  { acc_out out_data 1 64 }  { acc_out_ap_vld out_vld 1 1 } } }
}
