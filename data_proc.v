`timescale 1ns/1ps

module data_proc (

    input clk,
    input rstn,
    
    input [1:0] mode,
    input [71:0] kernel,
    
    //from producer
    input [7:0] pixel_in,
    input valid_in,
    output ready_in, // Changed to wire logic below
    
    
    //to next block whatever it is
    output reg [7:0] pixel_out,
    output reg valid_out,
    input ready_out

);
/* --------------------------------------------------------------------------
Purpose of this module : This module should perform certain operations
based on the mode register and pixel values streamed out by data_prod module.
mode[1:0]:
00 - Bypass
01 - Invert the pixel
10 - Convolution with a kernel of your choice (kernel is 3x3 2d array)
11 - Not implemented

Memory map of registers:

0x00 - Mode (2 bits)    [R/W]
0x04 - Kernel (9 * 8 = 72 bits)     [R/W]
0x10 - Status reg   [R]


----------------------------------------------------------------------------*/
reg [4:0]col_count, row_count;

// [FIX 1] Ready Handshake: Pass downstream ready upstream.
// If downstream is stuck, we stop reading.
assign ready_in = ready_out;

always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
        col_count <= 0;
        row_count <= 0;
    end else if (valid_in && ready_in) begin
        if (col_count == 31) begin
            col_count <= 0;
            row_count <= (row_count == 31) ? 0 : row_count + 1;
        end else begin
            col_count <= col_count + 1;
        end
    end
end


// [FIX 2] Line Buffers
reg [7:0] line_buffer_0 [0:31];
reg [7:0] line_buffer_1 [0:31];
reg [7:0] win [0:2][0:2];

always @(posedge clk) begin
    if (valid_in && ready_in) begin
        // 1. Shift the window columns to the left
        win[0][0] <= win[0][1]; win[0][1] <= win[0][2];
        win[1][0] <= win[1][1]; win[1][1] <= win[1][2];
        win[2][0] <= win[2][1]; win[2][1] <= win[2][2];

        // 2. FEED WINDOW: Grab data sitting in buffers RIGHT NOW
        // Because of how <= works, these are the "old" values from the previous row
        win[0][2] <= line_buffer_1[col_count]; // Data from 2 rows ago
        win[1][2] <= line_buffer_0[col_count]; // Data from 1 row ago
        win[2][2] <= pixel_in;                 // Current pixel from sensor

        // 3. UPDATE BUFFERS: These values will be available on the NEXT row
        line_buffer_1[col_count] <= line_buffer_0[col_count];
        line_buffer_0[col_count] <= pixel_in;
    end
end

// 1. Extract Kernel weights (using your slicing logic)
wire [7:0] k[0:2][0:2];
assign k[0][0] = kernel[7:0];   assign k[0][1] = kernel[15:8];   assign k[0][2] = kernel[23:16];
assign k[1][0] = kernel[31:24]; assign k[1][1] = kernel[39:32];  assign k[1][2] = kernel[47:40];
assign k[2][0] = kernel[55:48]; assign k[2][1] = kernel[63:56];  assign k[2][2] = kernel[71:64];

// 2. Generate Products (8-bit * 8-bit = 16-bit)
reg [15:0] products [0:8];

always @(posedge clk) begin
    if (valid_in && ready_in) begin
        products[0] <= win[0][0] * k[0][0];
        products[1] <= win[0][1] * k[0][1];
        products[2] <= win[0][2] * k[0][2];
        products[3] <= win[1][0] * k[1][0];
        products[4] <= win[1][1] * k[1][1];
        products[5] <= win[1][2] * k[1][2];
        products[6] <= win[2][0] * k[2][0];
        products[7] <= win[2][1] * k[2][1];
        products[8] <= win[2][2] * k[2][2];
    end
end

// 3. Accumulate and Saturate
reg [19:0] sum; // Extra bits for accumulation to prevent overflow
always @(*) begin
    sum = products[0] + products[1] + products[2] + 
          products[3] + products[4] + products[5] + 
          products[6] + products[7] + products[8];
end

// [FIX 3] Pipeline Valid Signal
// We need to delay the valid signal to match the pipeline depth
// Stage 1: Window Load, Stage 2: Product Calc, Stage 3: Output Reg
reg valid_pipe_1, valid_pipe_2; 

always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
        {valid_pipe_2, valid_pipe_1} <= 2'b0;
    end else if (ready_out) begin
        // Only generate valid if we have enough rows for convolution
        valid_pipe_1 <= valid_in && ((row_count > 1) || (row_count == 2 && col_count >= 2));
        valid_pipe_2 <= valid_pipe_1;
    end
end


// Output logic and Mode selection
always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
        pixel_out <= 8'h00;
        valid_out <= 1'b0;
    end else if (ready_out) begin // Only update if downstream is ready
        case (mode)
            2'b00: begin // Bypass
                pixel_out <= pixel_in;
                valid_out <= valid_in;
            end
            
            2'b01: begin // Invert
                pixel_out <= ~pixel_in;
                valid_out <= valid_in;
            end
            
            2'b10: begin // Convolution
                // Saturate the 20-bit sum to 8-bit
                if (sum > 20'd255) 
                    pixel_out <= 8'hFF;
                else 
                    pixel_out <= sum[7:0];
                
                // [FIX 3] Use pipelined valid
                valid_out <= valid_pipe_2; 
            end
            
            default: begin
                pixel_out <= 8'h00;
                valid_out <= 1'b0;
            end
        endcase
    end
end

// Status Register Logic (Address 0x10)
reg frame_done;
always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
        frame_done <= 1'b0;
    end else if (row_count == 31 && col_count == 31 && valid_in && ready_in) begin
        frame_done <= 1'b1;
        // Pulses high for the last pixel
    end else begin
        frame_done <= 1'b0;
    end
end

endmodule