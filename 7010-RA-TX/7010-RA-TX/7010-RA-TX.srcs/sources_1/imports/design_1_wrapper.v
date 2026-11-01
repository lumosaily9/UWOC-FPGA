//Copyright 1986-2020 Xilinx, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2020.2 (win64) Build 3064766 Wed Nov 18 09:12:45 MST 2020
//Date        : Fri Sep 19 15:47:55 2025
//Host        : lumos running 64-bit major release  (build 9200)
//Command     : generate_target design_1_wrapper.bd
//Design      : design_1_wrapper
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

module design_1_wrapper
   (clk_in1_0,
    reset_in_0,
    txd_0);
  input clk_in1_0;
  input reset_in_0;
  output txd_0;

  wire clk_in1_0;
  wire reset_in_0;
  wire txd_0;

  design_1 design_1_i
       (.clk_in1_0(clk_in1_0),
        .reset_in_0(reset_in_0),
        .txd_0(txd_0));
endmodule
