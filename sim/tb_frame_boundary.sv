`timescale 1ns/1ps
module tb_frame_boundary;
  reg clk=0;always #2.5 clk=~clk;
  reg resetn=0,valid=0,ready=1,in_last=0;
  reg [7:0] data=0;
  wire in_ready,out_valid,out_last;
  wire [7:0] out_data;
  wire [1:0] state;
  frame_cutter1 dut(.clk(clk),.resetn(resetn),.s_axis_input_tdata(data),
    .s_axis_input_tvalid(valid),.s_axis_input_tlast(in_last),.s_axis_input_tready(in_ready),
    .m_axis_output_tdata(out_data),.m_axis_output_tvalid(out_valid),
    .m_axis_output_tready(ready),.m_axis_output_tlast(out_last),.STATE(state));
  integer input_index=0,output_index=0,cycles=0,stress=0;
  function [7:0] source_byte(input integer n);source_byte=(n*29+1)&255;endfunction
  always @(posedge clk) if(resetn) begin
    cycles=cycles+1;
    if(valid&&in_ready)input_index=input_index+1;
    if(out_valid&&ready)begin
      if(out_data!==source_byte(output_index))$fatal(1,"boundary data index=%0d",output_index);
      if(out_last!==((output_index%255)==254))$fatal(1,"boundary TLAST index=%0d",output_index);
      output_index=output_index+1;
    end
  end
  always @(negedge clk) if(resetn)begin
    valid=(input_index<510);data=source_byte(input_index);in_last=((input_index%255)==254);
    ready=stress?((cycles%9)!=3 && (cycles%9)!=4):1;
  end
  initial begin
    if($test$plusargs("stress"))stress=1;
    repeat(6)@(negedge clk);resetn=1;
    wait(input_index==510);repeat(12)@(negedge clk);
    if(output_index!=510)$fatal(1,"boundary byte count expected=510 actual=%0d",output_index);
    $display("PASS frame_boundary frames=2 input_bytes=510 output_bytes=510 stress=%0d",stress);$finish;
  end
  initial begin #200000;$fatal(1,"boundary timeout");end
endmodule
