`timescale 1ns/1ps
module tb_serial_rx;
  localparam integer CPB=10;
  reg clk=0;always #2.5 clk=~clk;
  reg resetn=0, data_in=0, ready=1;
  wire valid,last;
  wire [7:0] data;
  wire a,b,c;
  wire [2:0] state;
  uart2fifo_v2 #(.CLK_FREQ(200000000),.BAUD_RATE(20000000)) dut(
    .clk(clk),.resetn(resetn),.data_in(data_in),.m_axis_tvalid(valid),
    .m_axis_tdata(data),.m_axis_tlast(last),.m_axis_tready(ready),
    .Waiting_first_high(a),.First_high_valid(b),.Half_sample_done(c),.state(state));
  reg [43:0] sync_bits=44'b00001010101010101010101010101010101000000000;
  integer received=0, i,j,f,cycles=0,stress=0;
  function [7:0] source_byte(input integer index);
    source_byte=((index%255)==254)?8'h80:(((index%255)*37+1)&255);
  endfunction
  task send_bit(input reg value);
    begin @(negedge clk);data_in=value;repeat(CPB)@(posedge clk);end
  endtask
  always @(posedge clk) if(resetn) begin
    cycles=cycles+1;
    if(valid&&ready) begin
      if(data!==source_byte(received)) $fatal(1,"RX data index=%0d expected=%02x actual=%02x",received,source_byte(received),data);
      if(last!==((received%255)==254)) $fatal(1,"RX TLAST mismatch index=%0d",received);
      received=received+1;
    end
  end
  // A brief bounded stall once per byte period exercises AXI output holding.
  always @(negedge clk) if(resetn&&stress) ready=((cycles%80)<65);
  initial begin
    if($test$plusargs("stress")) stress=1;
    repeat(8)@(negedge clk);resetn=1;
    repeat(10)send_bit(0);
    for(f=0;f<2;f=f+1)begin
      for(i=0;i<44;i=i+1)send_bit(sync_bits[i]);
      for(i=0;i<255;i=i+1)
        for(j=0;j<8;j=j+1)send_bit((source_byte(f*255+i)>>j)&1);
    end
    repeat(30)send_bit(0);
    if(received!=510) $fatal(1,"RX byte count expected=510 actual=%0d",received);
    $display("PASS serial_rx bit_rate=20000000 logic_clock=200000000 received_bytes=510 frames=2 sync_bits=44 stress=%0d",stress);$finish;
  end
  initial begin #300000;$fatal(1,"RX timeout received=%0d",received);end
  reg [1023:0] wave_path;
  initial if($value$plusargs("vcd=%s",wave_path))begin $dumpfile(wave_path);$dumpvars(0,tb_serial_rx);end
endmodule
