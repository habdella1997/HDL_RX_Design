`timescale 1ns / 1ps

module ssr_sort_2 // Returns the two max values. 
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
    input                              clk_i,
    input                              rst_i,
    input  [(DATAWIDTH*2)*PHASES -1:0] crossCorrelator_i,
    output [OUTBITS-1:0]               index_max_o,
    output signed [(DATAWIDTH*2)-1:0]  value_max_o,
    output [OUTBITS-1:0]               index_max2_o,
    output signed [(DATAWIDTH*2)-1:0]  value_max2_o
    );
    localparam integer LAYERS = $clog2(PHASES);
    localparam integer VAL_WIDTH = DATAWIDTH*2;
    
    wire signed [VAL_WIDTH-1:0] max_1w  [0:LAYERS] [0:PHASES-1];
    reg  signed [VAL_WIDTH-1:0] max_1r  [0:LAYERS] [0:PHASES-1];
    wire [OUTBITS-1:0]   idx_1w  [0:LAYERS] [0:PHASES-1];
    reg  [OUTBITS-1:0]   idx_1r  [0:LAYERS] [0:PHASES-1];
    
    wire signed [VAL_WIDTH-1:0] max_2w  [0:LAYERS] [0:PHASES-1];
    reg  signed [VAL_WIDTH-1:0] max_2r  [0:LAYERS] [0:PHASES-1];
    wire [OUTBITS-1:0]   idx_2w  [0:LAYERS] [0:PHASES-1];
    reg  [OUTBITS-1:0]   idx_2r  [0:LAYERS] [0:PHASES-1];
    
    
    
    genvar i;
    generate
        for(i=0;i<PHASES;i=i+1) begin
            assign max_1w[0][i] = crossCorrelator_i[(i+1)*VAL_WIDTH -1 -: VAL_WIDTH];
            assign idx_1w[0][i] = i;
            assign max_2w[0][i] = 0;
            assign idx_2w[0][i] = i;
        end
    endgenerate
    
    genvar layer, j;
    generate
        for(layer = 1; layer < LAYERS+1; layer=layer+1)begin
            for(j=0; j<PHASES>>layer; j = j+1) begin
                wire signed [VAL_WIDTH-1:0] m1_v1, m1_v2, m2_v1, m2_v2;
                wire [OUTBITS  -1:0] m1_i1, m1_i2, m2_i1, m2_i2;
                assign m1_v1 = max_1w[layer-1][2*j]; assign m1_v2 = max_1w[layer-1][2*j+1];
                assign m1_i1 = idx_1w[layer-1][2*j]; assign m1_i2 = idx_1w[layer-1][2*j+1];
                assign m2_v1 = max_2w[layer-1][2*j]; assign m2_v2 = max_2w[layer-1][2*j+1];
                assign m2_i1 = idx_2w[layer-1][2*j]; assign m2_i2 = idx_2w[layer-1][2*j+1];
                always @ (posedge clk_i) begin
                    if(m1_v1 >= m1_v2) begin
                        max_1r[layer][j] <= m1_v1; idx_1r[layer][j] <= m1_i1;
                        if(m2_v1 >= m2_v2) begin
                            max_2r[layer][j] <= (m2_v1 >= m1_v2) ? m2_v1:m1_v2;
                            idx_2r[layer][j] <= (m2_v1 >= m1_v2) ? m2_i1:m1_i2;
                        end else begin
                            max_2r[layer][j] <= (m2_v2 >= m1_v2) ? m2_v2:m1_v2;
                            idx_2r[layer][j] <= (m2_v2 >= m1_v2) ? m2_i2:m1_i2;
                        end
                    end else begin
                        max_1r[layer][j] <= m1_v2; idx_1r[layer][j] <= m1_i2;
                        if(m2_v1 >= m2_v2) begin
                            max_2r[layer][j] <= (m2_v1 >= m1_v1) ? m2_v1:m1_v1;
                            idx_2r[layer][j] <= (m2_v1 >= m1_v1) ? m2_i1:m1_i1;
                        end else begin
                            max_2r[layer][j] <= (m2_v2 >= m1_v1) ? m2_v2:m1_v1;
                            idx_2r[layer][j] <= (m2_v2 >= m1_v1) ? m2_i2:m1_i1;
                        end
                    end
                
                end
                assign max_1w [layer][j] = max_1r[layer][j];
                assign idx_1w [layer][j] = idx_1r[layer][j];
                assign max_2w [layer][j] = max_2r[layer][j];
                assign idx_2w [layer][j] = idx_2r[layer][j];
            end
        end
    endgenerate
    
    assign index_max_o  = idx_1w[LAYERS][0];
    assign value_max_o  = max_1w[LAYERS][0];
    assign index_max2_o = idx_2w[LAYERS][0];
    assign value_max2_o = max_2w[LAYERS][0];
    
    
endmodule
