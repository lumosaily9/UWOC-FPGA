`timescale 1ns / 1ps

module frame_cutter1 (
    input  wire        clk,             // 系统时钟
    input  wire        resetn,            // 同步复位（高有效）
    
    // 输入AXI-Stream接口
    input  wire [7:0]  s_axis_input_tdata,
    input  wire        s_axis_input_tvalid,
    input  wire        s_axis_input_tlast,
    output reg        s_axis_input_tready,
    output wire  [1:0]     STATE,

    
    // 输出AXI-Stream接口
    output reg  [7:0]  m_axis_output_tdata,
    output reg          m_axis_output_tvalid,
    input  wire         m_axis_output_tready,
    output reg          m_axis_output_tlast
);

// 状态机定义
localparam IDLE     = 2'b00;
localparam TRANSFER = 2'b01;
localparam DISCARD  = 2'b10;

reg [1:0] state;          // 当前状态
reg [7:0] byte_counter;   // 字节计数器（0-254）

assign STATE=state;

// 状态机逻辑
always @(posedge clk) begin
    if (!resetn) begin
        state <= IDLE;
        byte_counter <= 8'd0;
       s_axis_input_tready <= 1'b0;
         m_axis_output_tvalid <= 1'b0;
        m_axis_output_tlast <= 1'b0;
         m_axis_output_tdata <= 8'd0;
    end
    else begin
        case (state)
            // IDLE：等待帧开始
            IDLE: begin
                m_axis_output_tvalid <= 1'b0;
                m_axis_output_tlast <= 1'b0;
                if (s_axis_input_tvalid) begin
                    state <= TRANSFER;
                    byte_counter <= 8'd0;
                    s_axis_input_tready <= 1'b1;
                end
                else begin
                 state <= IDLE;
                end
            end
            
            // TRANSFER：转发前239字节
            TRANSFER: begin
                if (s_axis_input_tvalid &&  m_axis_output_tready) begin
                    // 数据路径
                     m_axis_output_tdata <= s_axis_input_tdata;
                     m_axis_output_tvalid <= 1'b1;
                    
                    // 第238字节（239th）置位tlast
                    if (byte_counter == 8'd254) begin
                        m_axis_output_tlast <= 1'b1;
                        if(s_axis_input_tlast==1'b1)begin
                        s_axis_input_tready <= 1'b0;
                        state <=IDLE;
                        end
                        else begin
                        state <= DISCARD;
                        end  // 转移至丢弃状态
                    end
                    else begin
                       state <=TRANSFER;
                    end
                    byte_counter <= byte_counter + 1;
                end
                else begin
                 m_axis_output_tvalid <= 1'b0;
                    state <=TRANSFER;
                 end
          
            end
            
            // DISCARD：丢弃最后16字节
            DISCARD: begin
                m_axis_output_tvalid <= 1'b0;  // 禁用输出
                m_axis_output_tlast <= 1'b0;   // 清除结束标志
                
                if (s_axis_input_tvalid) begin
                    if (s_axis_input_tlast==1'b1) begin
                        state <= IDLE;
                        s_axis_input_tready <= 1'b0;
                    end
                    else begin
                    state <= DISCARD;
                    end
                end
                else begin
                 state <= DISCARD;
                end
            end 
        endcase

    end
end

endmodule
