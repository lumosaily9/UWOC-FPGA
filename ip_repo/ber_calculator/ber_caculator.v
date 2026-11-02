module ber_calculator
#(
    parameter BYTE_NUM    = 239,        // 单次检测字节数
    parameter DATA_WIDTH  = 8,          // 数据位宽(字节)
    parameter ADDR_WIDTH  = 8, // ROM地址位宽(239→8位)
    parameter BE_CNT_WIDTH = 16 // 误码数位宽(239*8=1912→11位)
)
(
    input                       clk,
    input                       rst_n,
    input  [DATA_WIDTH-1:0]     s_axis_tdata,  // AXIS输入数据
    input                       s_axis_tvalid, // AXIS有效信号
    input  [DATA_WIDTH-1:0]     dinta,         // ROM输出参考数据
    output [ADDR_WIDTH-1:0]     addra,         // ROM读地址
    output [BE_CNT_WIDTH-1:0]   BEcount,       // 总误码数
    output                      s_axis_tready,  // AXIS准备信号
    output                      BEcount_valid
);
localparam [1:0] 
    IDLE        = 2'b00,    // 空闲状态
    COMPARE     = 2'b01,    // 接收数据状态
    WAIT       = 2'b10;
// 状态机定义：IDLE(等待握手)、COMPARE(逐位比较)

reg [1:0] current_state, next_state;

// 内部寄存器定义
reg [ADDR_WIDTH-1:0]  addra_reg;       // ROM地址寄存器
reg [BE_CNT_WIDTH-1:0] be_total_reg;   // 总误码数寄存器
reg [2:0]              bit_cnt;        // 字节内位计数器(0-7)
reg [ADDR_WIDTH-1:0]   byte_cnt;       // 字节计数器(0-238)
reg [DATA_WIDTH-1:0]   rx_data_reg;    // 锁存AXIS输入数据
reg [2:0]              bit_err_reg;    // 单字节误码数(0-8)
reg [2:0]              wait_cnt; 
reg[0:0]               becount_valid;
reg[0:0]              be_flag;
// 1. 时序逻辑：状态机与内部寄存器更新
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        current_state <= IDLE;
        be_flag     <= 'd0;
        addra_reg     <= 'd0;
        be_total_reg  <= 'd0;
        bit_cnt       <= 'd0;
        byte_cnt      <= 'd0;
        rx_data_reg   <= 'd0;
        bit_err_reg   <= 'd0;
        wait_cnt      <= 'd0;
        becount_valid<='d0;
    end else begin
        current_state <= next_state;
        
        case(current_state)
            // 空闲状态：等待AXIS握手，复位位计数器和单字节误码数
            IDLE: begin
            be_total_reg <= be_total_reg + bit_err_reg; 
           if(byte_cnt == BYTE_NUM ) begin
                        becount_valid<=1'b1;
                        be_flag<=1'b1;
                        byte_cnt     <= 'd0;                       // 重置字节计数
                    end else begin
                    becount_valid<=1'b0;
                    end
                bit_cnt     <= 'd0;
                bit_err_reg <= 'd0;
                // 握手成功：锁存输入数据
                if(s_axis_tvalid & s_axis_tready) begin
                    rx_data_reg <= s_axis_tdata;
                end
             
            end
            
             WAIT: begin
             if(be_flag==1'b1)begin
              be_flag<=1'b0;
              be_total_reg <= 0;
              end
              becount_valid<=1'b0;
              wait_cnt <= wait_cnt + 1'd1;
            end

            // 比较状态：逐位比较数据，统计误码
            COMPARE: begin
                wait_cnt <=1'd0;
                bit_cnt <= bit_cnt + 1'b1;  // 位计数器自增
                
                // 逐位比较：当前位不同则单字节误码数+1
                if(rx_data_reg[bit_cnt] != dinta[bit_cnt]) begin
                    bit_err_reg <= bit_err_reg + 1'b1;
                end

                // 单字节比较完成(8位)
                if(bit_cnt == 7) begin
                   // 累加总误码数
                    byte_cnt     <= byte_cnt + 1'b1;           // 字节计数器自增
                    addra_reg    <= addra_reg + 1'b1;          // ROM地址自增

                    // 完成239个字节检测
                    if(byte_cnt == BYTE_NUM - 1) begin
                        addra_reg    <= 'd0;                       // 重置ROM地址
                    end
                end
            end

            default: current_state <= IDLE;
        endcase
    end
end

// 2. 组合逻辑：状态机跳转控制
always @(*) begin
    next_state = current_state;
    case(current_state)
        IDLE: begin
            // AXIS握手成功则进入比较状态
            if(s_axis_tvalid & s_axis_tready) begin
                next_state = WAIT;
            end
        end
        
         WAIT: begin
          if(wait_cnt==1) begin
                next_state = COMPARE;
            end
        end

        COMPARE: begin
            // 单字节8位比较完成后回到空闲状态
            if(bit_cnt == 7) begin
                next_state = IDLE;
            end
        end
    endcase
end

// 3. 输出赋值
assign s_axis_tready = (current_state == IDLE) && (byte_cnt < BYTE_NUM) && (wait_cnt == 0); // 仅空闲且未完成检测时置高
assign addra        = addra_reg;                                       // ROM地址输出
assign BEcount      = be_total_reg;                                      // 总误码数输出
assign BEcount_valid = becount_valid;

endmodule