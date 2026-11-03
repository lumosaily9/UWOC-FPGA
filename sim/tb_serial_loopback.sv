`timescale 1ns/1ps
module tb_serial_loopback;
  reg clk=0;always #2.5 clk=~clk;
  reg resetn=0;
  reg [7:0] tx_data=1;
  reg tx_valid=1,rx_ready=1;
  reg [31:0] fifo_count=255;
  wire tx_ready,wire_data,rx_valid,rx_last;
  wire [7:0] rx_data;
  wire a,b,c;
  wire [2:0] state;
  integer tx_index=0,rx_index=0,cycles=0,stress=0;
  function [7:0] source_byte(input integer i);
    source_byte=(i==254)?8'h80:((i*37+1)&255);
  endfunction
  fifo2uart_v2 #(.CLK_FREQ(200000000),.BAUD_RATE(20000000)) tx(
    .clk(clk),.rst(resetn),.fifo_cnt(fifo_count),.s_axis_tdata(tx_data),
    .s_axis_tvalid(tx_valid),.s_axis_tready(tx_ready),.txd(wire_data));
  uart2fifo_v2 #(.CLK_FREQ(200000000),.BAUD_RATE(20000000)) rx(
    .clk(clk),.resetn(resetn),.data_in(wire_data),.m_axis_tvalid(rx_valid),
    .m_axis_tdata(rx_data),.m_axis_tlast(rx_last),.m_axis_tready(rx_ready),
    .Waiting_first_high(a),.First_high_valid(b),.Half_sample_done(c),.state(state));
  always @(posedge clk)if(resetn)begin
    cycles=cycles+1;
    if(tx_ready&&tx_valid)tx_index=tx_index+1;
    if(rx_ready&&rx_valid)begin
      if(rx_data!==source_byte(rx_index))$fatal(1,"loopback data index=%0d expected=%02x actual=%02x",rx_index,source_byte(rx_index),rx_data);
      if(rx_last!==(rx_index==254))$fatal(1,"loopback TLAST index=%0d",rx_index);
      rx_index=rx_index+1;
    end
  end
  always @(negedge clk)if(resetn)begin
    tx_valid=(tx_index<255);tx_data=source_byte(tx_index);fifo_count=255-tx_index;
    rx_ready=stress?((cycles%80)<65):1;
  end
  initial begin
    if($test$plusargs("stress"))stress=1;
    repeat(8)@(negedge clk);resetn=1;
    wait(rx_index==255);repeat(20)@(negedge clk);
    if(tx_index!=255)$fatal(1,"loopback TX byte count=%0d",tx_index);
    $display("PASS serial_loopback tx_bytes=255 rx_bytes=255 bit_rate=20000000 stress=%0d",stress);$finish;
  end
  initial begin #300000;$fatal(1,"loopback timeout tx=%0d rx=%0d",tx_index,rx_index);end
endmodule
