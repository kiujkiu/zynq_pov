// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2026 Advanced Micro Devices, Inc. All Rights Reserved.
// -------------------------------------------------------------------------------

`timescale 1 ps / 1 ps

(* BLOCK_STUB = "true" *)
module vio_dbg (
  clk,
  probe_in0,
  probe_in1,
  probe_in2,
  probe_in3,
  probe_in4,
  probe_in5,
  probe_in6,
  probe_in7,
  probe_out0,
  probe_out1,
  probe_out2,
  probe_out3,
  probe_out4,
  probe_out5,
  probe_out6,
  probe_out7,
  probe_out8,
  probe_out9,
  probe_out10,
  probe_out11,
  probe_out12
);

  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 signal_clock CLK" *)
  (* X_INTERFACE_MODE = "slave signal_clock" *)
  (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME signal_clock, FREQ_HZ 100000000, FREQ_TOLERANCE_HZ 0, PHASE 0.0, CLK_DOMAIN , ASSOCIATED_BUSIF , ASSOCIATED_PORT , ASSOCIATED_RESET , INSERT_VIP 0" *)
  input clk;
  (* X_INTERFACE_IGNORE = "true" *)
  input [31:0]probe_in0;
  (* X_INTERFACE_IGNORE = "true" *)
  input [15:0]probe_in1;
  (* X_INTERFACE_IGNORE = "true" *)
  input [15:0]probe_in2;
  (* X_INTERFACE_IGNORE = "true" *)
  input [23:0]probe_in3;
  (* X_INTERFACE_IGNORE = "true" *)
  input [15:0]probe_in4;
  (* X_INTERFACE_IGNORE = "true" *)
  input [15:0]probe_in5;
  (* X_INTERFACE_IGNORE = "true" *)
  input [8:0]probe_in6;
  (* X_INTERFACE_IGNORE = "true" *)
  input [31:0]probe_in7;
  (* X_INTERFACE_IGNORE = "true" *)
  output [7:0]probe_out0;
  (* X_INTERFACE_IGNORE = "true" *)
  output [15:0]probe_out1;
  (* X_INTERFACE_IGNORE = "true" *)
  output [0:0]probe_out2;
  (* X_INTERFACE_IGNORE = "true" *)
  output [7:0]probe_out3;
  (* X_INTERFACE_IGNORE = "true" *)
  output [0:0]probe_out4;
  (* X_INTERFACE_IGNORE = "true" *)
  output [0:0]probe_out5;
  (* X_INTERFACE_IGNORE = "true" *)
  output [3:0]probe_out6;
  (* X_INTERFACE_IGNORE = "true" *)
  output [0:0]probe_out7;
  (* X_INTERFACE_IGNORE = "true" *)
  output [0:0]probe_out8;
  (* X_INTERFACE_IGNORE = "true" *)
  output [3:0]probe_out9;
  (* X_INTERFACE_IGNORE = "true" *)
  output [3:0]probe_out10;
  (* X_INTERFACE_IGNORE = "true" *)
  output [2:0]probe_out11;
  (* X_INTERFACE_IGNORE = "true" *)
  output [15:0]probe_out12;

  // stub module has no contents

endmodule
