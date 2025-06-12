`timescale 1ns / 1ps

module multq0_15#
(    
    parameter DATAWIDTH     = 16, // DATA WIDTH BUS
    parameter INT_BITS      = 0, // USED FOR DSP INTEGER PART
    parameter FRAC_BITS     = 15 // FULL_LENGTH-WORD_LEGHT = fractional PART
)(
    input clk_i, 
    input [DATAWIDTH-1:0] a_i,
    input [DATAWIDTH-1:0] b_i,
    output [15:0] c_o
    );
    
    wire [31:0] mult_out;
    assign c_o = (mult_out >>> 15);
    // Instantiate the Multiplier IP core
    mult_gen_0 mult_inst (
        .CLK (clk_i),   // clock input
        .A   (a_i),     // 16-bit signed input A
        .B   (b_i),     // 16-bit signed input B
        .P   (mult_out)      // 32-bit signed output product
    );
        
endmodule
