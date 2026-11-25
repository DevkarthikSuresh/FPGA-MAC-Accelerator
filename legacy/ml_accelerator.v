`timescale 1ns / 1ps
// Recovered 2025 RTL, reformatted from the author's archived message.
module ml_accelerator #(
    parameter N = 3, parameter DW = 8
)(
    input clk, input rst, input start, input we,
    input [1:0] sel, input [1:0] waddr, input [DW-1:0] wdata,
    output reg done, output reg [6:0] seg_out, output reg [3:0] anode_en
);
    localparam ADDR_WIDTH = $clog2(N);
    localparam D_ACC_WIDTH = 32;
    localparam S_IDLE = 2'b00, S_PRODUCT = 2'b01,
               S_ACCUMULATE = 2'b10, S_FINISH = 2'b11;
    reg signed [DW-1:0] input_mem [0:N-1];
    reg signed [DW-1:0] weight_mem [0:N-1];
    reg signed [D_ACC_WIDTH-1:0] temp_acc, product_reg;
    reg [ADDR_WIDTH-1:0] mac_index;
    reg [1:0] state;
    reg [3:0] result;
    always @(posedge clk) begin
        if (we) begin
            case (sel)
                2'b00: input_mem[waddr] <= wdata;
                2'b01: weight_mem[waddr] <= wdata;
            endcase
        end
    end
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= S_IDLE; mac_index <= 0; temp_acc <= 0;
            product_reg <= 0; result <= 0; done <= 0;
        end else begin
            done <= 0;
            case (state)
                S_IDLE: if (start) begin
                    state <= S_PRODUCT; mac_index <= 0; temp_acc <= 0;
                end
                S_PRODUCT: begin
                    product_reg <= input_mem[mac_index] * weight_mem[mac_index];
                    state <= S_ACCUMULATE;
                end
                S_ACCUMULATE: begin
                    temp_acc <= temp_acc + product_reg;
                    if (mac_index == N - 1) begin
                        state <= S_FINISH; mac_index <= 0;
                    end else begin
                        mac_index <= mac_index + 1; state <= S_PRODUCT;
                    end
                end
                S_FINISH: begin
                    if (temp_acc < 0) result <= 0;
                    else result <= temp_acc[3:0];
                    done <= 1; state <= S_IDLE;
                end
                default: state <= S_IDLE;
            endcase
        end
    end
    always @(*) begin
        case (result)
            4'd0: seg_out = 7'b1000000;
            4'd1: seg_out = 7'b1111001;
            4'd2: seg_out = 7'b0100100;
            4'd3: seg_out = 7'b0110000;
            4'd4: seg_out = 7'b0011001;
            4'd5: seg_out = 7'b0010010;
            4'd6: seg_out = 7'b0000010;
            4'd7: seg_out = 7'b1111000;
            4'd8: seg_out = 7'b0000000;
            4'd9: seg_out = 7'b0010000;
            default: seg_out = 7'b1111111;
        endcase
    end
    // Original constant combinational block retained for provenance; see README.
    always @(*) begin
        anode_en = 4'b1110;
    end
endmodule
