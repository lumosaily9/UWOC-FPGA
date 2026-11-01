module fifo_count (
    input wire clk,
    input wire rst_n,
    input wire [31:0] fifo_count,       // FIFO 数据计数（假设 16 位宽度）
    input wire s_axis_input_tready,    // 输入 AXIS 就绪信号
    output wire m_axis_output_tready   // 输出 AXIS 就绪信号
);

// 内部寄存器定义
reg [5:0] cycle_counter;              // 50 周期计数器（0-49）
reg inner_ready;                      // 内部就绪信号
reg [31:0] fifo_count_sampled;        // 同步采样的 FIFO 计数值

// 周期计数器逻辑
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        cycle_counter <= 6'd0;
    end else begin
        if (cycle_counter == 6'd49) begin
            cycle_counter <= 6'd0;     // 达到 50 个周期时重置
        end else begin
            cycle_counter <= cycle_counter + 6'd1;
        end
    end
end

// FIFO 计数采样逻辑（在周期 0 采样）
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        fifo_count_sampled <= 16'd0;
    end else if (cycle_counter == 6'd0) begin
        fifo_count_sampled <= fifo_count;  // 每 50 个周期采样一次
    end
end

// 内部 ready 信号控制逻辑
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        inner_ready <= 1'b1;           // 复位时 ready 为高
    end else if (cycle_counter == 6'd0) begin
        // 在采样周期检查 FIFO 计数
        if (fifo_count_sampled > 16'd3400) begin
            inner_ready <= 1'b0;       // 超过阈值立即拉低
        end else begin
            inner_ready <= 1'b1;       // 低于阈值保持/恢复高电平
        end
    end
    // 注意：inner_ready 在其他周期保持当前值
end

// 输出就绪信号组合逻辑
assign m_axis_output_tready = s_axis_input_tready && inner_ready;

endmodule