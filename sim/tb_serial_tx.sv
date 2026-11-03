`timescale 1ns/1ps
module tb_serial_tx;
  localparam integer CLOCK_HZ=200000000, BIT_RATE=20000000, CPB=10;
  reg clk=0;always #2.5 clk=~clk;
  reg rst=0;
  reg [31:0] fifo_count=255;
  reg [7:0] data=1;
  reg valid=1;
  wire ready, txd;
  fifo2uart_v2 #(.CLK_FREQ(CLOCK_HZ),.BAUD_RATE(BIT_RATE)) dut(
    .clk(clk),.rst(rst),.fifo_cnt(fifo_count),.s_axis_tdata(data),
    .s_axis_tvalid(valid),.s_axis_tready(ready),.txd(txd));
  reg [43:0] protect=44'b00001010101010101010101010101010101000000000;
  integer byte_index=0, emitted=0, sync_cycles=0, sync_events=0;
  integer cycles=0, previous_event=-1;
  reg [7:0] expected;
  function [7:0] source_byte(input integer i);
    source_byte=(i==254)?8'h80:((i*37+1)&255);
  endfunction
  always @(negedge clk) begin
    data=source_byte(byte_index);
    valid=(byte_index<255);
    fifo_count=255-byte_index;
  end
  always @(posedge clk) if(rst) begin
    cycles=cycles+1;
    if(valid&&ready) byte_index=byte_index+1;
    if(dut.state==2'b10) begin
      sync_cycles=sync_cycles+1;
      if(dut.timer_count==CPB-1) sync_events=sync_events+1;
    end
    if(dut.state==2'b01 && dut.timer_count==CPB-1) begin
      if(previous_event>=0 && cycles-previous_event!=CPB) $fatal(1,"TX bit period expected=10 actual=%0d",cycles-previous_event);
      previous_event=cycles;
      expected=source_byte(emitted/8);
      #0.1;
      if(txd!==expected[emitted%8]) $fatal(1,"TX bit mismatch bit=%0d byte=%0d expected=%b actual=%b",emitted,emitted/8,expected[emitted%8],txd);
      emitted=emitted+1;
      if(emitted==2040) begin
        if(sync_events!=44 || sync_cycles!=440) $fatal(1,"TX sync length bits=%0d cycles=%0d",sync_events,sync_cycles);
        repeat(CPB-1)begin
          @(posedge clk);#0.1;
          if(txd!==1'b1)$fatal(1,"TX final bit shortened before its 10-cycle interval");
        end
        #4.7;if(txd!==1'b1)$fatal(1,"TX final bit changed before 50 ns elapsed");
        $display("PASS serial_tx bit_rate=20000000 logic_clock=200000000 cycles_per_bit=10 sync_bits=44 data_bits=2040 final_bit_cycles=10");$finish;
      end
    end
  end
  initial begin repeat(8) @(negedge clk);rst=1;end
  reg [1023:0] wave_path;
  initial if($value$plusargs("vcd=%s",wave_path))begin $dumpfile(wave_path);$dumpvars(0,tb_serial_tx);end
  initial begin #300000;$fatal(1,"TX timeout emitted=%0d bytes=%0d",emitted,byte_index);end
endmodule
