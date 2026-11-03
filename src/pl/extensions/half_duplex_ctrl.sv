`timescale 1ns/1ps
// Local time-slot scheduler. Peer devices need a shared schedule or negotiation.
// All cycle counts are positive integers in the clk domain.
module half_duplex_ctrl #(
    parameter integer TX_CYCLES = 16,
    parameter integer RX_CYCLES = 16,
    parameter integer GUARD_CYCLES = 4,
    parameter integer START_WITH_TX = 1
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       enable,
    output wire       tx_enable,
    output wire       rx_enable,
    output wire       guard_active,
    output reg [1:0]  state,
    output reg        slot_start
);
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] TX = 2'd1;
    localparam [1:0] GUARD = 2'd2;
    localparam [1:0] RX = 2'd3;
    localparam integer MAX_TR = (TX_CYCLES > RX_CYCLES) ? TX_CYCLES : RX_CYCLES;
    localparam integer MAX_COUNT = (MAX_TR > GUARD_CYCLES) ? MAX_TR : GUARD_CYCLES;
    localparam integer COUNT_WIDTH = (MAX_COUNT <= 1) ? 1 : $clog2(MAX_COUNT);
    reg [COUNT_WIDTH-1:0] count;
    reg next_is_rx;

    assign tx_enable = enable && (state == TX);
    assign rx_enable = enable && (state == RX);
    assign guard_active = enable && (state == GUARD);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            count <= 0;
            next_is_rx <= 1'b1;
            slot_start <= 1'b0;
        end else if (!enable) begin
            state <= IDLE;
            count <= 0;
            next_is_rx <= 1'b1;
            slot_start <= 1'b0;
        end else begin
            slot_start <= 1'b0;
            case (state)
                IDLE: begin
                    state <= START_WITH_TX ? TX : RX;
                    count <= 0;
                    slot_start <= 1'b1;
                end
                TX: begin
                    if (count == TX_CYCLES-1) begin
                        state <= GUARD;
                        next_is_rx <= 1'b1;
                        count <= 0;
                    end else count <= count + 1'b1;
                end
                GUARD: begin
                    if (count == GUARD_CYCLES-1) begin
                        state <= next_is_rx ? RX : TX;
                        count <= 0;
                        slot_start <= 1'b1;
                    end else count <= count + 1'b1;
                end
                RX: begin
                    if (count == RX_CYCLES-1) begin
                        state <= GUARD;
                        next_is_rx <= 1'b0;
                        count <= 0;
                    end else count <= count + 1'b1;
                end
                default: begin
                    state <= IDLE;
                    count <= 0;
                end
            endcase
        end
    end
endmodule
