`timescale 1ns/1ps
module tb_overflow_pipeline;
    reg clk=0;always #5 clk=~clk;
    reg rst=0,win=0,start=0,valid=0,out_ready=0;
    reg [11:0] sample=0;
    wire room,q_valid,overflow,abort,clear_history,fe_ready,fe_valid;
    wire [11:0] q_data;wire [2:0] level;
    wire signed [11:0] centered=$signed({1'b0,q_data})-13'sd2048;
    wire signed [11:0] equalized;
    wire [79:0] coeff={16'sd0,16'sd0,16'sd0,16'sd0,16'sd8192};
    ook_rx_guarded_fifo #(.DEPTH(5)) q(clk,rst,win,start,sample,valid,
        room,q_data,q_valid,fe_ready,level,overflow,abort,clear_history);
    ook_ffe5 fe(clk,rst,clear_history,centered,q_valid,fe_ready,
        coeff,equalized,fe_valid,out_ready);
    integer aborts=0,got=0,recovering=0,full_exchanges=0;
    // Each output of the clean frame must retain order and exact amplitude.
    always @(posedge clk) begin
        if(rst&&aborts==1&&recovering&&fe_valid&&out_ready)begin
            if(equalized!==(100+got))$fatal(1,"pipeline recovery data/order");
            got=got+1;
        end
        if(rst&&abort)aborts=aborts+1;
        if(rst&&level==5&&valid&&room&&q_valid&&fe_ready)
            full_exchanges=full_exchanges+1;
    end
    task tick;begin @(posedge clk);#1;@(negedge clk);end endtask
    initial begin
        // A missing delta-cycle convergence would trip this timeout if an
        // event-driven simulator progresses time; regression also has a
        // process-level timeout for a zero-delay loop.
        repeat(3)tick;rst=1;win=1;start=1;tick;start=0;
        valid=1;out_ready=0;
        for(integer k=0;k<32;k=k+1)begin
            sample=2100+k;tick;
            if(overflow&&(level!=0||q_valid||room))$fatal(1,"overflow blocks queue");
        end
        if(aborts!=1||!overflow||fe_valid)$fatal(1,"stalled pipeline not flushed");
        // A new receive window clears both queue and FFE state.
        win=0;valid=0;tick;win=1;start=1;out_ready=1;tick;
        start=0;recovering=1;
        for(integer k=0;k<8;k=k+1)begin
            sample=2148+k;valid=1;tick;valid=0;
            repeat(5)tick;
        end
        repeat(6)tick;
        if(got!=8||overflow||level!=0||fe_valid)$fatal(1,"next window recovery");
        recovering=0;
        // Refill until the queue is full, then unblock the FFE while a new
        // input pulse arrives. Full pop+push must not create an abort.
        out_ready=0;valid=1;
        for(integer k=0;k<8;k=k+1)begin sample=2300+k;tick;end
        if(level!=5||overflow)$fatal(1,"pipeline fill to exact capacity");
        out_ready=1;sample=2400;#1;
        if(!room||abort||!fe_ready)$fatal(1,"full pipeline exchange ready");
        tick;valid=0;
        repeat(16)tick;
        if(overflow||aborts!=1||full_exchanges<1)$fatal(1,"full exchange false abort");
        $display("RESULT integrated_overflow_events=%0d stalled_input_cycles=32 recovered_ffe_samples=%0d full_queue_pop_push_checks=%0d",aborts,got,full_exchanges);
        $finish;
    end
    initial begin #10000;$fatal(1,"pipeline timeout");end
endmodule
