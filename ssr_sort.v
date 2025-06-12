`timescale 1ns / 1ps

module ssr_sort
 #(
    parameter DATAWIDTH     = 16, // DATA WIDTH BUS
    parameter PHASES        = 64, // NUMBER OF PARALLEL PHASES
    parameter PERIODICITY   = 16, // AUTO_CORRELATION PERIODICITY (# OF SAMPLES)
    parameter INT_BITS      = 0, // USED FOR DSP INTEGER PART
    parameter FRAC_BITS     = 15, // FULL_LENGTH-WORD_LEGHT = fractional PART
    parameter ARRAY_SIZE    = (DATAWIDTH * PHASES) -1,
    parameter LTF_SIZE      = 64,
    parameter OUTBITS       = $clog2(PHASES)
 )
 (
    input                   clk_i,
    input                   rst_i,
    input  [(DATAWIDTH*2)*PHASES -1:0] crossCorrelator_i,
    output [OUTBITS-1:0]              index_max_o,
    output [(DATAWIDTH*2)-1:0]        value_max_o
    );
    localparam integer LAYERS = $clog2(PHASES);
    localparam integer VAL_WIDTH = DATAWIDTH*2;
    
    wire [VAL_WIDTH-1:0] crossCorrelator_SSR_tree_wire [0:LAYERS] [0:PHASES-1];
    reg  [VAL_WIDTH-1:0] crossCorrelator_SSR_tree_reg  [0:LAYERS] [0:PHASES-1];
    wire [OUTBITS-1:0]   index_SSR_tree_wire           [0:LAYERS] [0:PHASES-1];
    reg [OUTBITS-1:0]   index_SSR_tree_reg            [0:LAYERS] [0:PHASES-1];
    
    genvar i;
    generate
        for(i=0;i<PHASES;i=i+1) begin
            assign crossCorrelator_SSR_tree_wire[0][i] = crossCorrelator_i[(i+1)*VAL_WIDTH -1 -: VAL_WIDTH];
            assign index_SSR_tree_wire[0][i]           = i;
        end
    endgenerate
    
    genvar layer, j;
    generate
        for(layer = 1; layer < LAYERS+1; layer=layer+1)begin
            for(j=0; j<PHASES>>layer; j = j+1) begin
                always @ (posedge clk_i) begin
                    crossCorrelator_SSR_tree_reg[layer][j] <= (crossCorrelator_SSR_tree_wire[layer-1][2*j] > 
                                                               crossCorrelator_SSR_tree_wire[layer-1][2*j+1])  ?
                                                                crossCorrelator_SSR_tree_wire[layer-1][2*j]:
                                                                crossCorrelator_SSR_tree_wire[layer-1][2*j+1];
                    index_SSR_tree_reg[layer][j]           <= (crossCorrelator_SSR_tree_wire[layer-1][2*j] >
                                                               crossCorrelator_SSR_tree_wire[layer-1][2*j+1]) ? 
                                                               index_SSR_tree_wire[layer-1][2*j]:
                                                               index_SSR_tree_wire[layer-1][2*j+1];                                          
                end
                assign crossCorrelator_SSR_tree_wire[layer][j] = crossCorrelator_SSR_tree_reg[layer][j];
                assign index_SSR_tree_wire[layer][j]           = index_SSR_tree_reg[layer][j];
            end
        end
    endgenerate
    
    assign index_max_o = index_SSR_tree_wire[LAYERS][0];
    assign value_max_o = crossCorrelator_SSR_tree_wire[LAYERS][0];
    
endmodule
