module BECNT_UARTOUT_V2 #(
    parameter CLK_FREQ = 100_000_000,  // 时钟频率(Hz)
    parameter BAUD_RATE = 115200      // 波特率

) (
    input wire clk,                // 时钟
    input wire rst_n,              // 异步低电平复位
    
    // AXI-Stream Slave接口
    input wire [15:0] s_axis_tdata,   // 输入数据
    input wire s_axis_tvalid,         // 输入数据有效
    output reg s_axis_tready,         // 接收准备好
    
    // 数据计数输入
    input wire [31:0] data_cnt,        // 外部数据计数器
    
    // UART输出
    output reg BEout                  // UART发送引脚
);

// 状态定义
localparam IDLE        = 2'd0;  // 等待数据足够
localparam RECEIVE     = 2'd1;  // 接收10个数
localparam SEND1        = 2'd2; 
localparam SEND2        = 2'd3; // 发送状态
localparam CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;
// 寄存器定义
reg [1:0] state;            // 当前状态
reg [31:0] recv_cnt;         // 已接收数据计数
reg [23:0] sum_reg;         // 累加寄存器(20位，防止溢出)
reg [9:0] tx_low;           // 低字节10位数据: 1(起始位0) + 8位数据 + 0(停止位1)
reg [9:0] tx_mid;   
reg [9:0] tx_high;          // 高字节10位数据: 1(起始位0) + 8位数据 + 0(停止位1)
reg [9:0] tx_shift_reg;     // 发送移位寄存器
reg [3:0] bit_cnt;          // 发送位计数器
reg [2:0] byte_sel;               // 字节选择: 0=低字节, 1=高字节
reg [31:0] baud_cnt;        // 波特率计数器
reg [9:0] tx_FF;

// 状态转移
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        recv_cnt <= 32'd0;
        sum_reg <= 24'd0;
        s_axis_tready <= 1'b0;
        tx_low <= 10'd0;
        tx_mid <= 10'd0;
        tx_high <= 10'd0;
        tx_shift_reg <= 10'd0;
        bit_cnt <= 4'd0;
        byte_sel <= 3'b0;
        baud_cnt <= 32'd0;
        BEout <= 1'b1; 
        tx_FF<=10'b1111111110; // 空闲时为高电平
    end else begin
        case (state)
            // 状态1: 等待数据足够
            IDLE: begin
                recv_cnt <= 32'd0;
                sum_reg <= 24'd0;
                BEout <= 1'b1;
                bit_cnt <= 4'd0;
                baud_cnt <= 32'd0;
                byte_sel <= 3'b000;
                
                if (data_cnt >= 32'd1000) begin
                    s_axis_tready <= 1'b1;  // 准备接收
                    state <= RECEIVE;
                end
            end
            
            // 状态2: 接收1000个数并累加
            RECEIVE: begin
                if (s_axis_tvalid && s_axis_tready) begin
                    // 累加
                    sum_reg <= sum_reg + s_axis_tdata;
                    recv_cnt <= recv_cnt + 31'd1;
                    
                    if (recv_cnt == 32'd999) begin
                        s_axis_tready <= 1'b0;  // 停止接收
                        
               
                       sum_reg <= sum_reg + s_axis_tdata;
                        
                        state <= SEND1;
                        baud_cnt <= 32'd0;
                        BEout <= 1'b1;  // 起始为高电平
                    end
                end
            end
            
            SEND1:begin
            tx_low<={1'b1, sum_reg[7:0], 1'b0}; 
            tx_mid<={1'b1, sum_reg[15:8], 1'b0}; 
            tx_high<={1'b1, sum_reg[23:16], 1'b0}; 
            tx_shift_reg<=tx_FF; 
            state <= SEND2;
            end
            
            // 状态3: 发送10位数据(起始位0 + 8位数据 + 停止位1)
            SEND2: begin
                if (baud_cnt < CLKS_PER_BIT - 1) begin
                    baud_cnt <= baud_cnt + 32'd1;
                end else begin
                    baud_cnt <= 32'd0;
                    
                    // 发送当前位
                    BEout <= tx_shift_reg[bit_cnt];
                    
                    if (bit_cnt < 4'd9) begin
                        // 发送下一个位
                        bit_cnt <= bit_cnt + 4'd1;
                    end else begin
                        // 当前10位发送完成
                        bit_cnt <= 4'd0;
                        
                        if (byte_sel == 3'b000) begin
                            // 发送高字节
                            tx_shift_reg <= tx_FF;
                            byte_sel <= 3'b001;
                        end 
                        else if(byte_sel == 3'b001)begin
                            tx_shift_reg <= tx_FF;
                            byte_sel <= 3'b010;
                        end
                        else if(byte_sel == 3'b010)begin
                        tx_shift_reg <= tx_FF;
                        byte_sel <= 3'b011; 
                        end
                        else if(byte_sel == 3'b011)begin
                        tx_shift_reg <=  tx_high;
                            byte_sel <= 3'b100; 
                        end
                        else if(byte_sel == 3'b100)begin
                      tx_shift_reg <=  tx_mid;
                           byte_sel <= 3'b101; 
                        end
                        else if(byte_sel == 3'b101)begin
                         tx_shift_reg <=  tx_low;
                           byte_sel <= 3'b111; 
                        end
                        else if(byte_sel == 3'b111)begin
                       tx_shift_reg <=  0;
                           byte_sel <= 3'b000; 
                           state<=IDLE;
                        end
                    end
                end
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule