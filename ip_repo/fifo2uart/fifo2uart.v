`timescale 1ns / 1ps

module fifo2uart #(
    parameter CLK_FREQ = 50_000_000,  // 系统时钟频率 (默认50MHz)
    parameter BAUD_RATE = 5000000       // 波特率 (默认115200)
) (
    input clk,                // 50MHz 系统时钟
    input rst,                // 低电平复位

    // AXI4-Stream 输入接口
    input [7:0] s_axis_tdata,
    input s_axis_tvalid,
    output reg s_axis_tready,

    // 串行输出接口
    output reg txd            // 串行数据输出
);

// 计算每个UART位所需的时钟周期数
localparam integer CYCLES_PER_BIT = CLK_FREQ / BAUD_RATE;
localparam integer TIMER_WIDTH = $clog2(CYCLES_PER_BIT);

// 状态定义 - 修改：增加PROTECT状态
localparam IDLE   = 2'b00;
localparam SEND   = 2'b01;
localparam PROTECT = 2'b10;  // 新增保护状态

reg [1:0] state;             // 修改：状态位宽改为2位
reg [9:0] shift_reg;          // 10位数据移位寄存器 (LSB=起始位1, 位1-8=数据, MSB=停止位0)
reg [7:0] next_data;          // 下个数据缓存
reg has_next;                 // 缓存有效标志
reg [TIMER_WIDTH-1:0] timer_count; // 位周期计数器 (0-9)
reg [17:0] bit_count;          // 位索引计数器 (0-18)
reg [6:0] wait_counter;       // 等待计数器 (0-4)

// 新增：字节计数器和保护序列寄存器
reg [7:0] byte_counter = 0;  // 字节计数器（0-254）
reg [62:0] PROTECT_SEQ_INIT = 63'b000000000000010101010101010101010101010101010101010000000000000; // 保护序列（LSB first）
reg [62:0] protect_seq;

always @(posedge clk or negedge rst) begin
    if (!rst) begin
        state <= IDLE;
        s_axis_tready <= 1'b0;
        shift_reg <= 10'b0;
        next_data <= 8'b0;
        has_next <= 1'b0;
        timer_count <= 0;
        bit_count <= 18'b0;
        txd <= 1'b0;          // 复位时保持低电平
        wait_counter <= 4'b0; // 复位等待计数器
        byte_counter <= 0;    // 复位字节计数器
    end 
    else begin
            case (state)
                IDLE: begin
                    txd <= 1'b0;        // 空闲时输出低电平
                    timer_count <= 0; 
                    bit_count <= 18'b0;
                    s_axis_tready <= 1'b1; // 准备好接收数据
                    
                    if (s_axis_tvalid && s_axis_tready) begin
                        // 构造10位数据帧: {停止位0, 数据[7:0], 起始位1}
                        shift_reg <= {1'b0, s_axis_tdata, 1'b1}; 
                        state <= SEND;           // 进入发送状态
                        txd <= shift_reg[0];     // 立即发送起始位 (LSB=1)
                        s_axis_tready <= 1'b0;   // 暂停接收新数据
                    end
                end
                
                SEND: begin
                    // 每个位周期保持CYCLES_PER_BIT个时钟周期
                    if (timer_count == CYCLES_PER_BIT - 1) begin
                        timer_count <= 0;
                        
                        if (bit_count == 4'd9) begin   // 发送完10位
                            // 修改：发送完一个字节后增加计数器
                            byte_counter <= byte_counter + 1;
                            
                            // 修改：检查是否达到255字节
                            if (byte_counter == 8'd254) begin
                                state <= PROTECT;      // 进入保护状态
                                timer_count <= 0;
                                bit_count <= 0;
                                protect_seq <= PROTECT_SEQ_INIT;
                                txd <= PROTECT_SEQ_INIT[0]; // 开始发送保护序列
                                byte_counter <= 0;     // 重置字节计数器
                            end
                            else if (has_next) begin   // 有缓存数据
                                // 加载缓存数据并构造新帧
                                shift_reg <= {1'b0, next_data, 1'b1}; 
                                bit_count <= 4'b0;     // 重置位计数
                                has_next <= 1'b0;      
                                txd <= shift_reg[0];   // 发送新帧起始位
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
                    if (bit_count == 4'd8 && timer_count == CYCLES_PER_BIT - 1) begin
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
                
                // 新增：保护状态
                PROTECT: begin
                    s_axis_tready <= 1'b0; // 保护状态下不接收数据
                    
                    if (timer_count == CYCLES_PER_BIT - 1) begin
                        timer_count <= 0;
                        
                        if (bit_count == 18'd62) begin  // 发送完63位保护序列
                            // 修复：检查是否有缓存数据
                            if (has_next) begin
                                // 加载缓存数据并构造新帧
                                shift_reg <= {1'b0, next_data, 1'b1};
                                bit_count <= 18'b0;
                                state <= SEND;
                                txd <= shift_reg[0];   // 发送新帧起始位
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