`timescale 1ns/1ps
module tb_frame_cutter;
  reg clk=0;always #2.5 clk=~clk;
  reg resetn=0, valid=0, ready=1;
  reg [7:0] data=0;
  wire in_ready, out_valid, out_last;
  wire [7:0] out_data;
  frame_cutter dut(.clk(clk),.resetn(resetn),.s_axis_input_tdata(data),
    .s_axis_input_tvalid(valid),.s_axis_input_tready(in_ready),
    .m_axis_output_tdata(out_data),.m_axis_output_tvalid(out_valid),
    .m_axis_output_tready(ready),.m_axis_output_tlast(out_last));
  integer input_index=0, output_count=0, frame_count=0, cycle=0;
  integer stress=0;
  initial if($test$plusargs("stress")) stress=1;
  function [7:0] source_byte(input integer index);
    source_byte=((index%255)*29+(index/255)*73+1)&255;
  endfunction
  always @(posedge clk) if(resetn) begin
    cycle=cycle+1;
    if(valid&&in_ready) input_index=input_index+1;
    if(out_valid&&ready) begin
      if(out_data!==source_byte(frame_count*255+output_count))
        $fatal(1,"frame data frame=%0d index=%0d expected=%02x actual=%02x",frame_count,output_count,source_byte(frame_count*255+output_count),out_data);
      if(out_last!==(output_count==238)) $fatal(1,"frame TLAST mismatch index=%0d",output_count);
      if(output_count==238) begin output_count=0;frame_count=frame_count+1;end
      else output_count=output_count+1;
    end
  end
  always @(negedge clk) if(resetn) begin
    valid=(input_index<510);data=source_byte(input_index);
    ready=stress?((cycle%9)!=3 && (cycle%9)!=4):1;
  end
  initial begin
    repeat(6) @(negedge clk);resetn=1;
    wait(input_index==510);repeat(12) @(negedge clk);
    if(frame_count!=2 || output_count!=0) $fatal(1,"frame counts frames=%0d trailing=%0d",frame_count,output_count);
    $display("PASS frame_cutter frames=%0d input_bytes=510 output_bytes=478 stress=%0d",frame_count,stress);$finish;
  end
  initial begin #200000;$fatal(1,"frame cutter timeout inputs=%0d outputs=%0d",input_index,frame_count*239+output_count);end
endmodule
