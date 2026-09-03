set moduleName pov_eta_wr
set isTopModule 1
set isCombinational 0
set isDatapathOnly 0
set isPipelined 0
set pipeline_type none
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
set C_modelName {pov_eta_wr}
set C_modelType { void 0 }
set ap_memory_interface_dict [dict create]
set C_modelArgList {
	{ vox int 64 regular {axi_master 0}  }
	{ out_r int 64 regular {axi_master 1}  }
	{ voxel int 64 regular {axi_slave 0}  }
	{ slot_base int 64 regular {axi_slave 0}  }
	{ phase int 32 regular {axi_slave 0}  }
	{ slot_start int 32 regular {axi_slave 0}  }
	{ n_slots int 32 regular {axi_slave 0}  }
	{ axis_off_q8 int 32 regular {axi_slave 0}  }
	{ mirror_u int 32 regular {axi_slave 0}  }
}
set hasAXIMCache 0
set l_AXIML2Cache [list]
set AXIMCacheInstDict [dict create]
set C_modelArgMapList {[ 
	{ "Name" : "vox", "interface" : "axi_master", "bitwidth" : 64, "direction" : "READONLY", "bitSlice":[ {"cElement": [{"cName": "voxel","offset": { "type": "dynamic","port_name": "voxel","bundle": "control"},"direction": "READONLY"}]}]} , 
 	{ "Name" : "out_r", "interface" : "axi_master", "bitwidth" : 64, "direction" : "WRITEONLY", "bitSlice":[ {"cElement": [{"cName": "slot_base","offset": { "type": "dynamic","port_name": "slot_base","bundle": "control"},"direction": "WRITEONLY"}]}]} , 
 	{ "Name" : "voxel", "interface" : "axi_slave", "bundle":"control","type":"ap_none","bitwidth" : 64, "direction" : "READONLY", "offset" : {"in":16}, "offset_end" : {"in":27}} , 
 	{ "Name" : "slot_base", "interface" : "axi_slave", "bundle":"control","type":"ap_none","bitwidth" : 64, "direction" : "READONLY", "offset" : {"in":28}, "offset_end" : {"in":39}} , 
 	{ "Name" : "phase", "interface" : "axi_slave", "bundle":"control","type":"ap_none","bitwidth" : 32, "direction" : "READONLY", "offset" : {"in":40}, "offset_end" : {"in":47}} , 
 	{ "Name" : "slot_start", "interface" : "axi_slave", "bundle":"control","type":"ap_none","bitwidth" : 32, "direction" : "READONLY", "offset" : {"in":48}, "offset_end" : {"in":55}} , 
 	{ "Name" : "n_slots", "interface" : "axi_slave", "bundle":"control","type":"ap_none","bitwidth" : 32, "direction" : "READONLY", "offset" : {"in":56}, "offset_end" : {"in":63}} , 
 	{ "Name" : "axis_off_q8", "interface" : "axi_slave", "bundle":"control","type":"ap_none","bitwidth" : 32, "direction" : "READONLY", "offset" : {"in":64}, "offset_end" : {"in":71}} , 
 	{ "Name" : "mirror_u", "interface" : "axi_slave", "bundle":"control","type":"ap_none","bitwidth" : 32, "direction" : "READONLY", "offset" : {"in":72}, "offset_end" : {"in":79}} ]}
