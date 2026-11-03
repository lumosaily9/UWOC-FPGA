`timescale 1ns/1ps
module tb_control;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,enable=0;
 wire tx,rx,guard,start;wire[1:0] state;
 wire other_tx,other_rx,other_guard,other_start;wire[1:0] other_state;
 half_duplex_ctrl #(.TX_CYCLES(7),.RX_CYCLES(9),.GUARD_CYCLES(3)) a(clk,rst,enable,tx,rx,guard,state,start);
 half_duplex_ctrl #(.TX_CYCLES(9),.RX_CYCLES(7),.GUARD_CYCLES(3),.START_WITH_TX(0)) b(clk,rst,enable,other_tx,other_rx,other_guard,other_state,other_start);
 integer guard_length=0,directions=0,tx_cycles=0,rx_cycles=0,quiet_cycles=0;
 reg prev_guard=0;
 initial begin
  repeat(3)@(negedge clk);rst=1;enable=1;
  for(integer cycle=0;cycle<4108;cycle=cycle+1)begin
   @(posedge clk);#1;
   if((tx&&rx)||(other_tx&&other_rx))$fatal(1,"tx/rx conflict");
   if(tx!==other_rx||rx!==other_tx||guard!==other_guard)$fatal(1,"peer schedule not complementary");
   if(guard&&(tx||rx))$fatal(1,"guard not quiet");
   if(cycle==0&&(!tx||!other_rx))$fatal(1,"starting role");
   if(guard)begin guard_length=guard_length+1;quiet_cycles=quiet_cycles+1;end
   if(prev_guard&&!guard)begin
    if(guard_length!=3)$fatal(1,"guard length");
    directions=directions+1;guard_length=0;
    if(!start)$fatal(1,"missing slot_start");
   end
   if(tx)tx_cycles=tx_cycles+1;
   if(rx)rx_cycles=rx_cycles+1;
   prev_guard=guard;
  end
  @(negedge clk);enable=0;@(posedge clk);#1;
  if(tx||rx||guard||state!=0)$fatal(1,"stop condition");
  $display("RESULT control_clock_hz=100000000 controller_cycles=4108 peer_complementary_checks=4108 direction_changes=%0d tx_cycles=%0d rx_cycles=%0d guard_cycles=%0d guard_cycles_per_gap=3",directions,tx_cycles,rx_cycles,quiet_cycles);
  $finish;
 end
endmodule
