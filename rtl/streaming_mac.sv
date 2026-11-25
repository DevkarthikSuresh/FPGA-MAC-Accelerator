`timescale 1ns/1ps
// Signed dot-product engine; one accepted operand pair per clock.
// in_last marks the final pair of each dot product. No output backpressure.
module streaming_mac #(
    parameter integer DW = 8,
    parameter integer ACC_W = 32
)(
    input  wire clk,
    input  wire rst,
    input  wire in_valid,
    input  wire in_last,
    input  wire signed [DW-1:0] in_x,
    input  wire signed [DW-1:0] in_w,
    output reg out_valid,
    output reg signed [ACC_W-1:0] out_sum,
    output wire signed [ACC_W-1:0] out_relu
);
    reg signed [2*DW-1:0] product;
    reg product_valid, product_last;
    reg signed [ACC_W-1:0] acc;
    wire signed [ACC_W-1:0] extended_product = {{(ACC_W-2*DW){product[2*DW-1]}}, product};
    wire signed [ACC_W-1:0] next_sum = acc + extended_product;
    assign out_relu = out_sum[ACC_W-1] ? {ACC_W{1'b0}} : out_sum;

    // Stage 1 accepts the next pair even when stage 2 consumes the previous pair.
    always @(posedge clk) begin
        if (rst) begin
            product <= 0;
            product_valid <= 0;
            product_last <= 0;
            acc <= 0;
            out_sum <= 0;
            out_valid <= 0;
        end else begin
            product_valid <= in_valid;
            if (in_valid) begin
                product <= $signed(in_x) * $signed(in_w);
                product_last <= in_last;
            end
            out_valid <= 0;
            if (product_valid) begin
                if (product_last) begin
                    out_sum <= next_sum;
                    out_valid <= 1;
                    acc <= 0;
                end else begin
                    acc <= next_sum;
                end
            end
        end
    end
endmodule