# RTL Port declarations: 
set portNum 113
set portList { 
	{ ap_clk sc_in sc_logic 1 clock -1 } 
	{ ap_rst_n sc_in sc_logic 1 reset -1 active_low_sync } 
	{ ap_start sc_in sc_logic 1 start -1 } 
	{ ap_done sc_out sc_logic 1 predone -1 } 
	{ ap_idle sc_out sc_logic 1 done -1 } 
	{ ap_ready sc_out sc_logic 1 ready -1 } 
	{ m_axi_vox_AWVALID sc_out sc_logic 1 signal 0 } 
	{ m_axi_vox_AWREADY sc_in sc_logic 1 signal 0 } 
	{ m_axi_vox_AWADDR sc_out sc_lv 64 signal 0 } 
	{ m_axi_vox_AWID sc_out sc_lv 1 signal 0 } 
	{ m_axi_vox_AWLEN sc_out sc_lv 8 signal 0 } 
	{ m_axi_vox_AWSIZE sc_out sc_lv 3 signal 0 } 
	{ m_axi_vox_AWBURST sc_out sc_lv 2 signal 0 } 
	{ m_axi_vox_AWLOCK sc_out sc_lv 2 signal 0 } 
	{ m_axi_vox_AWCACHE sc_out sc_lv 4 signal 0 } 
	{ m_axi_vox_AWPROT sc_out sc_lv 3 signal 0 } 
	{ m_axi_vox_AWQOS sc_out sc_lv 4 signal 0 } 
	{ m_axi_vox_AWREGION sc_out sc_lv 4 signal 0 } 
	{ m_axi_vox_AWUSER sc_out sc_lv 1 signal 0 } 
	{ m_axi_vox_WVALID sc_out sc_logic 1 signal 0 } 
	{ m_axi_vox_WREADY sc_in sc_logic 1 signal 0 } 
	{ m_axi_vox_WDATA sc_out sc_lv 64 signal 0 } 
	{ m_axi_vox_WSTRB sc_out sc_lv 8 signal 0 } 
	{ m_axi_vox_WLAST sc_out sc_logic 1 signal 0 } 
	{ m_axi_vox_WID sc_out sc_lv 1 signal 0 } 
	{ m_axi_vox_WUSER sc_out sc_lv 1 signal 0 } 
	{ m_axi_vox_ARVALID sc_out sc_logic 1 signal 0 } 
	{ m_axi_vox_ARREADY sc_in sc_logic 1 signal 0 } 
	{ m_axi_vox_ARADDR sc_out sc_lv 64 signal 0 } 
	{ m_axi_vox_ARID sc_out sc_lv 1 signal 0 } 
	{ m_axi_vox_ARLEN sc_out sc_lv 8 signal 0 } 
	{ m_axi_vox_ARSIZE sc_out sc_lv 3 signal 0 } 
	{ m_axi_vox_ARBURST sc_out sc_lv 2 signal 0 } 
	{ m_axi_vox_ARLOCK sc_out sc_lv 2 signal 0 } 
	{ m_axi_vox_ARCACHE sc_out sc_lv 4 signal 0 } 
	{ m_axi_vox_ARPROT sc_out sc_lv 3 signal 0 } 
	{ m_axi_vox_ARQOS sc_out sc_lv 4 signal 0 } 
	{ m_axi_vox_ARREGION sc_out sc_lv 4 signal 0 } 
	{ m_axi_vox_ARUSER sc_out sc_lv 1 signal 0 } 
	{ m_axi_vox_RVALID sc_in sc_logic 1 signal 0 } 
	{ m_axi_vox_RREADY sc_out sc_logic 1 signal 0 } 
	{ m_axi_vox_RDATA sc_in sc_lv 64 signal 0 } 
	{ m_axi_vox_RLAST sc_in sc_logic 1 signal 0 } 
	{ m_axi_vox_RID sc_in sc_lv 1 signal 0 } 
	{ m_axi_vox_RUSER sc_in sc_lv 1 signal 0 } 
	{ m_axi_vox_RRESP sc_in sc_lv 2 signal 0 } 
	{ m_axi_vox_BVALID sc_in sc_logic 1 signal 0 } 
	{ m_axi_vox_BREADY sc_out sc_logic 1 signal 0 } 
	{ m_axi_vox_BRESP sc_in sc_lv 2 signal 0 } 
	{ m_axi_vox_BID sc_in sc_lv 1 signal 0 } 
	{ m_axi_vox_BUSER sc_in sc_lv 1 signal 0 } 
	{ m_axi_out_r_AWVALID sc_out sc_logic 1 signal 1 } 
	{ m_axi_out_r_AWREADY sc_in sc_logic 1 signal 1 } 
	{ m_axi_out_r_AWADDR sc_out sc_lv 64 signal 1 } 
	{ m_axi_out_r_AWID sc_out sc_lv 1 signal 1 } 
	{ m_axi_out_r_AWLEN sc_out sc_lv 8 signal 1 } 
	{ m_axi_out_r_AWSIZE sc_out sc_lv 3 signal 1 } 
	{ m_axi_out_r_AWBURST sc_out sc_lv 2 signal 1 } 
	{ m_axi_out_r_AWLOCK sc_out sc_lv 2 signal 1 } 
	{ m_axi_out_r_AWCACHE sc_out sc_lv 4 signal 1 } 
	{ m_axi_out_r_AWPROT sc_out sc_lv 3 signal 1 } 
	{ m_axi_out_r_AWQOS sc_out sc_lv 4 signal 1 } 
	{ m_axi_out_r_AWREGION sc_out sc_lv 4 signal 1 } 
	{ m_axi_out_r_AWUSER sc_out sc_lv 1 signal 1 } 
	{ m_axi_out_r_WVALID sc_out sc_logic 1 signal 1 } 
	{ m_axi_out_r_WREADY sc_in sc_logic 1 signal 1 } 
	{ m_axi_out_r_WDATA sc_out sc_lv 64 signal 1 } 
	{ m_axi_out_r_WSTRB sc_out sc_lv 8 signal 1 } 
	{ m_axi_out_r_WLAST sc_out sc_logic 1 signal 1 } 
	{ m_axi_out_r_WID sc_out sc_lv 1 signal 1 } 
	{ m_axi_out_r_WUSER sc_out sc_lv 1 signal 1 } 
	{ m_axi_out_r_ARVALID sc_out sc_logic 1 signal 1 } 
	{ m_axi_out_r_ARREADY sc_in sc_logic 1 signal 1 } 
	{ m_axi_out_r_ARADDR sc_out sc_lv 64 signal 1 } 
	{ m_axi_out_r_ARID sc_out sc_lv 1 signal 1 } 
	{ m_axi_out_r_ARLEN sc_out sc_lv 8 signal 1 } 
	{ m_axi_out_r_ARSIZE sc_out sc_lv 3 signal 1 } 
	{ m_axi_out_r_ARBURST sc_out sc_lv 2 signal 1 } 
	{ m_axi_out_r_ARLOCK sc_out sc_lv 2 signal 1 } 
	{ m_axi_out_r_ARCACHE sc_out sc_lv 4 signal 1 } 
	{ m_axi_out_r_ARPROT sc_out sc_lv 3 signal 1 } 
	{ m_axi_out_r_ARQOS sc_out sc_lv 4 signal 1 } 
	{ m_axi_out_r_ARREGION sc_out sc_lv 4 signal 1 } 
	{ m_axi_out_r_ARUSER sc_out sc_lv 1 signal 1 } 
	{ m_axi_out_r_RVALID sc_in sc_logic 1 signal 1 } 
	{ m_axi_out_r_RREADY sc_out sc_logic 1 signal 1 } 
	{ m_axi_out_r_RDATA sc_in sc_lv 64 signal 1 } 
	{ m_axi_out_r_RLAST sc_in sc_logic 1 signal 1 } 
	{ m_axi_out_r_RID sc_in sc_lv 1 signal 1 } 
	{ m_axi_out_r_RUSER sc_in sc_lv 1 signal 1 } 
	{ m_axi_out_r_RRESP sc_in sc_lv 2 signal 1 } 
	{ m_axi_out_r_BVALID sc_in sc_logic 1 signal 1 } 
	{ m_axi_out_r_BREADY sc_out sc_logic 1 signal 1 } 
	{ m_axi_out_r_BRESP sc_in sc_lv 2 signal 1 } 
	{ m_axi_out_r_BID sc_in sc_lv 1 signal 1 } 
	{ m_axi_out_r_BUSER sc_in sc_lv 1 signal 1 } 
	{ s_axi_control_AWVALID sc_in sc_logic 1 signal -1 } 
	{ s_axi_control_AWREADY sc_out sc_logic 1 signal -1 } 
	{ s_axi_control_AWADDR sc_in sc_lv 7 signal -1 } 
	{ s_axi_control_WVALID sc_in sc_logic 1 signal -1 } 
	{ s_axi_control_WREADY sc_out sc_logic 1 signal -1 } 
	{ s_axi_control_WDATA sc_in sc_lv 32 signal -1 } 
	{ s_axi_control_WSTRB sc_in sc_lv 4 signal -1 } 
	{ s_axi_control_ARVALID sc_in sc_logic 1 signal -1 } 
	{ s_axi_control_ARREADY sc_out sc_logic 1 signal -1 } 
	{ s_axi_control_ARADDR sc_in sc_lv 7 signal -1 } 
	{ s_axi_control_RVALID sc_out sc_logic 1 signal -1 } 
	{ s_axi_control_RREADY sc_in sc_logic 1 signal -1 } 
	{ s_axi_control_RDATA sc_out sc_lv 32 signal -1 } 
	{ s_axi_control_RRESP sc_out sc_lv 2 signal -1 } 
	{ s_axi_control_BVALID sc_out sc_logic 1 signal -1 } 
	{ s_axi_control_BREADY sc_in sc_logic 1 signal -1 } 
	{ s_axi_control_BRESP sc_out sc_lv 2 signal -1 } 
}
set NewPortList {[ 
	{ "name": "s_axi_control_AWADDR", "direction": "in", "datatype": "sc_lv", "bitwidth":7, "type": "signal", "bundle":{"name": "control", "role": "AWADDR" },"address":[{"name":"voxel","role":"data","value":"16"},{"name":"slot_base","role":"data","value":"28"},{"name":"phase","role":"data","value":"40"},{"name":"slot_start","role":"data","value":"48"},{"name":"n_slots","role":"data","value":"56"},{"name":"axis_off_q8","role":"data","value":"64"},{"name":"mirror_u","role":"data","value":"72"}] },
	{ "name": "s_axi_control_AWVALID", "direction": "in", "datatype": "sc_logic", "bitwidth":1, "type": "signal", "bundle":{"name": "control", "role": "AWVALID" } },
	{ "name": "s_axi_control_AWREADY", "direction": "out", "datatype": "sc_logic", "bitwidth":1, "type": "signal", "bundle":{"name": "control", "role": "AWREADY" } },
	{ "name": "s_axi_control_WVALID", "direction": "in", "datatype": "sc_logic", "bitwidth":1, "type": "signal", "bundle":{"name": "control", "role": "WVALID" } },
	{ "name": "s_axi_control_WREADY", "direction": "out", "datatype": "sc_logic", "bitwidth":1, "type": "signal", "bundle":{"name": "control", "role": "WREADY" } },
	{ "name": "s_axi_control_WDATA", "direction": "in", "datatype": "sc_lv", "bitwidth":32, "type": "signal", "bundle":{"name": "control", "role": "WDATA" } },
	{ "name": "s_axi_control_WSTRB", "direction": "in", "datatype": "sc_lv", "bitwidth":4, "type": "signal", "bundle":{"name": "control", "role": "WSTRB" } },
	{ "name": "s_axi_control_ARADDR", "direction": "in", "datatype": "sc_lv", "bitwidth":7, "type": "signal", "bundle":{"name": "control", "role": "ARADDR" },"address":[] },
	{ "name": "s_axi_control_ARVALID", "direction": "in", "datatype": "sc_logic", "bitwidth":1, "type": "signal", "bundle":{"name": "control", "role": "ARVALID" } },
	{ "name": "s_axi_control_ARREADY", "direction": "out", "datatype": "sc_logic", "bitwidth":1, "type": "signal", "bundle":{"name": "control", "role": "ARREADY" } },
	{ "name": "s_axi_control_RVALID", "direction": "out", "datatype": "sc_logic", "bitwidth":1, "type": "signal", "bundle":{"name": "control", "role": "RVALID" } },
	{ "name": "s_axi_control_RREADY", "direction": "in", "datatype": "sc_logic", "bitwidth":1, "type": "signal", "bundle":{"name": "control", "role": "RREADY" } },
	{ "name": "s_axi_control_RDATA", "direction": "out", "datatype": "sc_lv", "bitwidth":32, "type": "signal", "bundle":{"name": "control", "role": "RDATA" } },
	{ "name": "s_axi_control_RRESP", "direction": "out", "datatype": "sc_lv", "bitwidth":2, "type": "signal", "bundle":{"name": "control", "role": "RRESP" } },
	{ "name": "s_axi_control_BVALID", "direction": "out", "datatype": "sc_logic", "bitwidth":1, "type": "signal", "bundle":{"name": "control", "role": "BVALID" } },
	{ "name": "s_axi_control_BREADY", "direction": "in", "datatype": "sc_logic", "bitwidth":1, "type": "signal", "bundle":{"name": "control", "role": "BREADY" } },
	{ "name": "s_axi_control_BRESP", "direction": "out", "datatype": "sc_lv", "bitwidth":2, "type": "signal", "bundle":{"name": "control", "role": "BRESP" } }, 
 	{ "name": "ap_clk", "direction": "in", "datatype": "sc_logic", "bitwidth":1, "type": "clock", "bundle":{"name": "ap_clk", "role": "default" }} , 
 	{ "name": "ap_rst_n", "direction": "in", "datatype": "sc_logic", "bitwidth":1, "type": "reset", "bundle":{"name": "ap_rst_n", "role": "default" }} , 
 	{ "name": "ap_start", "direction": "in", "datatype": "sc_logic", "bitwidth":1, "type": "start", "bundle":{"name": "ap_start", "role": "default" }} , 
 	{ "name": "ap_done", "direction": "out", "datatype": "sc_logic", "bitwidth":1, "type": "predone", "bundle":{"name": "ap_done", "role": "default" }} , 
 	{ "name": "ap_idle", "direction": "out", "datatype": "sc_logic", "bitwidth":1, "type": "done", "bundle":{"name": "ap_idle", "role": "default" }} , 
 	{ "name": "ap_ready", "direction": "out", "datatype": "sc_logic", "bitwidth":1, "type": "ready", "bundle":{"name": "ap_ready", "role": "default" }} , 
 	{ "name": "m_axi_vox_AWVALID", "direction": "out", "datatype": "sc_logic", "bitwidth":1, "type": "signal", "bundle":{"name": "vox", "role": "AWVALID" }} , 
 	{ "name": "m_axi_vox_AWREADY", "direction": "in", "datatype": "sc_logic", "bitwidth":1, "type": "signal", "bundle":{"name": "vox", "role": "AWREADY" }} , 
 	{ "name": "m_axi_vox_AWADDR", "direction": "out", "datatype": "sc_lv", "bitwidth":64, "type": "signal", "bundle":{"name": "vox", "role": "AWADDR" }} , 
 	{ "name": "m_axi_vox_AWID", "direction": "out", "datatype": "sc_lv", "bitwidth":1, "type": "signal", "bundle":{"name": "vox", "role": "AWID" }} , 
 	{ "name": "m_axi_vox_AWLEN", "direction": "out", "datatype": "sc_lv", "bitwidth":8, "type": "signal", "bundle":{"name": "vox", "role": "AWLEN" }} , 
 	{ "name": "m_axi_vox_AWSIZE", "direction": "out", "datatype": "sc_lv", "bitwidth":3, "type": "signal", "bundle":{"name": "vox", "role": "AWSIZE" }} , 
 	{ "name": "m_axi_vox_AWBURST", "direction": "out", "datatype": "sc_lv", "bitwidth":2, "type": "signal", "bundle":{"name": "vox", "role": "AWBURST" }} , 
 	{ "name": "m_axi_vox_AWLOCK", "direction": "out", "datatype": "sc_lv", "bitwidth":2, "type": "signal", "bundle":{"name": "vox", "role": "AWLOCK" }} , 
 	{ "name": "m_axi_vox_AWCACHE", "direction": "out", "datatype": "sc_lv", "bitwidth":4, "type": "signal", "bundle":{"name": "vox", "role": "AWCACHE" }} , 
 	{ "name": "m_axi_vox_AWPROT", "direction": "out", "datatype": "sc_lv", "bitwidth":3, "type": "signal", "bundle":{"name": "vox", "role": "AWPROT" }} , 
 	{ "name": "m_axi_vox_AWQOS", "direction": "out", "datatype": "sc_lv", "bitwidth":4, "type": "signal", "bundle":{"name": "vox", "role": "AWQOS" }} , 
 	{ "name": "m_axi_vox_AWREGION", "direction": "out", "datatype": "sc_lv", "bitwidth":4, "type": "signal", "bundle":{"name": "vox", "role": "AWREGION" }} , 
 	{ "name": "m_axi_vox_AWUSER", "direction": "out", "datatype": "sc_lv", "bitwidth":1, "type": "signal", "bundle":{"name": "vox", "role": "AWUSER" }} , 
 	{ "name": "m_axi_vox_WVALID", "direction": "out", "datatype": "sc_logic", "bitwidth":1, "type": "signal", "bundle":{"name": "vox", "role": "WVALID" }} , 
 	{ "name": "m_axi_vox_WREADY", "direction": "in", "datatype": "sc_logic", "bitwidth":1, "type": "signal", "bundle":{"name": "vox", "role": "WREADY" }} , 
 	{ "name": "m_axi_vox_WDATA", "direction": "out", "datatype": "sc_lv", "bitwidth":64, "type": "signal", "bundle":{"name": "vox", "role": "WDATA" }} , 
 	{ "name": "m_axi_vox_WSTRB", "direction": "out", "datatype": "sc_lv", "bitwidth":8, "type": "signal", "bundle":{"name": "vox", "role": "WSTRB" }} , 
 	{ "name": "m_axi_vox_WLAST", "direction": "out", "datatype": "sc_logic", "bitwidth":1, "type": "signal", "bundle":{"name": "vox", "role": "WLAST" }} , 
 	{ "name": "m_axi_vox_WID", "direction": "out", "datatype": "sc_lv", "bitwidth":1, "type": "signal", "bundle":{"name": "vox", "role": "WID" }} , 
 	{ "name": "m_axi_vox_WUSER", "direction": "out", "datatype": "sc_lv", "bitwidth":1, "type": "signal", "bundle":{"name": "vox", "role": "WUSER" }} , 
 	{ "name": "m_axi_vox_ARVALID", "direction": "out", "datatype": "sc_logic", "bitwidth":1, "type": "signal", "bundle":{"name": "vox", "role": "ARVALID" }} , 
 	{ "name": "m_axi_vox_ARREADY", "direction": "in", "datatype": "sc_logic", "bitwidth":1, "type": "signal", "bundle":{"name": "vox", "role": "ARREADY" }} , 
 	{ "name": "m_axi_vox_ARADDR", "direction": "out", "datatype": "sc_lv", "bitwidth":64, "type": "signal", "bundle":{"name": "vox", "role": "ARADDR" }} , 
 	{ "name": "m_axi_vox_ARID", "direction": "out", "datatype": "sc_lv", "bitwidth":1, "type": "signal", "bundle":{"name": "vox", "role": "ARID" }} , 
 	{ "name": "m_axi_vox_ARLEN", "direction": "out", "datatype": "sc_lv", "bitwidth":8, "type": "signal", "bundle":{"name": "vox", "role": "ARLEN" }} , 
 	{ "name": "m_axi_vox_ARSIZE", "direction": "out", "datatype": "sc_lv", "bitwidth":3, "type": "signal", "bundle":{"name": "vox", "role": "ARSIZE" }} , 
 	{ "name": "m_axi_vox_ARBURST", "direction": "out", "datatype": "sc_lv", "bitwidth":2, "type": "signal", "bundle":{"name": "vox", "role": "ARBURST" }} , 
 	{ "name": "m_axi_vox_ARLOCK", "direction": "out", "datatype": "sc_lv", "bitwidth":2, "type": "signal", "bundle":{"name": "vox", "role": "ARLOCK" }} , 
 	{ "name": "m_axi_vox_ARCACHE", "direction": "out", "datatype": "sc_lv", "bitwidth":4, "type": "signal", "bundle":{"name": "vox", "role": "ARCACHE" }} , 
 	{ "name": "m_axi_vox_ARPROT", "direction": "out", "datatype": "sc_lv", "bitwidth":3, "type": "signal", "bundle":{"name": "vox", "role": "ARPROT" }} , 
 	{ "name": "m_axi_vox_ARQOS", "direction": "out", "datatype": "sc_lv", "bitwidth":4, "type": "signal", "bundle":{"name": "vox", "role": "ARQOS" }} , 
 	{ "name": "m_axi_vox_ARREGION", "direction": "out", "datatype": "sc_lv", "bitwidth":4, "type": "signal", "bundle":{"name": "vox", "role": "ARREGION" }} , 
 	{ "name": "m_axi_vox_ARUSER", "direction": "out", "datatype": "sc_lv", "bitwidth":1, "type": "signal", "bundle":{"name": "vox", "role": "ARUSER" }} , 
 	{ "name": "m_axi_vox_RVALID", "direction": "in", "datatype": "sc_logic", "bitwidth":1, "type": "signal", "bundle":{"name": "vox", "role": "RVALID" }} , 
 	{ "name": "m_axi_vox_RREADY", "direction": "out", "datatype": "sc_logic", "bitwidth":1, "type": "signal", "bundle":{"name": "vox", "role": "RREADY" }} , 
 	{ "name": "m_axi_vox_RDATA", "direction": "in", "datatype": "sc_lv", "bitwidth":64, "type": "signal", "bundle":{"name": "vox", "role": "RDATA" }} , 
 	{ "name": "m_axi_vox_RLAST", "direction": "in", "datatype": "sc_logic", "bitwidth":1, "type": "signal", "bundle":{"name": "vox", "role": "RLAST" }} , 
 	{ "name": "m_axi_vox_RID", "direction": "in", "datatype": "sc_lv", "bitwidth":1, "type": "signal", "bundle":{"name": "vox", "role": "RID" }} , 
 	{ "name": "m_axi_vox_RUSER", "direction": "in", "datatype": "sc_lv", "bitwidth":1, "type": "signal", "bundle":{"name": "vox", "role": "RUSER" }} , 
 	{ "name": "m_axi_vox_RRESP", "direction": "in", "datatype": "sc_lv", "bitwidth":2, "type": "signal", "bundle":{"name": "vox", "role": "RRESP" }} , 
 	{ "name": "m_axi_vox_BVALID", "direction": "in", "datatype": "sc_logic", "bitwidth":1, "type": "signal", "bundle":{"name": "vox", "role": "BVALID" }} , 
 	{ "name": "m_axi_vox_BREADY", "direction": "out", "datatype": "sc_logic", "bitwidth":1, "type": "signal", "bundle":{"name": "vox", "role": "BREADY" }} , 
 	{ "name": "m_axi_vox_BRESP", "direction": "in", "datatype": "sc_lv", "bitwidth":2, "type": "signal", "bundle":{"name": "vox", "role": "BRESP" }} , 
 	{ "name": "m_axi_vox_BID", "direction": "in", "datatype": "sc_lv", "bitwidth":1, "type": "signal", "bundle":{"name": "vox", "role": "BID" }} , 
 	{ "name": "m_axi_vox_BUSER", "direction": "in", "datatype": "sc_lv", "bitwidth":1, "type": "signal", "bundle":{"name": "vox", "role": "BUSER" }} , 
 	{ "name": "m_axi_out_r_AWVALID", "direction": "out", "datatype": "sc_logic", "bitwidth":1, "type": "signal", "bundle":{"name": "out_r", "role": "AWVALID" }} , 
 	{ "name": "m_axi_out_r_AWREADY", "direction": "in", "datatype": "sc_logic", "bitwidth":1, "type": "signal", "bundle":{"name": "out_r", "role": "AWREADY" }} , 
 	{ "name": "m_axi_out_r_AWADDR", "direction": "out", "datatype": "sc_lv", "bitwidth":64, "type": "signal", "bundle":{"name": "out_r", "role": "AWADDR" }} , 
 	{ "name": "m_axi_out_r_AWID", "direction": "out", "datatype": "sc_lv", "bitwidth":1, "type": "signal", "bundle":{"name": "out_r", "role": "AWID" }} , 
 	{ "name": "m_axi_out_r_AWLEN", "direction": "out", "datatype": "sc_lv", "bitwidth":8, "type": "signal", "bundle":{"name": "out_r", "role": "AWLEN" }} , 
 	{ "name": "m_axi_out_r_AWSIZE", "direction": "out", "datatype": "sc_lv", "bitwidth":3, "type": "signal", "bundle":{"name": "out_r", "role": "AWSIZE" }} , 
 	{ "name": "m_axi_out_r_AWBURST", "direction": "out", "datatype": "sc_lv", "bitwidth":2, "type": "signal", "bundle":{"name": "out_r", "role": "AWBURST" }} , 
 	{ "name": "m_axi_out_r_AWLOCK", "direction": "out", "datatype": "sc_lv", "bitwidth":2, "type": "signal", "bundle":{"name": "out_r", "role": "AWLOCK" }} , 
 	{ "name": "m_axi_out_r_AWCACHE", "direction": "out", "datatype": "sc_lv", "bitwidth":4, "type": "signal", "bundle":{"name": "out_r", "role": "AWCACHE" }} , 
 	{ "name": "m_axi_out_r_AWPROT", "direction": "out", "datatype": "sc_lv", "bitwidth":3, "type": "signal", "bundle":{"name": "out_r", "role": "AWPROT" }} , 
 	{ "name": "m_axi_out_r_AWQOS", "direction": "out", "datatype": "sc_lv", "bitwidth":4, "type": "signal", "bundle":{"name": "out_r", "role": "AWQOS" }} , 
 	{ "name": "m_axi_out_r_AWREGION", "direction": "out", "datatype": "sc_lv", "bitwidth":4, "type": "signal", "bundle":{"name": "out_r", "role": "AWREGION" }} , 
 	{ "name": "m_axi_out_r_AWUSER", "direction": "out", "datatype": "sc_lv", "bitwidth":1, "type": "signal", "bundle":{"name": "out_r", "role": "AWUSER" }} , 
 	{ "name": "m_axi_out_r_WVALID", "direction": "out", "datatype": "sc_logic", "bitwidth":1, "type": "signal", "bundle":{"name": "out_r", "role": "WVALID" }} , 
 	{ "name": "m_axi_out_r_WREADY", "direction": "in", "datatype": "sc_logic", "bitwidth":1, "type": "signal", "bundle":{"name": "out_r", "role": "WREADY" }} , 
 	{ "name": "m_axi_out_r_WDATA", "direction": "out", "datatype": "sc_lv", "bitwidth":64, "type": "signal", "bundle":{"name": "out_r", "role": "WDATA" }} , 
 	{ "name": "m_axi_out_r_WSTRB", "direction": "out", "datatype": "sc_lv", "bitwidth":8, "type": "signal", "bundle":{"name": "out_r", "role": "WSTRB" }} , 
 	{ "name": "m_axi_out_r_WLAST", "direction": "out", "datatype": "sc_logic", "bitwidth":1, "type": "signal", "bundle":{"name": "out_r", "role": "WLAST" }} , 
 	{ "name": "m_axi_out_r_WID", "direction": "out", "datatype": "sc_lv", "bitwidth":1, "type": "signal", "bundle":{"name": "out_r", "role": "WID" }} , 
 	{ "name": "m_axi_out_r_WUSER", "direction": "out", "datatype": "sc_lv", "bitwidth":1, "type": "signal", "bundle":{"name": "out_r", "role": "WUSER" }} , 
 	{ "name": "m_axi_out_r_ARVALID", "direction": "out", "datatype": "sc_logic", "bitwidth":1, "type": "signal", "bundle":{"name": "out_r", "role": "ARVALID" }} , 
 	{ "name": "m_axi_out_r_ARREADY", "direction": "in", "datatype": "sc_logic", "bitwidth":1, "type": "signal", "bundle":{"name": "out_r", "role": "ARREADY" }} , 
 	{ "name": "m_axi_out_r_ARADDR", "direction": "out", "datatype": "sc_lv", "bitwidth":64, "type": "signal", "bundle":{"name": "out_r", "role": "ARADDR" }} , 
 	{ "name": "m_axi_out_r_ARID", "direction": "out", "datatype": "sc_lv", "bitwidth":1, "type": "signal", "bundle":{"name": "out_r", "role": "ARID" }} , 
 	{ "name": "m_axi_out_r_ARLEN", "direction": "out", "datatype": "sc_lv", "bitwidth":8, "type": "signal", "bundle":{"name": "out_r", "role": "ARLEN" }} , 
 	{ "name": "m_axi_out_r_ARSIZE", "direction": "out", "datatype": "sc_lv", "bitwidth":3, "type": "signal", "bundle":{"name": "out_r", "role": "ARSIZE" }} , 
 	{ "name": "m_axi_out_r_ARBURST", "direction": "out", "datatype": "sc_lv", "bitwidth":2, "type": "signal", "bundle":{"name": "out_r", "role": "ARBURST" }} , 
 	{ "name": "m_axi_out_r_ARLOCK", "direction": "out", "datatype": "sc_lv", "bitwidth":2, "type": "signal", "bundle":{"name": "out_r", "role": "ARLOCK" }} , 
 	{ "name": "m_axi_out_r_ARCACHE", "direction": "out", "datatype": "sc_lv", "bitwidth":4, "type": "signal", "bundle":{"name": "out_r", "role": "ARCACHE" }} , 
 	{ "name": "m_axi_out_r_ARPROT", "direction": "out", "datatype": "sc_lv", "bitwidth":3, "type": "signal", "bundle":{"name": "out_r", "role": "ARPROT" }} , 
 	{ "name": "m_axi_out_r_ARQOS", "direction": "out", "datatype": "sc_lv", "bitwidth":4, "type": "signal", "bundle":{"name": "out_r", "role": "ARQOS" }} , 
 	{ "name": "m_axi_out_r_ARREGION", "direction": "out", "datatype": "sc_lv", "bitwidth":4, "type": "signal", "bundle":{"name": "out_r", "role": "ARREGION" }} , 
 	{ "name": "m_axi_out_r_ARUSER", "direction": "out", "datatype": "sc_lv", "bitwidth":1, "type": "signal", "bundle":{"name": "out_r", "role": "ARUSER" }} , 
 	{ "name": "m_axi_out_r_RVALID", "direction": "in", "datatype": "sc_logic", "bitwidth":1, "type": "signal", "bundle":{"name": "out_r", "role": "RVALID" }} , 
 	{ "name": "m_axi_out_r_RREADY", "direction": "out", "datatype": "sc_logic", "bitwidth":1, "type": "signal", "bundle":{"name": "out_r", "role": "RREADY" }} , 
 	{ "name": "m_axi_out_r_RDATA", "direction": "in", "datatype": "sc_lv", "bitwidth":64, "type": "signal", "bundle":{"name": "out_r", "role": "RDATA" }} , 
 	{ "name": "m_axi_out_r_RLAST", "direction": "in", "datatype": "sc_logic", "bitwidth":1, "type": "signal", "bundle":{"name": "out_r", "role": "RLAST" }} , 
 	{ "name": "m_axi_out_r_RID", "direction": "in", "datatype": "sc_lv", "bitwidth":1, "type": "signal", "bundle":{"name": "out_r", "role": "RID" }} , 
 	{ "name": "m_axi_out_r_RUSER", "direction": "in", "datatype": "sc_lv", "bitwidth":1, "type": "signal", "bundle":{"name": "out_r", "role": "RUSER" }} , 
 	{ "name": "m_axi_out_r_RRESP", "direction": "in", "datatype": "sc_lv", "bitwidth":2, "type": "signal", "bundle":{"name": "out_r", "role": "RRESP" }} , 
 	{ "name": "m_axi_out_r_BVALID", "direction": "in", "datatype": "sc_logic", "bitwidth":1, "type": "signal", "bundle":{"name": "out_r", "role": "BVALID" }} , 
 	{ "name": "m_axi_out_r_BREADY", "direction": "out", "datatype": "sc_logic", "bitwidth":1, "type": "signal", "bundle":{"name": "out_r", "role": "BREADY" }} , 
 	{ "name": "m_axi_out_r_BRESP", "direction": "in", "datatype": "sc_lv", "bitwidth":2, "type": "signal", "bundle":{"name": "out_r", "role": "BRESP" }} , 
 	{ "name": "m_axi_out_r_BID", "direction": "in", "datatype": "sc_lv", "bitwidth":1, "type": "signal", "bundle":{"name": "out_r", "role": "BID" }} , 
 	{ "name": "m_axi_out_r_BUSER", "direction": "in", "datatype": "sc_lv", "bitwidth":1, "type": "signal", "bundle":{"name": "out_r", "role": "BUSER" }}  ]}

