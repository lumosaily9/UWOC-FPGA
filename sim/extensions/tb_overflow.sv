`timescale 1ns/1ps
module tb_overflow;
    reg clk=0;always #5 clk=~clk;
    reg rst=0,win=0,start=0,valid=0,ready=0;
    reg [11:0] sample=0;
    wire room,out_valid,overflow,abort,clear_history;
    wire [11:0] data;wire[2:0] level;
    ook_rx_guarded_fifo #(.DEPTH(5)) dut(clk,rst,win,start,sample,valid,
        room,data,out_valid,ready,level,overflow,abort,clear_history);
    integer drops=0,recovered=0,full_exchange=0;
    task tick;begin @(posedge clk);#1;@(negedge clk);end endtask
    initial begin
        repeat(3)tick;rst=1;win=1;start=1;tick;start=0;
        valid=1;ready=0;
        for(integer k=0;k<5;k=k+1)begin sample=100+k;tick;end
        if(level!=5||overflow||room)$fatal(1,"queue fill");
        sample=105;#1;
        if(!abort||clear_history)$fatal(1,"abort must not feed combinational FFE clear");
        drops=drops+1;tick;
        if(!overflow||!clear_history||level!=0||out_valid||room)$fatal(1,"overflow sticky and queue flush");
        for(integer k=0;k<20;k=k+1)begin
            sample=200+k;ready=1;tick;
            if(out_valid||!overflow||level!=0||abort)$fatal(1,"invalid frame blocked");
        end
        valid=0;win=0;tick;
        if(!clear_history||!overflow)$fatal(1,"window close clear and sticky");
        win=1;start=1;tick;start=0;
        if(overflow||level!=0)$fatal(1,"next frame reset");
        // New frame recovers clean order, including full-queue pop+push.
        valid=1;ready=0;
        for(integer k=0;k<5;k=k+1)begin sample=300+k;tick;end
        sample=305;ready=1;#1;
        if(!room||!out_valid||abort||data!=300)$fatal(1,"full pop/push room");
        full_exchange=full_exchange+1;recovered=recovered+1;tick;
        valid=0;
        for(integer k=301;k<=305;k=k+1)begin
            if(!out_valid||data!=k||overflow)$fatal(1,"recovered order");
            recovered=recovered+1;tick;
        end
        if(level||out_valid)$fatal(1,"drain empty");
        // Closing a nonempty window synchronously flushes stale samples.
        ready=0;valid=1;sample=999;tick;valid=0;win=0;tick;
        if(level!=0||out_valid)$fatal(1,"closed window flush");
        $display("RESULT overflow_events=%0d blocked_frame_samples=20 recovered_samples=%0d full_pop_push_cases=%0d synchronous_window_flush_cases=1",drops,recovered,full_exchange);
        $finish;
    end
endmodule
