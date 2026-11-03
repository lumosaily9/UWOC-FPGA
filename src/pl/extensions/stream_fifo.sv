`timescale 1ns/1ps
// Single-clock ready/valid FIFO. DEPTH can be a non-power-of-two value.
// The read port is combinational; synthesis may use registers or distributed RAM.
module stream_fifo #(
    parameter integer WIDTH = 14,
    parameter integer DEPTH = 16,
    parameter integer PTR_WIDTH = (DEPTH <= 2) ? 1 : $clog2(DEPTH),
    parameter integer COUNT_WIDTH = (DEPTH <= 1) ? 1 : $clog2(DEPTH+1)
) (
    input  wire                   clk,
    input  wire                   rst_n,
    input  wire [WIDTH-1:0]       s_data,
    input  wire                   s_valid,
    output wire                   s_ready,
    output wire [WIDTH-1:0]       m_data,
    output wire                   m_valid,
    input  wire                   m_ready,
    output reg [COUNT_WIDTH-1:0]  level
);
    reg [WIDTH-1:0] memory [0:DEPTH-1];
    reg [PTR_WIDTH-1:0] write_ptr;
    reg [PTR_WIDTH-1:0] read_ptr;
    wire push;
    wire pop;

    assign m_valid = (level != 0);
    assign m_data = memory[read_ptr];
    assign pop = m_valid && m_ready;
    assign s_ready = (level < DEPTH) || pop;
    assign push = s_valid && s_ready;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_ptr <= 0;
            read_ptr <= 0;
            level <= 0;
        end else begin
            if (push) begin
                memory[write_ptr] <= s_data;
                if (write_ptr == DEPTH-1)
                    write_ptr <= 0;
                else
                    write_ptr <= write_ptr + 1'b1;
            end
            if (pop) begin
                if (read_ptr == DEPTH-1)
                    read_ptr <= 0;
                else
                    read_ptr <= read_ptr + 1'b1;
            end
            case ({push,pop})
                2'b10: level <= level + 1'b1;
                2'b01: level <= level - 1'b1;
                default: level <= level;
            endcase
        end
    end
endmodule