set RtlHierarchyInfo {[
	{"ID" : "0", "Level" : "0", "Path" : "`AUTOTB_DUT_INST", "Parent" : "", "Child" : ["1", "11", "12", "13"],
		"CDFG" : "pov_eta_wr",
		"Protocol" : "ap_ctrl_hs",
		"ControlExist" : "1", "ap_start" : "1", "ap_ready" : "1", "ap_done" : "1", "ap_continue" : "0", "ap_idle" : "1", "real_start" : "0",
		"Pipeline" : "None", "UnalignedPipeline" : "0", "RewindPipeline" : "0", "ProcessNetwork" : "0",
		"II" : "0",
		"VariableLatency" : "1", "ExactLatency" : "-1", "EstimateLatencyMin" : "1565640", "EstimateLatencyMax" : "6251976",
		"Combinational" : "0",
		"Datapath" : "0",
		"ClockEnable" : "0",
		"HasSubDataflow" : "0",
		"InDataflowNetwork" : "0",
		"HasNonBlockingOperation" : "0",
		"IsBlackBox" : "0",
		"Port" : [
			{"Name" : "vox", "Type" : "MAXI", "Direction" : "I",
				"SubConnect" : [
					{"ID" : "1", "SubInstance" : "grp_pov_eta_wr_Pipeline_SLICES_COLUMNS_COPY_COLUMN_fu_175", "Port" : "vox", "Inst_start_state" : "5", "Inst_end_state" : "6"}]},
			{"Name" : "out_r", "Type" : "MAXI", "Direction" : "O",
				"BlockSignal" : [
					{"Name" : "out_r_blk_n_AW", "Type" : "RtlSignal"},
					{"Name" : "out_r_blk_n_B", "Type" : "RtlSignal"}],
				"SubConnect" : [
					{"ID" : "1", "SubInstance" : "grp_pov_eta_wr_Pipeline_SLICES_COLUMNS_COPY_COLUMN_fu_175", "Port" : "out_r", "Inst_start_state" : "5", "Inst_end_state" : "6"}]},
			{"Name" : "voxel", "Type" : "None", "Direction" : "I"},
			{"Name" : "slot_base", "Type" : "None", "Direction" : "I"},
			{"Name" : "phase", "Type" : "None", "Direction" : "I"},
			{"Name" : "slot_start", "Type" : "None", "Direction" : "I"},
			{"Name" : "n_slots", "Type" : "None", "Direction" : "I"},
			{"Name" : "axis_off_q8", "Type" : "None", "Direction" : "I"},
			{"Name" : "mirror_u", "Type" : "None", "Direction" : "I"},
			{"Name" : "PV2_COS8", "Type" : "Memory", "Direction" : "I",
				"SubConnect" : [
					{"ID" : "1", "SubInstance" : "grp_pov_eta_wr_Pipeline_SLICES_COLUMNS_COPY_COLUMN_fu_175", "Port" : "PV2_COS8", "Inst_start_state" : "5", "Inst_end_state" : "6"}]},
			{"Name" : "PV2_SIN8", "Type" : "Memory", "Direction" : "I",
				"SubConnect" : [
					{"ID" : "1", "SubInstance" : "grp_pov_eta_wr_Pipeline_SLICES_COLUMNS_COPY_COLUMN_fu_175", "Port" : "PV2_SIN8", "Inst_start_state" : "5", "Inst_end_state" : "6"}]}]},
	{"ID" : "1", "Level" : "1", "Path" : "`AUTOTB_DUT_INST.grp_pov_eta_wr_Pipeline_SLICES_COLUMNS_COPY_COLUMN_fu_175", "Parent" : "0", "Child" : ["2", "3", "4", "5", "6", "7", "8", "9", "10"],
		"CDFG" : "pov_eta_wr_Pipeline_SLICES_COLUMNS_COPY_COLUMN",
		"Protocol" : "ap_ctrl_hs",
		"ControlExist" : "1", "ap_start" : "1", "ap_ready" : "1", "ap_done" : "1", "ap_continue" : "0", "ap_idle" : "1", "real_start" : "0",
		"Pipeline" : "None", "UnalignedPipeline" : "0", "RewindPipeline" : "0", "ProcessNetwork" : "0",
		"II" : "0",
		"VariableLatency" : "1", "ExactLatency" : "-1", "EstimateLatencyMin" : "1565630", "EstimateLatencyMax" : "6251966",
		"Combinational" : "0",
		"Datapath" : "0",
		"ClockEnable" : "0",
		"HasSubDataflow" : "0",
		"InDataflowNetwork" : "0",
		"HasNonBlockingOperation" : "0",
		"IsBlackBox" : "0",
		"Port" : [
			{"Name" : "out_r", "Type" : "MAXI", "Direction" : "O",
				"BlockSignal" : [
					{"Name" : "out_r_blk_n_W", "Type" : "RtlSignal"}]},
			{"Name" : "vox", "Type" : "MAXI", "Direction" : "I",
				"BlockSignal" : [
					{"Name" : "vox_blk_n_R", "Type" : "RtlSignal"},
					{"Name" : "vox_blk_n_AR", "Type" : "RtlSignal"}]},
			{"Name" : "mul_ln14", "Type" : "None", "Direction" : "I"},
			{"Name" : "sext_ln46", "Type" : "None", "Direction" : "I"},
			{"Name" : "phase", "Type" : "None", "Direction" : "I"},
			{"Name" : "zext_ln18", "Type" : "None", "Direction" : "I"},
			{"Name" : "axis_off_q8", "Type" : "None", "Direction" : "I"},
			{"Name" : "voxel", "Type" : "None", "Direction" : "I"},
			{"Name" : "mirror_u", "Type" : "None", "Direction" : "I"},
			{"Name" : "PV2_COS8", "Type" : "Memory", "Direction" : "I"},
			{"Name" : "PV2_SIN8", "Type" : "Memory", "Direction" : "I"}],
		"Loop" : [
			{"Name" : "SLICES_COLUMNS_COPY_COLUMN", "PipelineType" : "UPC",
				"LoopDec" : {"FSMBitwidth" : "1", "FirstState" : "ap_ST_fsm_pp0_stage0", "FirstStateIter" : "ap_enable_reg_pp0_iter0", "FirstStateBlock" : "ap_block_pp0_stage0_subdone", "LastState" : "ap_ST_fsm_pp0_stage0", "LastStateIter" : "ap_enable_reg_pp0_iter62", "LastStateBlock" : "ap_block_pp0_stage0_subdone", "QuitState" : "ap_ST_fsm_pp0_stage0", "QuitStateIter" : "ap_enable_reg_pp0_iter62", "QuitStateBlock" : "ap_block_pp0_stage0_subdone", "OneDepthLoop" : "0", "has_ap_ctrl" : "1", "has_continue" : "0"}}]},
	{"ID" : "2", "Level" : "2", "Path" : "`AUTOTB_DUT_INST.grp_pov_eta_wr_Pipeline_SLICES_COLUMNS_COPY_COLUMN_fu_175.PV2_COS8_U", "Parent" : "1"},
	{"ID" : "3", "Level" : "2", "Path" : "`AUTOTB_DUT_INST.grp_pov_eta_wr_Pipeline_SLICES_COLUMNS_COPY_COLUMN_fu_175.PV2_SIN8_U", "Parent" : "1"},
	{"ID" : "4", "Level" : "2", "Path" : "`AUTOTB_DUT_INST.grp_pov_eta_wr_Pipeline_SLICES_COLUMNS_COPY_COLUMN_fu_175.mul_10s_32s_32_3_1_U1", "Parent" : "1"},
	{"ID" : "5", "Level" : "2", "Path" : "`AUTOTB_DUT_INST.grp_pov_eta_wr_Pipeline_SLICES_COLUMNS_COPY_COLUMN_fu_175.mul_10s_32s_32_3_1_U2", "Parent" : "1"},
	{"ID" : "6", "Level" : "2", "Path" : "`AUTOTB_DUT_INST.grp_pov_eta_wr_Pipeline_SLICES_COLUMNS_COPY_COLUMN_fu_175.srem_32ns_11ns_32_36_1_U3", "Parent" : "1"},
	{"ID" : "7", "Level" : "2", "Path" : "`AUTOTB_DUT_INST.grp_pov_eta_wr_Pipeline_SLICES_COLUMNS_COPY_COLUMN_fu_175.mul_16ns_10ns_25_1_1_U4", "Parent" : "1"},
	{"ID" : "8", "Level" : "2", "Path" : "`AUTOTB_DUT_INST.grp_pov_eta_wr_Pipeline_SLICES_COLUMNS_COPY_COLUMN_fu_175.mac_muladd_10s_8s_25s_25_4_1_U5", "Parent" : "1"},
	{"ID" : "9", "Level" : "2", "Path" : "`AUTOTB_DUT_INST.grp_pov_eta_wr_Pipeline_SLICES_COLUMNS_COPY_COLUMN_fu_175.mac_muladd_10s_8s_25s_25_4_1_U6", "Parent" : "1"},
	{"ID" : "10", "Level" : "2", "Path" : "`AUTOTB_DUT_INST.grp_pov_eta_wr_Pipeline_SLICES_COLUMNS_COPY_COLUMN_fu_175.flow_control_loop_pipe_sequential_init_U", "Parent" : "1"},
	{"ID" : "11", "Level" : "1", "Path" : "`AUTOTB_DUT_INST.control_s_axi_U", "Parent" : "0"},
	{"ID" : "12", "Level" : "1", "Path" : "`AUTOTB_DUT_INST.out_r_m_axi_U", "Parent" : "0"},
	{"ID" : "13", "Level" : "1", "Path" : "`AUTOTB_DUT_INST.vox_m_axi_U", "Parent" : "0"}]}


