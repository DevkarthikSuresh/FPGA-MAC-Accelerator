`timescale 1ns/1ps
module tb_streaming_mac;
    reg clk=0, rst=1, in_valid=0, in_last=0;
    reg signed [7:0] in_x=0, in_w=0;
    wire out_valid;
    wire signed [31:0] out_sum, out_relu;
    streaming_mac dut(.*);
    always #5 clk=~clk;
    integer running=0, pending_sum=0, checks=0;
    reg pending=0;
    // Scoreboard tracks transactions and checks the exact one-cycle delay
    // from the final input sampling edge to its output sampling edge.
    always @(posedge clk) begin
        #1;
        if (rst) begin
            if (out_valid !== 1'b0) $fatal(1,"out_valid during reset");
            running=0; pending=0; pending_sum=0;
        end else begin
            if (out_valid !== pending) $fatal(1,"unexpected output valid");
            if (pending) begin
                if ($signed(out_sum) !== pending_sum) $fatal(1,"sum got %0d expected %0d",out_sum,pending_sum);
                if ($signed(out_relu) !== ((pending_sum<0)?0:pending_sum)) $fatal(1,"ReLU mismatch");
                checks=checks+1;
            end
            pending=0;
            if (in_valid) begin
                running=running+$signed(in_x)*$signed(in_w);
                if (in_last) begin
                    pending=1; pending_sum=running; running=0;
                end
            end
        end
    end
    task send(input integer x, input integer w, input bit last);
        begin @(negedge clk); in_valid=1; in_x=x; in_w=w; in_last=last; end
    endtask
    task bubble;
        begin @(negedge clk); in_valid=0; in_last=0; end
    endtask
    integer i,j,a,b;
    initial begin
        $dumpfile("streaming_mac.vcd"); $dumpvars(0,tb_streaming_mac);
        repeat(2) @(negedge clk); rst=0;
        send(2,3,0); send(-4,2,0); send(5,2,1); // 8
        send(-128,127,1); // negative, contiguous with preceding vector
        send(-128,-128,1); // positive signed extreme
        send(3,4,0); bubble(); send(2,-8,1); // -4, with bubble
        for(i=0;i<784;i=i+1) send(127,127,i==783);
        for(i=0;i<784;i=i+1) send(-128,127,i==783);
        for(j=0;j<20;j=j+1) begin
            for(i=0;i<11;i=i+1) begin
                a=$urandom_range(0,255)-128; b=$urandom_range(0,255)-128;
                send(a,b,i==10);
                if(i==3) bubble();
            end
        end
        // A reset cancels an incomplete dot product.
        send(12,10,0); bubble(); @(negedge clk); rst=1;
        repeat(2) @(negedge clk); rst=0;
        send(1,7,1); bubble(); bubble();
        if(checks != 27) $fatal(1,"wrong number of checked vectors: %0d",checks);
        $display("PASS: %0d dot products",checks); $finish;
    end
endmodule
