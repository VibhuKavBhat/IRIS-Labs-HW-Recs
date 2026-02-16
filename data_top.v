module data_top (
    input clk,             // 100MHz Processing Clock
    input sensor_clk,      // 200MHz Sensor Clock
    input rstn,            // System Reset
    input sensor_rstn,     // Sensor Reset
    
    // Config Registers (from Memory Map)
    input [1:0]  mode,
    input [71:0] kernel,
    
    // Output Stream
    output [7:0] pixel_out,
    output       valid_out,
    input        ready_out
);

    // Internal Signal Interconnects
    wire [7:0] prod_pixel;
    wire       prod_valid;
    wire       prod_ready;
    
    wire [7:0] fifo_pixel;
    wire       fifo_empty;
    wire       fifo_full;
    wire       proc_ready_in;

    // 1. Data Producer (Sensor Domain)
    data_producer #(
        .IMAGE_SIZE(1024)
    ) producer_inst (
        .sensor_clk(sensor_clk),
        .rst_n(sensor_rstn),
        .ready(prod_ready),    // Connected to FIFO full status
        .pixel(prod_pixel),
        .valid(prod_valid)
    );

    // 2. Async FIFO (The Bridge)
    // Translates data from 200MHz sensor_clk to 100MHz clk
    async_fifo #(
        .DATA_WIDTH(8),
        .ADDR_WIDTH(6)
    ) fifo_inst (
        .wclk(sensor_clk),
        .wrst_n(sensor_rstn),
        .w_en(prod_valid),
        .wdata(prod_pixel),
        .full(fifo_full),      // Drives producer's ready

        .rclk(clk),
        .rrst_n(rstn),
        .r_en(proc_ready_in && !fifo_empty), // Only read if proc is ready and data exists
        .rdata(fifo_pixel),
        .empty(fifo_empty)
    );

    // Bridge logic for Producer Ready
    assign prod_ready = !fifo_full;

    // 3. Data Processing Block (Processing Domain)
    data_proc processor_inst (
        .clk(clk),
        .rstn(rstn),
        .mode(mode),
        .kernel(kernel),
        .pixel_in(fifo_pixel),
        .valid_in(!fifo_empty), // Valid when FIFO has data
        .ready_in(proc_ready_in),
        .pixel_out(pixel_out),
        .valid_out(valid_out),
        .ready_out(ready_out)
    );

endmodule