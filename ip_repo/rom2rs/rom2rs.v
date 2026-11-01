`timescale 1ns / 1ps

module rom2rs #(
    parameter CLK_FREQ = 50_000_000     // 系统时钟频率 (默认50MHz)
)(
    input          clk,                   // 时钟 (与ROM共享)
    input          rst_n,                 // 同步复位
    
    // ROM 接口
    output reg [7:0]  rd_addr,            // ROM读取地址 (0-238)
    input   [7:0]  rd_data,               // ROM数据输出
    
    // RS编码器 AXI-Stream输出接口
    output  [7:0]  m_axis_output_tdata,   // 输出数据到RS编码器
    output         m_axis_output_tvalid,  // 数据有效标志
    output         m_axis_output_tlast,   // 帧结束标志
    input          m_axis_output_tready   // RS编码器就绪信号
);

// 控制逻辑寄存器定义
reg [7:0]   frame_count = 0;      // 帧内字节计数器 (0-238)
reg         tvalid = 0;           // 有效信号寄存器
reg         tlast = 0;            // 帧结束寄存器
reg         first_cycle = 1;      // 首次传输标志
reg         flag=0;
reg [3:0]   wait_counter = 0; 
// 输出端口连接
assign m_axis_output_tdata = rd_data;
assign m_axis_output_tvalid = tvalid;
assign m_axis_output_tlast = tlast;

// 系统参数
localparam FRAME_SIZE = 239;      // 每帧数据字节数 (固定239字节)

// 传输控制状态机
always @(posedge clk) begin
    if (!rst_n) begin
        // 复位状态
        rd_addr <= 8'd0;
        frame_count <= 0;
        tvalid <= 0;
        tlast <= 0;
        first_cycle <= 1;  // 复位后设置为首次传输
    end
    else begin
        // 关键修复：在首次传输成功前保持 tvalid=0
         if (wait_counter < 4'd10) begin
            wait_counter <= wait_counter + 1;
      
         end
            // 正常操作模式
           else if (m_axis_output_tready) begin
                // 握手成功时更新地址和计数器
                tvalid<= 1'd1;
                if (frame_count == FRAME_SIZE - 1) begin
                   flag<= 1'd1;
                    frame_count <= 0;
                    tlast <= 1'b1;            // 设置帧结束标志
                    rd_addr <= 8'd0; // 地址回到0
             
                end
          
                else begin
                if(tlast==1'd1) begin
                rd_addr<=rd_addr;
                tlast <= 1'b0; 
                end
                else begin
                    frame_count <= frame_count + 1;
                    rd_addr <= rd_addr + 8'd1; // 地址递增
                    tlast <= 1'b0;             // 清除帧结束标志
                end
                end
                 if (flag == 1'd1) begin
                     flag<= 1'd0;
                     tvalid<= 1'd0; 
                  end
            end
            else begin
            tvalid<= 1'd0;
            end
         
    end
end

endmodule