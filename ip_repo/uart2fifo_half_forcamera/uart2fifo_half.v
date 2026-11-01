module uart2fifo_half_forcamera #(
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
reg     [7:0]   data_cnt;       // 数据位计数器
reg             bit_flag;   
reg             bit_buf;
reg     [2:0]   STATE;          // 主状态机
reg     [7:0]   pkt_counter;    // 数据包字节计数器 (0-254)

// 新增缓存寄存器
reg     [7:0]   pending_data;   // 等待发送的数据缓存
reg             has_pending;    // 缓存有效标志

// ============= 新增同步序列检测相关寄存器 =============
reg     [37:0]  sync_shift_reg; // 同步序列移位寄存器
reg     [7:0]   sync_cnt;       // 同步序列位计数器
reg             sync_detected;  // 同步序列检测标志
reg     [7:0]   zero_cnt;       // 连续0计数器
reg             waiting_first_high; // 等待第一个高电平标志
reg             first_high_valid;
reg            half_sample_done;   // 半周期采样完成标志
// =================================================

// 动态计算波特率分频系数
localparam BAUD_DIV = (CLK_FREQ / BAUD_RATE) - 1;  // 波特率分频系数
localparam HALF_BAUD_DIV = (BAUD_DIV + 1) / 2 - 1; // 半波特率周期值

// 状态定义 - 新增SYNC_DETECT状态
localparam [2:0] 
    SYNC_DETECT = 3'b000,   // 新增：同步序列检测状态
    IDLE        = 3'b001,
    START       = 3'b010,
    STOP        = 3'b011;

// 同步序列常量 (00010101010101010101 低位先发)
localparam [37:0] SYNC_PATTERN = 38'b01010101010101010101010101010101010101;

