`timescale 1ns / 1ps


module tb_RA_TX();

    //parameter define
    parameter CLK_PERIOD = 20; //时钟周期 20ns

    //reg define
    reg sys_clk;
    reg sys_rst_n;

    //wire define
    wire txd_0;
    //信号初始化
    initial begin
        sys_clk = 1'b0;
        sys_rst_n = 1'b0;
        #200
         sys_rst_n = 1'b1;
    end

    //产生时钟
    always #(CLK_PERIOD/2) sys_clk = ~sys_clk;

   design_1_wrapper u_design_1_wrapper(
        .clk_in1_0         (sys_clk),
        .reset_in_0       (sys_rst_n),
        .txd_0 (txd_0)
        
        
        
    );

endmodule