`timescale 1ns/1ps

module tb_data_prod_proc;

    reg clk = 0;
    reg sensor_clk = 0;
    
    // 100MHz Processing Clock
    always #5 clk = ~clk;

    // 200MHz Sensor Clock
    always #2.5 sensor_clk = ~sensor_clk;

    reg [5:0] reset_cnt = 0;
    wire resetn = &reset_cnt;

    always @(posedge clk) begin
        if (!resetn)
            reset_cnt <= reset_cnt + 1'b1;
    end

    reg [5:0] sensor_reset_cnt = 0;
    wire sensor_resetn = &sensor_reset_cnt;

    always @(posedge sensor_clk) begin
        if (!sensor_resetn)
            sensor_reset_cnt <= sensor_reset_cnt + 1'b1;
    end

    // --- FILE WRITING SETUP ---
    integer f; // File descriptor
    
    // Configuration Signals
    reg [1:0]  tb_mode;
    reg [71:0] tb_kernel;
    reg        tb_ready_out;

    // Outputs from Top Wrapper
    wire [7:0] final_pixel;
    wire       final_valid;

    // Instantiate Top Wrapper
    data_top dut (
        .clk(clk),
        .sensor_clk(sensor_clk),
        .rstn(resetn),
        .sensor_rstn(sensor_resetn),
        .mode(tb_mode),
        .kernel(tb_kernel),
        .pixel_out(final_pixel),
        .valid_out(final_valid),
        .ready_out(tb_ready_out)
    );

    // --- CAPTURE LOGIC ---
   always @(posedge clk) begin
        // Only write when in Convolution Mode (Mode 2)
        if (final_valid && tb_mode == 2'b10) begin
            $fwrite(f, "%h\n", final_pixel);
        end
    end

    initial begin
        // [FIX] Use ABSOLUTE PATH to avoid permission errors
        // Make sure this folder exists!
        f = $fopen("D:/Verilog/iris_q2/output_image.txt", "w"); 

        // Initialize Signals
        tb_mode = 2'b00;      // Start in Bypass
        tb_kernel = 72'h0;
        tb_ready_out = 1'b1;  // Consumer always ready

        // Wait for resets
        wait(resetn && sensor_resetn);
        repeat(10) @(posedge clk);

        // --- Test Sequence ---
        
        // 1. Bypass
       /* $display("Testing Bypass Mode...");
        tb_mode = 2'b00;
        repeat(100) @(posedge clk);

        // 2. Invert
        $display("Testing Invert Mode...");
        tb_mode = 2'b01;
        repeat(100) @(posedge clk);*/

        // 3. Convolution
        $display("Testing Convolution Mode...");
        tb_kernel = {8'h0, 8'h0, 8'h0, 8'h0, 8'h01, 8'h0, 8'h0, 8'h0, 8'h0};
        tb_mode = 2'b10;
        
        // Run simulation
        repeat(10000) @(posedge clk);

        // Close File
        $display("Closing file and finishing...");
        $fclose(f);
        $finish;
    end

endmodule