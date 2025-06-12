`timescale 1ns / 1ps

//goal maintain the highest & latest peak. Priority goes to latest to discover the last LTF symbol alignment


module maxDetector 
#(
    parameter DATAWIDTH     = 16, // DATA WIDTH BUS
    parameter PHASES        = 16, // NUMBER OF PARALLEL PHASES
    parameter PERIODICITY   = 16, // AUTO_CORRELATION PERIODICITY (# OF SAMPLES)
    parameter INT_BITS      = 0, // USED FOR DSP INTEGER PART
    parameter FRAC_BITS     = 15, // FULL_LENGTH-WORD_LEGHT = fractional PART
    parameter ARRAY_SIZE    = (DATAWIDTH * PHASES) -1,
    parameter CLOCKWIDTH    = 4
 )
 (
    input signed [(DATAWIDTH*2)-1 :0] max_1_p, //p -previus
    input signed [(DATAWIDTH*2)-1 :0] max_2_p, 
    input [$clog2(PHASES)-1:0] idx_1_p,
    input [$clog2(PHASES)-1:0] idx_2_p,
    input [CLOCKWIDTH      :0] clk_1_p,
    input [CLOCKWIDTH      :0] clk_2_p,
    
    input signed [(DATAWIDTH*2)-1 :0] max_1_c, // c- current
    input signed [(DATAWIDTH*2)-1 :0] max_2_c, 
    input [$clog2(PHASES)-1:0] idx_1_c,
    input [$clog2(PHASES)-1:0] idx_2_c,
    input [CLOCKWIDTH      :0] clk_1_c,
    input [CLOCKWIDTH      :0] clk_2_c,
    
    output reg signed  [(DATAWIDTH*2)-1 :0] max_1_o, // o - output
    output reg signed [(DATAWIDTH*2)-1 :0] max_2_o, 
    output reg [$clog2(PHASES)-1:0] idx_1_o,
    output reg [$clog2(PHASES)-1:0] idx_2_o,
    output reg [CLOCKWIDTH      :0] clk_1_o,
    output reg [CLOCKWIDTH      :0] clk_2_o
    );
    
    always @(*) begin
        if(max_1_c > max_1_p) begin
            max_1_o = max_1_c;
            idx_1_o = idx_1_c;
            clk_1_o = clk_1_c;
            if(max_2_c > max_1_p) begin
                max_2_o = max_2_c;
                idx_2_o = idx_2_c;
                clk_2_o = clk_2_c;
            end else begin
                max_2_o = max_1_p;
                idx_2_o = idx_1_p;
                clk_2_o = clk_1_p;
            end
        end else if (max_1_c > max_2_p) begin
            max_2_o = max_1_c;
            idx_2_o = idx_1_c;
            clk_2_o = clk_1_c;
            max_1_o = max_1_p;
            idx_1_o = idx_1_p;
            clk_1_o = clk_1_p;
        end else begin
            max_2_o = max_2_p;
            idx_2_o = idx_2_p;
            clk_2_o = clk_2_p;
            max_1_o = max_1_p;
            idx_1_o = idx_1_p;
            clk_1_o = clk_1_p;
        end
    end
    
    
endmodule
