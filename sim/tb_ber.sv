`timescale 1ns/1ps
module tb_ber;
  reg clk=0;
  always #2.5 clk=~clk;
  reg rst_n=0, valid=0;
  reg [7:0] data=0;
  wire ready, count_valid;
  wire [7:0] addr;
  wire [15:0] errors;
  reg [7:0] reference_data=0;
  ber_calculator dut(.clk(clk),.rst_n(rst_n),.s_axis_tdata(data),
    .s_axis_tvalid(valid),.dinta(reference_data),.addra(addr),
    .BEcount(errors),.s_axis_tready(ready),.BEcount_valid(count_valid));
  function [7:0] reference_byte(input integer index);
    reference_byte=(index*37+1)&255;
  endfunction
  always @(posedge clk) reference_data<=reference_byte(addr);
  integer cases=0;
  task run_frame(input integer mode,input integer expected);
    integer i, cycles;
    reg [7:0] value;
    begin
      @(negedge clk); rst_n=0;valid=0;
      repeat(5) @(negedge clk);
      rst_n=1;repeat(3) @(negedge clk);
      for(i=0;i<239;i=i+1) begin
        value=reference_byte(i);
        if(mode==1 && i==127) value=value^8'h01;
        if(mode==2 && i==17) value=value^8'hff;
        if(mode==3) value=value^8'hff;
        data=value; valid=1;
        do @(posedge clk); while(!ready);
        @(negedge clk);valid=0;
      end
      cycles=0;
      while(!count_valid && cycles<200) begin @(negedge clk);cycles=cycles+1;end
      if(!count_valid) $fatal(1,"BER frame completion timeout");
      if(errors!==expected) $fatal(1,"BER mode=%0d expected=%0d actual=%0d",mode,expected,errors);
      cases=cases+1;
      $display("CHECK ber mode=%0d bits=1912 expected=%0d actual=%0d",mode,expected,errors);
    end
  endtask
  initial begin
    run_frame(0,0);run_frame(1,1);run_frame(2,8);run_frame(3,1912);
    $display("PASS ber cases=%0d checked_bits=%0d",cases,cases*1912);$finish;
  end
  initial begin #1000000;$fatal(1,"BER global timeout");end
endmodule