set ArgLastReadFirstWriteLatency {
	pov_eta_wr {
		vox {Type I LastRead 60 FirstWrite -1}
		out_r {Type O LastRead 6 FirstWrite 62}
		voxel {Type I LastRead 0 FirstWrite -1}
		slot_base {Type I LastRead 0 FirstWrite -1}
		phase {Type I LastRead 0 FirstWrite -1}
		slot_start {Type I LastRead 0 FirstWrite -1}
		n_slots {Type I LastRead 0 FirstWrite -1}
		axis_off_q8 {Type I LastRead 0 FirstWrite -1}
		mirror_u {Type I LastRead 0 FirstWrite -1}
		PV2_COS8 {Type I LastRead -1 FirstWrite -1}
		PV2_SIN8 {Type I LastRead -1 FirstWrite -1}}
	pov_eta_wr_Pipeline_SLICES_COLUMNS_COPY_COLUMN {
		out_r {Type O LastRead -1 FirstWrite 62}
		vox {Type I LastRead 60 FirstWrite -1}
		mul_ln14 {Type I LastRead 0 FirstWrite -1}
		sext_ln46 {Type I LastRead 0 FirstWrite -1}
		phase {Type I LastRead 0 FirstWrite -1}
		zext_ln18 {Type I LastRead 0 FirstWrite -1}
		axis_off_q8 {Type I LastRead 0 FirstWrite -1}
		voxel {Type I LastRead 0 FirstWrite -1}
		mirror_u {Type I LastRead 0 FirstWrite -1}
		PV2_COS8 {Type I LastRead -1 FirstWrite -1}
		PV2_SIN8 {Type I LastRead -1 FirstWrite -1}}}

