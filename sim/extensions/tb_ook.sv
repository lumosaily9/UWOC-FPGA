`timescale 1ns/1ps
module tb_ook;
    reg clk=0;always #4.166667 clk=~clk;
    integer errors=0;
    task fail(input string msg);begin $display("FAIL %s",msg);$fatal(1);end endtask
    // Independent binary mapping / threshold checks.
    reg test_bit=0;wire[13:0] test_code;
    reg signed[11:0] test_eq=0;wire test_result;
    ook_mapper map0(test_bit,test_code);
    ook_slicer slice0(test_eq,12'sd0,test_result);
    // Phase-selection checks.
    reg prst=0,pwin=0,pvalid=0;reg[11:0] psample=0;reg[2:0] phase=0;
    wire[11:0] pselected;wire pselected_valid;
    ook_phase_selector sel(clk,prst,pwin,psample,pvalid,phase,pselected,pselected_valid);
    integer phase_cases=0,gap_cases=0;
    task check_phase(input integer ph,input integer gaps);
        integer n,cycles,count,expected;
        begin
            @(negedge clk);prst=0;pwin=0;pvalid=0;
            repeat(2)@(negedge clk);
            prst=1;pwin=1;phase=ph;n=0;cycles=0;count=0;
            while(n<192)begin
                pvalid=(!gaps)||(cycles%5!=1);
                psample=n;
                if(n>90)phase=(ph+1)%6; // Locked phase may not change mid-frame.
                @(posedge clk);#1;
                expected=pvalid&&((n%6)==ph);
                if(pselected_valid!==expected)fail("phase output-valid");
                if(expected)begin
                    if(pselected!==n)fail("phase value");count=count+1;
                end
                if(pvalid)n=n+1;
                @(negedge clk);cycles=cycles+1;
            end
            pvalid=0;pwin=0;
            if(count!=32)fail("phase output count");
            if(gaps)gap_cases=gap_cases+1;else phase_cases=phase_cases+1;
        end
    endtask
    task check_window_restart;
        integer n,expected;
        begin
            @(negedge clk);pwin=0;pvalid=0;prst=1;
            repeat(2)@(negedge clk);
            pwin=1;phase=2;pvalid=1;
            for(n=0;n<12;n=n+1)begin
                psample=1000+n;@(posedge clk);#1;
                expected=(n%6==2);
                if(pselected_valid!==expected)fail("first window phase");
                if(expected&&pselected!==(1000+n))fail("first window sample");
                @(negedge clk);
            end
            pwin=0;pvalid=1;psample=3999;
            repeat(2)begin
                @(posedge clk);#1;
                if(pselected_valid||sel.sample_count!=0||sel.window_active!=0)fail("window close clear");
                @(negedge clk);
            end
            pwin=1;phase=5;
            for(n=0;n<12;n=n+1)begin
                psample=2000+n;@(posedge clk);#1;
                expected=(n%6==5);
                if(pselected_valid!==expected)fail("reopened window phase");
                if(expected&&pselected!==(2000+n))fail("reopened window sample");
                @(negedge clk);
            end
            pwin=0;pvalid=0;
        end
    endtask
    // Complete TX -> selected sample -> FIFO -> FFE -> binary decision.
    reg lrst=0,lenable=0,lvalid=0,lbit=0;wire lready;
    wire[13:0] tx_sample;wire tx_valid;
    wire[11:0] rx_sample;wire rx_valid;
    wire fq_ready,fq_valid;wire[11:0] fq_data;wire[2:0] fq_level;
    wire fe_ready,fe_valid;wire signed[11:0] fe_data;
    wire signed[11:0] centered=$signed({1'b0,fq_data})-13'sd2048;
    wire lresult;reg lout_ready=0;
    reg[79:0] identity={16'sd0,16'sd0,16'sd0,16'sd0,16'sd8192};
    ook_tx_hold hold0(clk,lrst,lenable,lbit,lvalid,lready,tx_sample,tx_valid);
    ook_phase_selector ls(clk,lrst,lenable,tx_sample[13:2],tx_valid,3'd3,rx_sample,rx_valid);
    stream_fifo #(.WIDTH(12),.DEPTH(5)) q(clk,lrst,rx_sample,rx_valid,fq_ready,fq_data,fq_valid,fe_ready,fq_level);
    ook_ffe5 fe(clk,lrst,1'b0,centered,fq_valid,fe_ready,identity,fe_data,fe_valid,lout_ready);
    ook_slicer sl(fe_data,12'sd0,lresult);
    reg expected_bits[0:1024];
    integer sent=0,got=0,loop_cycles=0,tx_samples=0;
    initial begin
        test_bit=0;#1;if(test_code!==2048)fail("map0");
        test_bit=1;#1;if(test_code!==14336)fail("map1");
        for(integer c=0;c<4096;c=c+1)begin
            test_eq=c-2048;#1;
            if(test_result!==(c>=2048))fail("binary threshold");
        end
        for(integer ph=0;ph<6;ph=ph+1)begin check_phase(ph,0);check_phase(ph,1);end
        check_window_restart();
        for(integer k=0;k<1025;k=k+1)expected_bits[k]=((k*1103515245+12345)>>12)&1;
        @(negedge clk);lrst=0;repeat(3)@(negedge clk);
        lrst=1;lenable=1;
        while(got<1025&&loop_cycles<20000)begin
            lvalid=(sent<1025);lbit=expected_bits[(sent<1025)?sent:0];
            lout_ready=(loop_cycles%41<29); // Deterministic downstream pauses.
            @(posedge clk);
            if(lvalid&&lready)sent=sent+1;
            if(tx_valid)tx_samples=tx_samples+1;
            if(rx_valid&&!fq_ready)fail("unexpected selected-sample overflow");
            if(fe_valid&&lout_ready)begin
                if(lresult!==expected_bits[got])fail("loopback order/value");got=got+1;
            end
            @(negedge clk);loop_cycles=loop_cycles+1;
        end
        if(got!=1025||sent!=1025||tx_samples!=6150)fail("loopback length");
        $display("RESULT mapper_cases=2 adc_codes=4096 phase_cases=%0d gap_phase_cases=%0d window_restart_cases=1 loopback_bits=%0d held_samples=%0d loopback_cycles=%0d",phase_cases,gap_cases,got,tx_samples,loop_cycles);
        $finish;
    end
endmodule

module tb_ffe;
    reg clk=0;always #4.166667 clk=~clk;
    reg rst=0,clear=0,sv=0,mr=0;reg signed[11:0] x=0;
    reg[79:0] coeff=0;wire sr,mv;wire signed[11:0] y;
    ook_ffe5 dut(clk,rst,clear,x,sv,sr,coeff,y,mv,mr);
    integer c[0:4];integer hist[0:3];integer gold[0:4095];integer age[0:4095];
    integer sent,got,cycle,values=0,possat=0,negsat=0,stall_checks=0,latency_min=9999;
    reg was_stall=0;reg signed[11:0] saved_y;
    longint signed acc,scaled;
    task fail(input string msg);begin $display("FAIL FFE %s",msg);$fatal(1);end endtask
    initial begin
        for(integer mode=0;mode<4;mode=mode+1)begin
            @(negedge clk);rst=0;sv=0;mr=0;
            repeat(3)@(negedge clk);
            for(integer j=0;j<4;j=j+1)hist[j]=0;
            case(mode)
                0:begin c[0]=8192;c[1]=0;c[2]=0;c[3]=0;c[4]=0;end
                1:begin c[0]=12288;c[1]=-4096;c[2]=2048;c[3]=-1024;c[4]=512;end
                2:begin c[0]=32767;c[1]=32767;c[2]=32767;c[3]=32767;c[4]=32767;end
                3:begin c[0]=-16384;c[1]=8192;c[2]=-4096;c[3]=2048;c[4]=-1024;end
            endcase
            for(integer j=0;j<5;j=j+1)coeff[j*16+:16]=c[j];
            rst=1;sent=0;got=0;cycle=0;was_stall=0;
            while(got<1024&&cycle<10000)begin
                sv=(sent<1024);x=((sent*173+mode*19)%4096)-2048;
                mr=(mode==0)?1:((cycle%31)<19);
                @(posedge clk);
                if(was_stall)begin
                    if(!mv||y!==saved_y)fail("output changed under backpressure");
                    stall_checks=stall_checks+1;
                end
                if(mv&&mr)begin
                    if($signed(y)!==gold[got])begin
                        $display("mode=%0d sample=%0d actual=%0d gold=%0d",mode,got,$signed(y),gold[got]);fail("arithmetic/order");
                    end
                    if(cycle-age[got]<latency_min)latency_min=cycle-age[got];
                    got=got+1;values=values+1;
                end
                if(sv&&sr)begin
                    acc=$signed(x)*c[0];
                    for(integer j=1;j<5;j=j+1)acc=acc+hist[j-1]*c[j];
                    scaled=acc>>>13;
                    if(scaled>2047)begin gold[sent]=2047;possat=possat+1;end
                    else if(scaled< -2048)begin gold[sent]=-2048;negsat=negsat+1;end
                    else gold[sent]=scaled;
                    age[sent]=cycle;
                    for(integer j=3;j>0;j=j-1)hist[j]=hist[j-1];
                    hist[0]=$signed(x);sent=sent+1;
                end
                was_stall=mv&&!mr;saved_y=y;
                @(negedge clk);cycle=cycle+1;
            end
            if(got!=1024)fail("length");
        end
        @(negedge clk);sv=0;clear=1;@(posedge clk);#1;
        if(mv||dut.valid_product||dut.valid_sum)fail("clear valid flags");
        for(integer j=0;j<4;j=j+1)if(dut.delay_line[j]!==0)fail("clear delay history");
        @(negedge clk);clear=0;
        if(possat==0||negsat==0||stall_checks==0||latency_min!=3)fail("coverage");
        $display("RESULT ffe_coefficient_sets=4 ffe_samples=%0d positive_saturations=%0d negative_saturations=%0d backpressure_hold_checks=%0d minimum_handshake_latency_cycles=%0d clear_history_cases=1",values,possat,negsat,stall_checks,latency_min);
        $finish;
    end
endmodule

module tb_capacity;
    reg clk=0;always #4.166667 clk=~clk;
    reg rst=0,wvalid=0,read_enable=0;reg[11:0] sample=0;
    wire rr,rv,cr,cv,sel_valid;wire[11:0] rd,cd,selected;
    wire[12:0] raw_level;wire[10:0] compact_level;
    ook_phase_selector sel(clk,rst,1'b1,sample,wvalid,3'd3,selected,sel_valid);
    stream_fifo #(.WIDTH(12),.DEPTH(6144)) raw(clk,rst,sample,wvalid,rr,rd,rv,read_enable,raw_level);
    stream_fifo #(.WIDTH(12),.DEPTH(1024)) compact(clk,rst,selected,sel_valid,cr,cd,cv,read_enable,compact_level);
    integer raw_read=0,compact_read=0,cycles=0,compact_drain=0;
    task fail(input string msg);begin $display("FAIL capacity %s",msg);$fatal(1);end endtask
    initial begin
        repeat(3)@(negedge clk);rst=1;
        for(integer i=0;i<6144;i=i+1)begin
            sample=i;wvalid=1;@(posedge clk);
            if(!rr)fail("raw overflow");@(negedge clk);
        end
        wvalid=0;repeat(3)@(negedge clk);
        if(raw_level!=6144||compact_level!=1024)fail("fill count");
        read_enable=1;
        while(raw_read<6144&&cycles<7000)begin
            @(posedge clk);
            if(rv)begin if(rd!==(raw_read%4096))fail("raw order");raw_read=raw_read+1;end
            if(cv)begin
                if(cd!==((compact_read*6+3)%4096))fail("compact order");
                compact_read=compact_read+1;
                if(compact_read==1024)compact_drain=cycles+1;
            end
            cycles=cycles+1;@(negedge clk);
        end
        if(raw_read!=6144||compact_read!=1024||cycles!=6144||compact_drain!=1024)fail("drain count");
        $display("RESULT source_bits=1024 samples_per_bit=6 raw_writes=6144 compact_writes=1024 raw_capacity_bits=73728 compact_capacity_bits=12288 raw_drain_cycles=%0d compact_drain_cycles=%0d",cycles,compact_drain);
        $finish;
    end
endmodule
