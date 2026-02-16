`timescale 1ns/1ps

module async_fifo #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 6 // [FIX] Increased to 64 depth (2^6) to prevent overflow
)(
    // Write Domain (Producer)
    input                    wclk,
    input                    wrst_n,
    input                    w_en,
    input  [DATA_WIDTH-1:0]  wdata,
    output                   full,

    // Read Domain (Processor)
    input                    rclk,
    input                    rrst_n,
    input                    r_en,
    output [DATA_WIDTH-1:0]  rdata,
    output                   empty
);

    reg [DATA_WIDTH-1:0] mem [0:(1<<ADDR_WIDTH)-1];
    reg [ADDR_WIDTH:0] wptr_bin, rptr_bin;
    wire [ADDR_WIDTH:0] wptr_gray, rptr_gray;
    reg [ADDR_WIDTH:0] wptr_gray_sync1, wptr_gray_sync2;
    reg [ADDR_WIDTH:0] rptr_gray_sync1, rptr_gray_sync2;

    // --- Write Domain Logic ---
    always @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n) begin
            wptr_bin <= 0;
        end else if (w_en && !full) begin
            mem[wptr_bin[ADDR_WIDTH-1:0]] <= wdata;
            wptr_bin <= wptr_bin + 1;
        end
    end

    assign wptr_gray = (wptr_bin >> 1) ^ wptr_bin;

    // --- Read Domain Logic ---
    always @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) begin
            rptr_bin <= 0;
        end else if (r_en && !empty) begin
            rptr_bin <= rptr_bin + 1;
        end
    end
    
    assign rdata = mem[rptr_bin[ADDR_WIDTH-1:0]];
    assign rptr_gray = (rptr_bin >> 1) ^ rptr_bin;

    // --- 2-FF Synchronizers (The CDC Bridge) ---
    always @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) {wptr_gray_sync2, wptr_gray_sync1} <= 0;
        else         {wptr_gray_sync2, wptr_gray_sync1} <= {wptr_gray_sync1, wptr_gray};
    end

    always @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n) {rptr_gray_sync2, rptr_gray_sync1} <= 0;
        else         {rptr_gray_sync2, rptr_gray_sync1} <= {rptr_gray_sync1, rptr_gray};
    end

    // --- Status Flags ---
    assign empty = (rptr_gray == wptr_gray_sync2);
    assign full  = (wptr_gray == {~rptr_gray_sync2[ADDR_WIDTH:ADDR_WIDTH-1], rptr_gray_sync2[ADDR_WIDTH-2:0]});

endmodule