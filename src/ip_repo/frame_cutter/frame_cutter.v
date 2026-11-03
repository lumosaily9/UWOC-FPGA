`timescale 1ns / 1ps

// Extract 239 information bytes from a 255-byte decoded RS codeword.
module frame_cutter (
    input wire clk,
    input wire resetn,
    input wire [7:0] s_axis_input_tdata,
    input wire s_axis_input_tvalid,
    output wire s_axis_input_tready,
    output reg [7:0] m_axis_output_tdata,
    output reg m_axis_output_tvalid,
    input wire m_axis_output_tready,
    output reg m_axis_output_tlast
);
    reg [7:0] byte_counter;
    wire discard_byte = byte_counter >= 8'd239;
    wire output_available = !m_axis_output_tvalid || m_axis_output_tready;
    assign s_axis_input_tready = resetn && (discard_byte || output_available);
    wire input_transfer = s_axis_input_tvalid && s_axis_input_tready;
    always @(posedge clk) begin
        if (!resetn) begin
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
                if (!discard_byte) begin
                    m_axis_output_tdata <= s_axis_input_tdata;
                    m_axis_output_tvalid <= 1'b1;
                    m_axis_output_tlast <= byte_counter == 8'd238;
                end
                if (byte_counter == 8'd254) byte_counter <= 8'd0;
                else byte_counter <= byte_counter + 1'b1;
            end
        end
    end
endmodule
