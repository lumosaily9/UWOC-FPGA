`timescale 1ns/1ps
// Continuous ADC/selector input cannot be stalled. An unaccepted pulse
// invalidates the current frame, flushes the queue, and clears FFE history.
// frame_start is asserted before the first sample of a new receive frame.
module ook_rx_guarded_fifo #(
    parameter integer WIDTH=12,
    parameter integer DEPTH=16,
    parameter integer PW=(DEPTH<=2)?1:$clog2(DEPTH),
    parameter integer CW=(DEPTH<=1)?1:$clog2(DEPTH+1)
)(input wire clk,rst_n,rx_window,frame_start,
  input wire [WIDTH-1:0] s_data,input wire s_valid,
  output wire s_ready,
  output wire [WIDTH-1:0] m_data,output wire m_valid,
  input wire m_ready,
  output reg [CW-1:0] level,
  output reg frame_overflow,
  output wire frame_abort,clear_history);
    reg [WIDTH-1:0] memory[0:DEPTH-1];
    reg [PW-1:0] write_ptr,read_ptr;
    wire accepting=rx_window&&!frame_start&&!frame_overflow;
    assign m_valid=accepting&&(level!=0);
    assign m_data=memory[read_ptr];
    wire pop=m_valid&&m_ready;
    assign s_ready=accepting&&((level<DEPTH)||pop);
    wire push=s_valid&&s_ready;
    assign frame_abort=accepting&&s_valid&&!s_ready;
    wire flush_fifo=frame_start||!rx_window||frame_abort;
    // The FFE's ready signal feeds this queue's pop/ready path. Use the
    // registered overflow flag here, never combinational frame_abort.
    assign clear_history=frame_start||!rx_window||frame_overflow;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            write_ptr<=0;read_ptr<=0;level<=0;frame_overflow<=0;
        end else begin
            if(frame_start) frame_overflow<=0;
            else if(frame_abort) frame_overflow<=1;
            if(flush_fifo) begin
                write_ptr<=0;read_ptr<=0;level<=0;
            end else begin
                if(push) begin
                    memory[write_ptr]<=s_data;
                    write_ptr<=(write_ptr==DEPTH-1)?0:write_ptr+1'b1;
                end
                if(pop) read_ptr<=(read_ptr==DEPTH-1)?0:read_ptr+1'b1;
                case({push,pop})
                    2'b10:level<=level+1'b1;
                    2'b01:level<=level-1'b1;
                    default:level<=level;
                endcase
            end
        end
    end
endmodule
