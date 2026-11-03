`timescale 1ns / 1ps

// Register a 255-byte RS input codeword and retain AXIS data during stalls.
module frame_cutter1 (
    input wire clk,
    input wire resetn,
    input wire [7:0] s_axis_input_tdata,
    input wire s_axis_input_tvalid,
    input wire s_axis_input_tlast,
    output wire s_axis_input_tready,
    output wire [1:0] STATE,
    output reg [7:0] m_axis_output_tdata,
    output reg m_axis_output_tvalid,
    input wire m_axis_output_tready,
    output reg m_axis_output_tlast
);
    localparam IDLE = 2'b00;
    localparam TRANSFER = 2'b01;
    localparam DISCARD = 2'b10;
    reg [1:0] state;
    reg [7:0] byte_counter;
    wire output_available = !m_axis_output_tvalid || m_axis_output_tready;
    assign s_axis_input_tready = resetn && ((state == DISCARD) || output_available);
    assign STATE = state;
    wire input_transfer = s_axis_input_tvalid && s_axis_input_tready;
    always @(posedge clk) begin
        if (!resetn) begin
            state <= IDLE;
            byte_counter <= 8'd0;
            m_axis_output_tdata <= 8'd0;
            m_axis_output_tvalid <= 1'b0;
            m_axis_output_tlast <= 1'b0;
        end else begin
            if (m_axis_output_tvalid && m_axis_output_tready) begin
                m_axis_output_tvalid <= 1'b0;
                m_axis_output_tlast <= 1'b0;
            end
            if (input_transfer) begin
                if (state == DISCARD) begin
                    if (s_axis_input_tlast) begin
                        state <= IDLE;
                        byte_counter <= 8'd0;
                    end
                end else begin
                    m_axis_output_tdata <= s_axis_input_tdata;
                    m_axis_output_tvalid <= 1'b1;
                    m_axis_output_tlast <= byte_counter == 8'd254;
                    if (byte_counter == 8'd254) begin
                        byte_counter <= 8'd0;
                        state <= s_axis_input_tlast ? IDLE : DISCARD;
                    end else begin
                        byte_counter <= byte_counter + 1'b1;
                        state <= TRANSFER;
                    end
                end
            end
        end
    end
endmodule
