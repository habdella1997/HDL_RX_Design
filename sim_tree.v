`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/23/2025 05:31:23 PM
// Design Name: 
// Module Name: sim_tree
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module sim_tree #(    
    parameter DATAWIDTH     = 16, // DATA WIDTH BUS
    parameter PHASES        = 16, // NUMBER OF PARALLEL PHASES
    parameter PERIODICITY   = 16, // AUTO_CORRELATION PERIODICITY (# OF SAMPLES)
    parameter INT_BITS      = 0, // USED FOR DSP INTEGER PART
    parameter FRAC_BITS     = 15, // FULL_LENGTH-WORD_LEGHT = fractional PART
    parameter ARRAY_SIZE    = (DATAWIDTH * PHASES) -1,
    parameter LOG_NUMBER    = $clog2(PHASES)

)(
     input signed [INT_BITS+FRAC_BITS:0] data_in [0:PHASES-1], 
     input clk_i,
     output signed [INT_BITS+FRAC_BITS:0] data_out
    );
    
        localparam integer LAG_SAMPLES = PERIODICITY; // IEEE802.11a = 16 
        localparam integer DELAY_WIDTH = (LAG_SAMPLES * DATAWIDTH) -1; // 16 Samples @ 16 bits => 256 BITS
        localparam integer ARRAY_MULT_WIDTH = ((DATAWIDTH) * (PERIODICITY+PHASES))-1;
        localparam integer SLICE_LEFT  = PHASES-PERIODICITY;
        localparam integer SLICE_RIGHT = SLICE_LEFT + PERIODICITY;
        
    
        wire signed [INT_BITS+FRAC_BITS:0]   summation_tree_wire [0:LOG_NUMBER][0:PHASES-1];
        reg  signed [INT_BITS+FRAC_BITS+1:0] summation_tree_reg [0:LOG_NUMBER][0:PHASES-1];
        
        genvar i;        
        genvar layer,j;
        generate
            for (i = 0; i < PHASES; i = i + 1) begin : init_level
                assign summation_tree_wire[0][i] = data_in[i];
            end
        endgenerate

        generate
            for (layer = 1; layer < LOG_NUMBER+1; layer = layer + 1) begin : tree_layers
                for (j = 0; j < PHASES >> layer; j = j + 1) begin : adder_stage
                   c_addsub_0 inst_ac_re (
                        .A(summation_tree_wire[layer-1][2*j]),
                        .B(summation_tree_wire[layer-1][2*j + 1]),
                        .CE(1'b1),  // Clock enable = 1
                        .CLK(clk_i),
                        .S(summation_tree_reg[layer][j])
                     );
                     assign summation_tree_wire[layer][j]     = summation_tree_reg[layer][j][16:1];
                end
            end
        endgenerate
    
        assign data_out = summation_tree_wire[LOG_NUMBER][0];
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
endmodule
