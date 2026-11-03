`timescale 1ns/1ps
module ook_mapper #(
    parameter [13:0] LEVEL_0=14'd2048,
    parameter [13:0] LEVEL_1=14'd14336
)(input wire s_bit,output wire [13:0] m_code);
    assign m_code=s_bit?LEVEL_1:LEVEL_0;
endmodule

module ook_tx_hold #(
    parameter integer SPS=6,
    parameter [13:0] LEVEL_0=14'd2048,
    parameter [13:0] LEVEL_1=14'd14336,
    parameter integer CW=(SPS<=1)?1:$clog2(SPS)
)(input wire clk,rst_n,enable,input wire s_bit,s_valid,
  output wire s_ready,output reg [13:0] m_sample,output reg m_valid);
    reg [CW-1:0] remaining;
    reg [13:0] held;
    assign s_ready=enable&&(remaining==0);
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin remaining<=0;held<=0;m_sample<=0;m_valid<=0;end
        else if(!enable) begin remaining<=0;m_valid<=0;end
        else if(remaining!=0) begin
            m_sample<=held;m_valid<=1;remaining<=remaining-1'b1;
        end else if(s_valid) begin
            held<=s_bit?LEVEL_1:LEVEL_0;
            m_sample<=s_bit?LEVEL_1:LEVEL_0;
            m_valid<=1;remaining<=SPS-1;
        end else m_valid<=0;
    end
endmodule

module ook_phase_selector #(
    parameter integer SPS=6,
    parameter integer CW=(SPS<=1)?1:$clog2(SPS)
)(input wire clk,rst_n,rx_window,input wire [11:0] s_sample,
  input wire s_valid,input wire [CW-1:0] sample_phase,
  output reg [11:0] m_sample,output reg m_valid);
    reg [CW-1:0] sample_count,phase_locked;
    reg window_active;
    wire [CW-1:0] selected_phase=window_active?phase_locked:sample_phase;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin sample_count<=0;phase_locked<=0;window_active<=0;m_sample<=0;m_valid<=0;end
        else begin
            m_valid<=0;
            if(!rx_window) begin sample_count<=0;window_active<=0;end
            else begin
                if(!window_active) begin phase_locked<=sample_phase;window_active<=1;end
                if(s_valid) begin
                    sample_count<=(sample_count==SPS-1)?0:sample_count+1'b1;
                    if(sample_count==selected_phase) begin m_sample<=s_sample;m_valid<=1;end
                end
            end
        end
    end
endmodule

// Five symbol-spaced taps. Coefficients are signed 16-bit integers / 8192.
// PS must keep the coefficient vector constant throughout each frame.
module ook_ffe5 #(
    parameter integer DATA_WIDTH=12,
    parameter integer COEFF_WIDTH=16,
    parameter integer FRAC_BITS=13,
    parameter integer TAPS=5,
    parameter integer PW=DATA_WIDTH+COEFF_WIDTH,
    parameter integer AW=PW+$clog2(TAPS)
)(input wire clk,rst_n,clear_history,
  input wire signed [DATA_WIDTH-1:0] s_sample,input wire s_valid,
  output wire s_ready,input wire [TAPS*COEFF_WIDTH-1:0] coeff_q13,
  output reg signed [DATA_WIDTH-1:0] m_equalized,output wire m_valid,
  input wire m_ready);
    reg signed [DATA_WIDTH-1:0] delay_line[0:TAPS-2];
    reg signed [PW-1:0] product[0:TAPS-1];
    reg signed [AW-1:0] accumulator,sum_next,scaled;
    reg valid_product,valid_sum,valid_output;
    wire advance=!valid_output||m_ready;
    integer k;
    localparam integer SAT_MAX=(1<<(DATA_WIDTH-1))-1;
    localparam integer SAT_MIN=-(1<<(DATA_WIDTH-1));
    assign s_ready=advance&&!clear_history;
    assign m_valid=valid_output;
    always @* begin
        sum_next=0;
        for(integer j=0;j<TAPS;j=j+1)
            sum_next=sum_next+{{(AW-PW){product[j][PW-1]}},product[j]};
        scaled=accumulator>>>FRAC_BITS;
    end
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            for(k=0;k<TAPS-1;k=k+1)delay_line[k]<=0;
            for(k=0;k<TAPS;k=k+1)product[k]<=0;
            accumulator<=0;m_equalized<=0;
            valid_product<=0;valid_sum<=0;valid_output<=0;
        end else if(clear_history) begin
            for(k=0;k<TAPS-1;k=k+1)delay_line[k]<=0;
            valid_product<=0;valid_sum<=0;valid_output<=0;
        end else if(advance) begin
            valid_product<=s_valid;
            valid_sum<=valid_product;
            valid_output<=valid_sum;
            if(s_valid) begin
                product[0]<=$signed(s_sample)*$signed(coeff_q13[0+:COEFF_WIDTH]);
                for(k=1;k<TAPS;k=k+1)
                    product[k]<=$signed(delay_line[k-1])*$signed(coeff_q13[k*COEFF_WIDTH+:COEFF_WIDTH]);
                delay_line[0]<=s_sample;
                for(k=1;k<TAPS-1;k=k+1)delay_line[k]<=delay_line[k-1];
            end
            if(valid_product)accumulator<=sum_next;
            if(valid_sum) begin
                if(scaled>SAT_MAX)m_equalized<=SAT_MAX;
                else if(scaled<SAT_MIN)m_equalized<=SAT_MIN;
                else m_equalized<=scaled[DATA_WIDTH-1:0];
            end
        end
    end
endmodule

module ook_slicer #(
    parameter integer DATA_WIDTH=12
)(input wire signed [DATA_WIDTH-1:0] s_equalized,
  input wire signed [DATA_WIDTH-1:0] threshold,
  output wire m_bit);
    assign m_bit=($signed(s_equalized)>=$signed(threshold));
endmodule
