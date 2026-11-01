module uart2fifo_v2 #(
    parameter CLK_FREQ = 50_000_000,   // 系统时钟频率 (默认50MHz)
    parameter BAUD_RATE = 5_000_000    // 波特率 (默认5Mbps)
)(
    // Global Signals
    input               clk,        // 系统时钟
    input               resetn,
    
    // RS Signals 
    input               data_in,    // 串行数据输入
    
    // AXI-Stream Master Interface
    output reg          m_axis_tvalid,
    output reg  [7:0]   m_axis_tdata,
    output reg          m_axis_tlast,  // 数据包结束标志
    input               m_axis_tready
);

// 接收状态机
reg     [15:0]  clk_cnt;        // 波特率计数器
reg     [7:0]   data_buf;       // 数据缓存
reg     [3:0]   data_cnt;       // 数据位计数器
reg     [2:0]   STATE;          // 主状态机
reg     [7:0]   pkt_counter;    // 数据包字节计数器 (0-254)

// 新增缓存寄存器
reg     [7:0]   pending_data;   // 等待发送的数据缓存
reg             has_pending;    // 缓存有效标志
reg             pending_tlast;  // 缓存的tlast标志

// ============= 同步序列检测相关寄存器 =============
reg     [20:0]  sync_shift_reg; // 同步序列移位寄存器
reg             sync_detected;  // 同步序列检测标志
// =================================================

// 动态计算波特率分频系数
localparam BAUD_DIV = (CLK_FREQ / BAUD_RATE) - 1;  // 波特率分频系数

// 状态定义
localparam [2:0] 
    SYNC_DETECT = 3'b000,   // 同步序列检测状态
    RECEIVE     = 3'b001;   // 连续数据接收状态

// 同步序列常量 (00010101010101010101 低位先发)
localparam [20:0] SYNC_PATTERN = 21'b101010101010101010101;

// ============= 输入同步器（防止亚稳态）============= // 修改开始
reg [1:0] data_in_sync;  // 两级同步寄存器

always @(posedge clk or negedge resetn) begin
    if (!resetn) begin
        data_in_sync <= 2'b00;  // 默认高电平（空闲状态）
    end else begin
        data_in_sync <= {data_in_sync[0], data_in};  // 两级同步
    end
end
// ============= 修改结束 =============

// 主状态机
always @(posedge clk or negedge resetn) begin
    if (!resetn) begin
        STATE           <= SYNC_DETECT;  // 复位后进入同步检测状态
        clk_cnt         <= 16'h0;
        data_cnt        <= 4'h0;
        data_buf        <= 8'h00;
        m_axis_tvalid   <= 1'b0;
        m_axis_tdata    <= 8'h0;
        m_axis_tlast    <= 1'b0;
        pkt_counter     <= 8'd0;
        pending_data    <= 8'h0;
        has_pending     <= 1'b0;
        pending_tlast   <= 1'b0;
        sync_shift_reg  <= 21'h0;
        sync_detected   <= 1'b0;
    end 
    else begin
        case (STATE)
            // ============= 同步序列检测状态 =============
            SYNC_DETECT: begin
                m_axis_tvalid <= 1'b0;
                m_axis_tlast  <= 1'b0;
                
                // 优先发送缓存数据
                if (has_pending && m_axis_tready) begin
                    m_axis_tdata  <= pending_data;
                    m_axis_tvalid <= 1'b1;
                    m_axis_tlast  <= pending_tlast;
                    has_pending   <= 1'b0;
                end
                
                // 波特率计数
                if (clk_cnt == BAUD_DIV) begin
                    clk_cnt <= 0;
                    
                    // 移位寄存器移入新数据
                    // ============= 使用同步后的信号 ============= // 修改开始
                    sync_shift_reg <= {data_in_sync[1], sync_shift_reg[20:1]};
                    // ============= 修改结束 =============
                    
                    // 检测同步序列
                    if (sync_shift_reg == SYNC_PATTERN) begin
                        sync_detected <= 1'b1;
                        STATE <= RECEIVE;  // 进入连续接收状态
                        clk_cnt <= 0;      // 重置波特率计数器
                        data_cnt <= 0;     // 重置数据位计数器
                        pkt_counter <= 0;   // 重置包计数器
                    end
                end 
                else begin
                    clk_cnt <= clk_cnt + 1;
                end
            end
            
            // ============= 连续数据接收状态 =============
            RECEIVE: begin
                // 优先发送缓存数据
                if (has_pending && m_axis_tready) begin
                    m_axis_tdata  <= pending_data;
                    m_axis_tvalid <= 1'b1;
                    m_axis_tlast  <= pending_tlast;
                    has_pending   <= 1'b0;
                end
                else begin
                    m_axis_tvalid <= 1'b0;
                end
                
                // 波特率计数
                if (clk_cnt == BAUD_DIV) begin
                    clk_cnt <= 0;
                    
                    // 采样数据位
                    // ============= 使用同步后的信号 ============= // 修改开始
                    data_buf <= {data_in_sync[1], data_buf[7:1]};
                    // ============= 修改结束 =============
                    
                    if (data_cnt == 7) begin
                        // 完成一个字节接收
                        data_cnt <= 0;
                        
                        // 更新包计数器并设置tlast
                        if (pkt_counter == 8'd254) begin
                            pkt_counter <= 8'd0;
                            
                            // 尝试直接发送
                            if (m_axis_tready && !has_pending) begin
                                m_axis_tdata  <= data_buf;
                                m_axis_tvalid <= 1'b1;
                                m_axis_tlast  <= 1'b1;
                            end 
                            else begin
                                // 缓存数据
                                pending_data <= data_buf;
                                pending_tlast <= 1'b1;
                                has_pending  <= 1'b1;
                            end
                            
                            // 返回同步检测状态
                            STATE <= SYNC_DETECT;
                        end 
                        else begin
                            pkt_counter <= pkt_counter + 1;
                            
                            // 尝试直接发送
                            if (m_axis_tready && !has_pending) begin
                                m_axis_tdata  <= data_buf;
                                m_axis_tvalid <= 1'b1;
                                m_axis_tlast  <= 1'b0;
                            end 
                            else begin
                                // 缓存数据
                                pending_data <= data_buf;
                                pending_tlast <= 1'b0;
                                has_pending  <= 1'b1;
                            end
                        end
                    end 
                    else begin
                        data_cnt <= data_cnt + 1;
                    end
                end 
                else begin
                    clk_cnt <= clk_cnt + 1;
                end
            end
            
            default: STATE <= SYNC_DETECT;
        endcase
    end
end

endmodule