set hasDtUnsupportedChannel 0

set PerformanceInfo {[
	{"Name" : "Latency", "Min" : "1565640", "Max" : "6251976"}
	, {"Name" : "Interval", "Min" : "1565641", "Max" : "6251977"}
]}

set PipelineEnableSignalInfo {[
]}

set Spec2ImplPortList { 
	vox { m_axi {  { m_axi_vox_AWVALID VALID 1 1 }  { m_axi_vox_AWREADY READY 0 1 }  { m_axi_vox_AWADDR ADDR 1 64 }  { m_axi_vox_AWID ID 1 1 }  { m_axi_vox_AWLEN SIZE 1 8 }  { m_axi_vox_AWSIZE BURST 1 3 }  { m_axi_vox_AWBURST LOCK 1 2 }  { m_axi_vox_AWLOCK CACHE 1 2 }  { m_axi_vox_AWCACHE PROT 1 4 }  { m_axi_vox_AWPROT QOS 1 3 }  { m_axi_vox_AWQOS REGION 1 4 }  { m_axi_vox_AWREGION USER 1 4 }  { m_axi_vox_AWUSER DATA 1 1 }  { m_axi_vox_WVALID VALID 1 1 }  { m_axi_vox_WREADY READY 0 1 }  { m_axi_vox_WDATA FIFONUM 1 64 }  { m_axi_vox_WSTRB STRB 1 8 }  { m_axi_vox_WLAST LAST 1 1 }  { m_axi_vox_WID ID 1 1 }  { m_axi_vox_WUSER DATA 1 1 }  { m_axi_vox_ARVALID VALID 1 1 }  { m_axi_vox_ARREADY READY 0 1 }  { m_axi_vox_ARADDR ADDR 1 64 }  { m_axi_vox_ARID ID 1 1 }  { m_axi_vox_ARLEN SIZE 1 8 }  { m_axi_vox_ARSIZE BURST 1 3 }  { m_axi_vox_ARBURST LOCK 1 2 }  { m_axi_vox_ARLOCK CACHE 1 2 }  { m_axi_vox_ARCACHE PROT 1 4 }  { m_axi_vox_ARPROT QOS 1 3 }  { m_axi_vox_ARQOS REGION 1 4 }  { m_axi_vox_ARREGION USER 1 4 }  { m_axi_vox_ARUSER DATA 1 1 }  { m_axi_vox_RVALID VALID 0 1 }  { m_axi_vox_RREADY READY 1 1 }  { m_axi_vox_RDATA FIFONUM 0 64 }  { m_axi_vox_RLAST LAST 0 1 }  { m_axi_vox_RID ID 0 1 }  { m_axi_vox_RUSER DATA 0 1 }  { m_axi_vox_RRESP RESP 0 2 }  { m_axi_vox_BVALID VALID 0 1 }  { m_axi_vox_BREADY READY 1 1 }  { m_axi_vox_BRESP RESP 0 2 }  { m_axi_vox_BID ID 0 1 }  { m_axi_vox_BUSER DATA 0 1 } } }
	out_r { m_axi {  { m_axi_out_r_AWVALID VALID 1 1 }  { m_axi_out_r_AWREADY READY 0 1 }  { m_axi_out_r_AWADDR ADDR 1 64 }  { m_axi_out_r_AWID ID 1 1 }  { m_axi_out_r_AWLEN SIZE 1 8 }  { m_axi_out_r_AWSIZE BURST 1 3 }  { m_axi_out_r_AWBURST LOCK 1 2 }  { m_axi_out_r_AWLOCK CACHE 1 2 }  { m_axi_out_r_AWCACHE PROT 1 4 }  { m_axi_out_r_AWPROT QOS 1 3 }  { m_axi_out_r_AWQOS REGION 1 4 }  { m_axi_out_r_AWREGION USER 1 4 }  { m_axi_out_r_AWUSER DATA 1 1 }  { m_axi_out_r_WVALID VALID 1 1 }  { m_axi_out_r_WREADY READY 0 1 }  { m_axi_out_r_WDATA FIFONUM 1 64 }  { m_axi_out_r_WSTRB STRB 1 8 }  { m_axi_out_r_WLAST LAST 1 1 }  { m_axi_out_r_WID ID 1 1 }  { m_axi_out_r_WUSER DATA 1 1 }  { m_axi_out_r_ARVALID VALID 1 1 }  { m_axi_out_r_ARREADY READY 0 1 }  { m_axi_out_r_ARADDR ADDR 1 64 }  { m_axi_out_r_ARID ID 1 1 }  { m_axi_out_r_ARLEN SIZE 1 8 }  { m_axi_out_r_ARSIZE BURST 1 3 }  { m_axi_out_r_ARBURST LOCK 1 2 }  { m_axi_out_r_ARLOCK CACHE 1 2 }  { m_axi_out_r_ARCACHE PROT 1 4 }  { m_axi_out_r_ARPROT QOS 1 3 }  { m_axi_out_r_ARQOS REGION 1 4 }  { m_axi_out_r_ARREGION USER 1 4 }  { m_axi_out_r_ARUSER DATA 1 1 }  { m_axi_out_r_RVALID VALID 0 1 }  { m_axi_out_r_RREADY READY 1 1 }  { m_axi_out_r_RDATA FIFONUM 0 64 }  { m_axi_out_r_RLAST LAST 0 1 }  { m_axi_out_r_RID ID 0 1 }  { m_axi_out_r_RUSER DATA 0 1 }  { m_axi_out_r_RRESP RESP 0 2 }  { m_axi_out_r_BVALID VALID 0 1 }  { m_axi_out_r_BREADY READY 1 1 }  { m_axi_out_r_BRESP RESP 0 2 }  { m_axi_out_r_BID ID 0 1 }  { m_axi_out_r_BUSER DATA 0 1 } } }
}

set maxi_interface_dict [dict create]
dict set maxi_interface_dict out_r { CHANNEL_NUM 0 BUNDLE out_r NUM_READ_OUTSTANDING 16 NUM_WRITE_OUTSTANDING 16 MAX_READ_BURST_LENGTH 16 MAX_WRITE_BURST_LENGTH 64 READ_WRITE_MODE WRITE_ONLY}
dict set maxi_interface_dict vox { CHANNEL_NUM 0 BUNDLE vox NUM_READ_OUTSTANDING 16 NUM_WRITE_OUTSTANDING 16 MAX_READ_BURST_LENGTH 64 MAX_WRITE_BURST_LENGTH 16 READ_WRITE_MODE READ_ONLY}

# RTL port scheduling information:
set fifoSchedulingInfoList { 
}

# RTL bus port read request latency information:
set busReadReqLatencyList { 
	{ vox 1 }
	{ out_r 1 }
}

# RTL bus port write response latency information:
set busWriteResLatencyList { 
	{ vox 1 }
	{ out_r 1 }
}

# RTL array port load latency information:
set memoryLoadLatencyList { 
}
