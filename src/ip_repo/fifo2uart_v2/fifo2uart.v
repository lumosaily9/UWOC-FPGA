`timescale 1ns / 1ps

module fifo2uart_v2 #(
    parameter CLK_FREQ = 200_000_000,  // 系统时钟频率 (200 MHz)
    parameter BAUD_RATE = 20_000_000       // 串行码元速率 (20 MBd)
) (
    input clk,                // 200 MHz 系统时钟
    input rst,                // 低电平复位
    input [31:0]fifo_cnt,            
    // AXI4-Stream 输入接口
    input [7:0] s_axis_tdata,
    input s_axis_tvalid,
    output reg s_axis_tready,

    // 串行输出接口
    output reg txd            // 串行数据输出
);

// 计算每个串行数据位的时钟周期数
localparam integer CYCLES_PER_BIT = CLK_FREQ / BAUD_RATE;
localparam integer TIMER_WIDTH = $clog2(CYCLES_PER_BIT);

// 发送状态定义
localparam IDLE   = 3'b000;
localparam SEND   = 3'b001;
localparam PROTECT = 3'b010;  // 同步序列发送状态
localparam WAIT = 3'b011;
localparam FINISH = 3'b100; 

reg [2:0] state;             // 3位发送状态寄存器
reg [7:0] shift_reg;          // 8位数据移位寄存器，低位优先
reg [7:0] next_data;          // 下个数据缓存
reg has_next;                 // 缓存有效标志
reg [TIMER_WIDTH-1:0] timer_count; // 位周期计数器 (0-9)
reg [17:0] bit_count;          // 位索引：数据位0-7，同步序列位0-43
reg [6:0] wait_counter;       // 启动等待计数器
reg [9:0] frame_cnt;  
// 码字字节计数器与同步序列寄存器
reg [7:0] byte_counter = 0;  // 字节计数器（0-254）
reg [43:0] PROTECT_SEQ_INIT = 44'b00001010101010101010101010101010101000000000; // 同步序列（LSB first）
reg [43:0] protect_seq;
reg [15:0] invalid_word;

always @(posedge clk or negedge rst) begin
    if (!rst) begin
        state <= WAIT;
        s_axis_tready <= 1'b0;
        shift_reg <= 8'b0;
        next_data <= 8'b0;
        has_next <= 1'b0;
        timer_count <= 0;
        bit_count <= 18'b0;
        txd <= 1'b0;          // 复位时保持低电平
        wait_counter <= 4'b0; // 复位等待计数器
        byte_counter <= 0;    // 复位字节计数器
        frame_cnt<= 0;
        invalid_word<= 16'b11001010110001;
    end 
    else begin
            case (state)
            
                WAIT: begin
                    protect_seq <= PROTECT_SEQ_INIT;
                    bit_count <= 18'b0;
                     txd <= 1'b0;
                    if (fifo_cnt>=31'd254) begin
                        state <= PROTECT;
                        timer_count <= 0;
                        frame_cnt<=1;
                    end
                end      
                      
                IDLE: begin
                    txd <= 1'b0;        // 空闲时输出低电平
                    timer_count <= 0; 
                    bit_count <= 18'b0;
                    s_axis_tready <= 1'b1; // 准备好接收数据
                    if (s_axis_tvalid && s_axis_tready) begin
                        // 装载连续8位数据，不插入逐字节起止位
                        shift_reg <= s_axis_tdata; 
                        state <= SEND;           // 进入发送状态
                        s_axis_tready <= 1'b0;   // 暂停接收新数据
                    end
                end
                
                SEND: begin
                    // 每个位周期保持CYCLES_PER_BIT个时钟周期
                    if (timer_count == CYCLES_PER_BIT - 1) begin
                        timer_count <= 0;
                        if (bit_count == 4'd7) begin   // 输出当前字节第8位
                            // 发送完一个字节后更新计数
                            byte_counter <= byte_counter + 1;
                            
                            // 检查255字节码字末尾
                            if (byte_counter == 8'd254) begin
                                // 输出第7位并保持完整位周期。
                                txd <= shift_reg[0];
                                state <= FINISH;
                                timer_count <= 0;
                                bit_count <= 0;
                                byte_counter <= 0;
                            end
                            else if (has_next) begin   // 有缓存数据
                                // 载入下一字节
                                shift_reg <= next_data; 
                                bit_count <= 4'b0;     // 重置位计数
                                has_next <= 1'b0;      
                                txd <= shift_reg[0];   // 输出当前移位寄存器末位
                            end 
                            else begin                 // 无缓存数据
                                state <= IDLE;         // 返回空闲状态
                            end
                        end 
                        else begin
                            bit_count <= bit_count + 1; // 指向下一位
                            // 右移并发送新LSB (LSB-first)
                            shift_reg <= shift_reg >> 1; 
                            txd <= shift_reg[0];       // 发送新位
                        end
                    end 
                    else begin
                        timer_count <= timer_count + 1;
                    end
                    // 在第8位周期预取新数据
                    if (bit_count == 4'd6 && timer_count == CYCLES_PER_BIT - 1) begin
                        s_axis_tready <= 1'b1; // 打开一个周期接收窗口
                    end
                    else if (s_axis_tready) begin
                        s_axis_tready <= 1'b0; // 确保只激活一个周期
                    end
                    // 捕获新数据到缓存
                    if (s_axis_tready && s_axis_tvalid) begin
                        next_data <= s_axis_tdata;
                        has_next <= 1'b1;
                    end
                end
                
                // 末位保持完整码元周期。
                FINISH: begin
                    s_axis_tready <= 1'b0;
                    if (timer_count == CYCLES_PER_BIT - 1) begin
                        timer_count <= 0;
                        txd <= 1'b0;
                        state <= WAIT;
                    end else begin
                        timer_count <= timer_count + 1'b1;
                    end
                end

                // 同步序列发送
                PROTECT: begin
                    s_axis_tready <= 1'b0; // 保护状态下不接收数据
                    if (timer_count == CYCLES_PER_BIT - 1) begin
                        timer_count <= 0;
                        if (bit_count == 18'd43) begin  // 完成44位同步序列
                            // 检查下一字节缓存
                            if (has_next) begin
                                // 载入下一字节
                                shift_reg <= next_data;
                                bit_count <= 18'b0;
                                state <= SEND;
                                txd <= shift_reg[0];   // 输出当前移位寄存器末位
                                has_next <= 1'b0;
                            end
                            else begin
                                state <= IDLE;    // 返回空闲状态
                            end
                        end
                        else begin
                            bit_count <= bit_count + 1;
                            protect_seq <= protect_seq >> 1; // 右移序列
                            txd <= protect_seq[0];           // 发送下一位
                        end
                    end 
                    else begin
                        timer_count <= timer_count + 1;
                    end
                end
            endcase
        end
    end
endmodule