// 主状态机
always @(posedge clk or negedge resetn) begin
    if (!resetn) begin
        STATE           <= SYNC_DETECT;  // 复位后进入同步检测状态
        clk_cnt         <= 16'h0;
        data_cnt        <= 8'h0;
        data_buf        <= 8'h00;
        m_axis_tvalid   <= 1'b0;
        m_axis_tdata    <= 8'h0;
        m_axis_tlast    <= 1'b0;
        pkt_counter     <= 8'd0;
        pending_data    <= 8'h0;
        has_pending     <= 1'b0;
        bit_flag        <= 1'b0;
        bit_buf         <= 1'b0;
        
        // ============= 新增同步检测复位 =============
        sync_shift_reg  <= 38'h0;
        sync_cnt        <= 6'h0;
        sync_detected   <= 1'b0;
        zero_cnt        <= 8'h0;
        waiting_first_high <= 1'b0;
        half_sample_done   <= 1'b0;
        first_high_valid    <= 1'b0;
        // =========================================
    end 
    else begin
        case (STATE)
            // ============= 新增同步序列检测状态 =============
             SYNC_DETECT: begin
                m_axis_tvalid <= 1'b0;
                m_axis_tlast  <= 1'b0;
                has_pending   <= 1'b0;
          
                
                // 波特率计数
                if (!waiting_first_high) begin
                 if (clk_cnt == BAUD_DIV)begin
                    clk_cnt <= 0;
                    
                    // 阶段1: 检测连续8位0
                    if (!waiting_first_high && !half_sample_done) begin
                        if (data_in == 1'b0) begin
                            if (zero_cnt == 8'd5) begin
                                // 检测到连续8位0，进入等待高电平阶段
                                waiting_first_high <= 1'b1;
                                zero_cnt <= 8'h0;
                            end else begin
                                zero_cnt <= zero_cnt + 1;
                            end
                        end else begin
                            zero_cnt <= 8'h0; // 遇到1，清零计数器
                        end
                    end 
                    end else begin
                    clk_cnt <= clk_cnt + 1;
                    end
                end
                    // 阶段2: 等待第一个高电平并验证
                   if (waiting_first_high && !half_sample_done) begin
                        if (data_in == 1'b1) begin
                            // 检测到高电平，启动半周期验证
                            zero_cnt <= 8'h0;
                            half_sample_done <= 1'b1;
                            clk_cnt <= 0; // 重置计数器用于半周期采样
                        end 
                    end
                    // 阶段3: 半周期后验证高电平
                    if (half_sample_done && !first_high_valid) begin
                     if (clk_cnt == HALF_BAUD_DIV-1)begin
                        if (data_in == 1'b1) begin
                            // 高电平验证成功，开始采样38位同步序列
                         
                             first_high_valid<= 1'b1;
                             sync_shift_reg <= {data_in, sync_shift_reg[37:1]};
                            sync_cnt <= sync_cnt + 1;  
                            clk_cnt <= 0;
                        end else begin
                            // 验证失败，重新开始
                            half_sample_done <= 1'b0;
                            zero_cnt <= 8'h0;
                            waiting_first_high <= 1'b0;
                        end
                        end else begin
                        clk_cnt <= clk_cnt + 1;
                        end
                    end
                    // 阶段4: 采样38位同步序列
                    if ( first_high_valid && sync_cnt < 6'd39) begin
                        if (clk_cnt == BAUD_DIV) begin
                            clk_cnt <= 0;
                            sync_shift_reg <= {data_in, sync_shift_reg[37:1]};
                            sync_cnt <= sync_cnt + 1;
                           
                            // 完成38位采样后进行比较
                            if (sync_cnt == 6'd38) begin
                                if (sync_shift_reg == SYNC_PATTERN) begin
                                    first_high_valid   <=1'b0;
                                    sync_shift_reg  <=6'd0;
                                      half_sample_done    <=1'b0;
                                    sync_cnt <= 6'h0;
                                     waiting_first_high <= 1'b0;
                                    STATE <= IDLE;
                                end else begin
                                    // 同步序列不匹配，重新开始检测
                                    first_high_valid   <=1'b0;
                                    zero_cnt <= 8'h0;
                                    sync_cnt <= 6'h0;
                                      half_sample_done    <=1'b0;
                                    sync_shift_reg<=6'd0;
                                    waiting_first_high <= 1'b0;
                                end
                            end
                        end else begin
                            clk_cnt <= clk_cnt + 1;
                        end
                    end
                end 
            
            // =============================================
            
            // IDLE状态：优先处理缓存数据
            IDLE: begin
                m_axis_tvalid <= 1'b0;
                m_axis_tlast  <= 1'b0;
                sync_shift_reg  <= 38'h0;
                
                // 优先发送缓存数据
                if (has_pending) begin
                    if (m_axis_tready) begin
                        m_axis_tdata  <= pending_data;
                        m_axis_tvalid <= 1'b1;
                        m_axis_tlast  <= (pkt_counter == 8'd254);
                        if (pkt_counter == 8'd254) begin
                            pkt_counter <= 8'd0;
                        end else begin
                            pkt_counter <= pkt_counter + 1;
                        end
                        has_pending  <= 1'b0;
                    end
                end
                // 检测起始位 (现在是1)
                else if (data_in == 1'b1) begin
            if (clk_cnt == HALF_BAUD_DIV-1) begin 
                // 半周期后再次确认电平状态
                if (data_in == 1'b1) begin
                    clk_cnt  <= 0;
                    data_cnt <= 0;
                    data_buf <= 8'h00;
                    STATE    <= START;
                end else begin
                    // 半周期后电平变为低，说明是毛刺，重新开始检测
                    clk_cnt <= 0;
                end
            end 
            else begin
                clk_cnt <= clk_cnt + 1;
            end
        end
            end

            
            // 接收8位数据
            START: begin
                if (clk_cnt == BAUD_DIV) begin
                    clk_cnt  <= 0;
                    if(bit_flag==1'b0)begin
                    bit_buf<=data_in;
                    bit_flag<=1'b1;
                    end 
                    if(bit_flag==1'b1)begin
                    bit_flag<=1'b0;
                    if(bit_buf==1'b1)begin
                    bit_buf<=1'b0;
                    data_buf <= {1'b0, data_buf[7:1]}; 
                    end
                    if(bit_buf==1'b0)begin
                    bit_buf<=1'b0;
                    data_buf <= {1'b1, data_buf[7:1]}; 
                    end
                    end
                    if (data_cnt == 15) begin 
                        STATE    <= STOP;
                    end 
                    else begin
                        data_cnt <= data_cnt + 1;
                    end
                end 
                else begin
                    clk_cnt <= clk_cnt + 1;
                end
            end
            
            // 停止位处理
    STOP: begin
                if (clk_cnt == BAUD_DIV) begin
                    clk_cnt <= 0;
                    if (data_in == 1'b0) begin 
                        // 停止位正确
                        if (pkt_counter == 8'd254) begin
                            pkt_counter <= 8'd0;   // 包结束，计数器清零
                        end else begin
                            pkt_counter <= pkt_counter + 1; // 包内下一个字节
                        end

                        // 尝试发送当前字节
                        if (m_axis_tready) begin
                            m_axis_tdata  <= data_buf;
                            m_axis_tvalid <= 1'b1;
                            m_axis_tlast  <= (pkt_counter == 8'd254);
                        end 
                        else begin
                            // 缓存数据
                            pending_data <= data_buf;
                            has_pending  <= 1'b1;
                        end

                        // 状态转换
                        if (pkt_counter == 8'd254) begin
                            STATE <= SYNC_DETECT;
                        end else begin
                            STATE <= IDLE;
                        end
                    end 
                    else begin
                        // 停止位错误，丢弃当前字节，进入IDLE状态，保持pkt_counter不变
                        STATE <= IDLE;
                        // pkt_counter 保持不变，不增加
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