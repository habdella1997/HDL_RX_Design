`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/28/2025 02:12:29 PM
// Design Name: 
// Module Name: cross_correlation
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
//  LATENCY = 9 clock cycles 
//              6 for addition, 1 for add/sub, 1 for mult, and 1 for final summation
//////////////////////////////////////////////////////////////////////////////////


module cross_correlation#(
    parameter DATAWIDTH     = 16, // DATA WIDTH BUS
    parameter PHASES        = 16, // NUMBER OF PARALLEL PHASES
    parameter PERIODICITY   = 16, // AUTO_CORRELATION PERIODICITY (# OF SAMPLES)
    parameter INT_BITS      = 0, // USED FOR DSP INTEGER PART
    parameter FRAC_BITS     = 15, // FULL_LENGTH-WORD_LEGHT = fractional PART
    parameter ARRAY_SIZE    = (DATAWIDTH * PHASES) -1,
    parameter LTF_SIZE      = 64
 )
 (
    input [LTF_SIZE*DATAWIDTH-1:0] re_i,
    input [LTF_SIZE*DATAWIDTH-1:0] im_i ,
    input                   clk_i,
    input                   rst_i,
    output signed [(DATAWIDTH*2)-1:0]           magnitude_out
    );
    
    localparam integer LOG_NUMBER = $clog2(LTF_SIZE);
    localparam integer BITRED  = 8;
    localparam integer TREESIZE = (PHASES+PHASES)-1;
//    localparam logic [63:0] LTF_RE = 64'b11000011_00011011_10001101_11001111_00100011_00000001_10110000_00010010;
//    localparam logic [63:0] LTF_IM = 64'b11011110_01110011_11000111_10111111_01011101_11111111_10100100_00100000;
     
  
    wire signed [DATAWIDTH-1:0] cross_correlated_samples_ac_wire [0:LTF_SIZE-1];
    wire signed [DATAWIDTH-1:0] cross_correlated_samples_bd_wire [0:LTF_SIZE-1];
    wire signed [DATAWIDTH-1:0] cross_correlated_samples_ad_wire [0:LTF_SIZE-1];
    wire signed [DATAWIDTH-1:0] cross_correlated_samples_bc_wire [0:LTF_SIZE-1];
    
    genvar  i;
    generate 
        for(i=0;i<LTF_SIZE;i++)begin // X[n] * H[-n] where H[n] are the known LTF Sequence. 
            assign cross_correlated_samples_ac_wire[i] = (LTF_SEQUENCE_SIGN_RE[i] == 1'b0) ? re_i[(i+1)*DATAWIDTH-1 -: DATAWIDTH] : -re_i[(i+1)*DATAWIDTH-1 -: DATAWIDTH];
            assign cross_correlated_samples_bd_wire[i] = (LTF_SEQUENCE_SIGN_IM[i] == 1'b0) ? im_i[(i+1)*DATAWIDTH-1 -: DATAWIDTH] : -im_i[(i+1)*DATAWIDTH-1 -: DATAWIDTH];
            assign cross_correlated_samples_ad_wire[i] = (LTF_SEQUENCE_SIGN_IM[i] == 1'b0) ? re_i[(i+1)*DATAWIDTH-1 -: DATAWIDTH] : -re_i[(i+1)*DATAWIDTH-1 -: DATAWIDTH];
            assign cross_correlated_samples_bc_wire[i] = (LTF_SEQUENCE_SIGN_RE[i] == 1'b0) ? im_i[(i+1)*DATAWIDTH-1 -: DATAWIDTH] : -im_i[(i+1)*DATAWIDTH-1 -: DATAWIDTH];
        end
    endgenerate

    
    wire signed [BITRED-1:0]   summation_tree_ac_wire [0:TREESIZE-1];
    reg  signed [BITRED:0] summation_tree_ac_reg  [0:TREESIZE-1];
    wire signed [BITRED-1:0]   summation_tree_bd_wire [0:TREESIZE-1];
    reg  signed [BITRED:0] summation_tree_bd_reg  [0:TREESIZE-1];
    wire signed [BITRED-1:0]   summation_tree_ad_wire [0:TREESIZE-1];
    reg  signed [BITRED:0] summation_tree_ad_reg  [0:TREESIZE-1];
    wire signed [BITRED-1:0]   summation_tree_bc_wire [0:TREESIZE-1];
    reg  signed [BITRED:0] summation_tree_bc_reg  [0:TREESIZE-1];
    
    function automatic int get_offset(input int layer);
        case (layer)
            0: get_offset = 0;
            1: get_offset = 64;
            2: get_offset = 96;
            3: get_offset = 112;
            4: get_offset = 120;
            5: get_offset = 124;
            6: get_offset = 126;
            7: get_offset = 127;
            default: get_offset = 0;
        endcase
    endfunction
        
    genvar m;        
    genvar layer,j;
    generate
        for (m = 0; m < LTF_SIZE; m = m + 1) begin : init_level
            assign summation_tree_ac_wire[m] = cross_correlated_samples_ac_wire[m][15 -: BITRED];
            assign summation_tree_bd_wire[m] = cross_correlated_samples_bd_wire[m][15 -: BITRED];
            assign summation_tree_ad_wire[m] = cross_correlated_samples_ad_wire[m][15 -: BITRED];
            assign summation_tree_bc_wire[m] = cross_correlated_samples_bc_wire[m][15 -: BITRED];
        end
    endgenerate

    generate
        for (layer = 1; layer < LOG_NUMBER+1; layer = layer + 1) begin : tree_layers // 1-clock cylce latency per layer. 
            for (j = 0; j < LTF_SIZE >> layer; j = j + 1) begin : adder_stage
                always @ (posedge clk_i) begin
                    summation_tree_ac_reg[get_offset(layer)+j] <= summation_tree_ac_wire[get_offset(layer-1) + (2*j)] + summation_tree_ac_wire[get_offset(layer-1) + (2*j+1)];
                end
           
                assign summation_tree_ac_wire[get_offset(layer)+j]     = summation_tree_ac_reg[get_offset(layer)+j][BITRED : 1];
                always @ (posedge clk_i) begin
                    summation_tree_bd_reg[get_offset(layer)+j] <= summation_tree_bd_wire[get_offset(layer-1) + (2*j)] + summation_tree_bd_wire[get_offset(layer-1) + (2*j+1)];
                end
                assign summation_tree_bd_wire[get_offset(layer)+j]     = summation_tree_bd_reg[get_offset(layer)+j][BITRED : 1];
                always @ (posedge clk_i) begin
                    summation_tree_ad_reg[get_offset(layer)+j] <= summation_tree_ad_wire[get_offset(layer-1) + (2*j)] + summation_tree_ad_wire[get_offset(layer-1) + (2*j+1)];
                end
                assign summation_tree_ad_wire[get_offset(layer)+j]     = summation_tree_ad_reg[get_offset(layer)+j][BITRED : 1];
                always @ (posedge clk_i) begin
                    summation_tree_bc_reg[get_offset(layer)+j] <= summation_tree_bc_wire[get_offset(layer-1) + (2*j)] + summation_tree_bc_wire[get_offset(layer-1) + (2*j+1)];
                end
                assign summation_tree_bc_wire[get_offset(layer)+j]     = summation_tree_bc_reg[get_offset(layer)+j][BITRED : 1];
                 
            end
        end
    endgenerate
    //Q0.15 -> (summation) -> Q1.14 (truncte by 1) -> Q1.13
    //Q0.15 -> (Summation+Truncation x6) -> Q6.9 (16 bits total). 
    //LATENCY = 1clock per layer = 6 clock cycles to finish summing up the 64 samples. 
    wire signed [INT_BITS+FRAC_BITS:0] AC, BD, AD, BC;
    assign AC = {summation_tree_ac_wire[TREESIZE-1], 8'b00000000} ; // Q6.9
    assign BD = {summation_tree_bd_wire[TREESIZE-1], 8'b00000000} ; // Q6.9
    assign AD = {summation_tree_ad_wire[TREESIZE-1], 8'b00000000} ; // Q6.9
    assign BC = {summation_tree_bc_wire[TREESIZE-1], 8'b00000000} ; // Q6.9
    
    reg signed [INT_BITS+FRAC_BITS+1:0] AC_BD, AD_BC;
    reg signed [(INT_BITS+FRAC_BITS+2)*2:0] re_squared, im_squared;
    reg signed [((INT_BITS+FRAC_BITS+2)*2)+1:0] magnitude;
    
    (* use_dsp = "yes" *)
    always @ (posedge clk_i)begin
        AC_BD <= AC - BD;  // Q6.9 - Q6.9 = Q7.9
        AD_BC <= AD + BC;
        re_squared <= AC_BD * AC_BD; // Q7.9 * Q7.9 = Q15.18 (34bits)
        im_squared <= AD_BC * AD_BC; // Q7.9 * Q7.9 = Q15.18
        magnitude  <= (re_squared + im_squared) <<< 5; // Q15.18 + Q15.18= Q16.18 <<< 5 = Q11.23
    end
    assign magnitude_out = magnitude[35:4];//Q11.23 -> drop 4 bits -> Q11.19
                                    
      reg [63:0] LTF_SEQUENCE_SIGN_RE; 
      reg [63:0] LTF_SEQUENCE_SIGN_IM; 
initial begin
        LTF_SEQUENCE_SIGN_RE[0] = 1'b1;
        LTF_SEQUENCE_SIGN_IM[0] = 1'b1;
        LTF_SEQUENCE_SIGN_RE[1] = 1'b0;
        LTF_SEQUENCE_SIGN_IM[1] = 1'b1;
        LTF_SEQUENCE_SIGN_RE[2] = 1'b0;
        LTF_SEQUENCE_SIGN_IM[2] = 1'b0;
        LTF_SEQUENCE_SIGN_RE[3] = 1'b0;
        LTF_SEQUENCE_SIGN_IM[3] = 1'b0;
        LTF_SEQUENCE_SIGN_RE[4] = 1'b0;
        LTF_SEQUENCE_SIGN_IM[4] = 1'b1;
        LTF_SEQUENCE_SIGN_RE[5] = 1'b1;
        LTF_SEQUENCE_SIGN_IM[5] = 1'b1;
        LTF_SEQUENCE_SIGN_RE[6] = 1'b1;
        LTF_SEQUENCE_SIGN_IM[6] = 1'b1;
        LTF_SEQUENCE_SIGN_RE[7] = 1'b0;
        LTF_SEQUENCE_SIGN_IM[7] = 1'b1;
        LTF_SEQUENCE_SIGN_RE[8] = 1'b0;
        LTF_SEQUENCE_SIGN_IM[8] = 1'b0;
        LTF_SEQUENCE_SIGN_RE[9] = 1'b0;
        LTF_SEQUENCE_SIGN_IM[9] = 1'b1;
        LTF_SEQUENCE_SIGN_RE[10] = 1'b1;
        LTF_SEQUENCE_SIGN_IM[10] = 1'b1;
        LTF_SEQUENCE_SIGN_RE[11] = 1'b0;
        LTF_SEQUENCE_SIGN_IM[11] = 1'b1;
        LTF_SEQUENCE_SIGN_RE[12] = 1'b0;
        LTF_SEQUENCE_SIGN_IM[12] = 1'b1;
        LTF_SEQUENCE_SIGN_RE[13] = 1'b1;
        LTF_SEQUENCE_SIGN_IM[13] = 1'b0;
        LTF_SEQUENCE_SIGN_RE[14] = 1'b0;
        LTF_SEQUENCE_SIGN_IM[14] = 1'b1;
        LTF_SEQUENCE_SIGN_RE[15] = 1'b0;
        LTF_SEQUENCE_SIGN_IM[15] = 1'b1;
        LTF_SEQUENCE_SIGN_RE[16] = 1'b0;
        LTF_SEQUENCE_SIGN_IM[16] = 1'b0;
        LTF_SEQUENCE_SIGN_RE[17] = 1'b1;
        LTF_SEQUENCE_SIGN_IM[17] = 1'b0;
        LTF_SEQUENCE_SIGN_RE[18] = 1'b1;
        LTF_SEQUENCE_SIGN_IM[18] = 1'b0;
        LTF_SEQUENCE_SIGN_RE[19] = 1'b0;
        LTF_SEQUENCE_SIGN_IM[19] = 1'b0;
        LTF_SEQUENCE_SIGN_RE[20] = 1'b0;
        LTF_SEQUENCE_SIGN_IM[20] = 1'b0;
        LTF_SEQUENCE_SIGN_RE[21] = 1'b1;
        LTF_SEQUENCE_SIGN_IM[21] = 1'b0;
        LTF_SEQUENCE_SIGN_RE[22] = 1'b1;
        LTF_SEQUENCE_SIGN_IM[22] = 1'b1;
        LTF_SEQUENCE_SIGN_RE[23] = 1'b1;
        LTF_SEQUENCE_SIGN_IM[23] = 1'b1;
        LTF_SEQUENCE_SIGN_RE[24] = 1'b1;
        LTF_SEQUENCE_SIGN_IM[24] = 1'b1;
        LTF_SEQUENCE_SIGN_RE[25] = 1'b1;
        LTF_SEQUENCE_SIGN_IM[25] = 1'b1;
        LTF_SEQUENCE_SIGN_RE[26] = 1'b0;
        LTF_SEQUENCE_SIGN_IM[26] = 1'b1;
        LTF_SEQUENCE_SIGN_RE[27] = 1'b1;
        LTF_SEQUENCE_SIGN_IM[27] = 1'b0;
        LTF_SEQUENCE_SIGN_RE[28] = 1'b1;
        LTF_SEQUENCE_SIGN_IM[28] = 1'b0;
        LTF_SEQUENCE_SIGN_RE[29] = 1'b0;
        LTF_SEQUENCE_SIGN_IM[29] = 1'b0;
        LTF_SEQUENCE_SIGN_RE[30] = 1'b0;
        LTF_SEQUENCE_SIGN_IM[30] = 1'b0;
        LTF_SEQUENCE_SIGN_RE[31] = 1'b1;
        LTF_SEQUENCE_SIGN_IM[31] = 1'b0;
        LTF_SEQUENCE_SIGN_RE[32] = 1'b0;
        LTF_SEQUENCE_SIGN_IM[32] = 1'b1;
        LTF_SEQUENCE_SIGN_RE[33] = 1'b0;
        LTF_SEQUENCE_SIGN_IM[33] = 1'b1;
        LTF_SEQUENCE_SIGN_RE[34] = 1'b1;
        LTF_SEQUENCE_SIGN_IM[34] = 1'b1;
        LTF_SEQUENCE_SIGN_RE[35] = 1'b1;
        LTF_SEQUENCE_SIGN_IM[35] = 1'b1;
        LTF_SEQUENCE_SIGN_RE[36] = 1'b0;
        LTF_SEQUENCE_SIGN_IM[36] = 1'b0;
        LTF_SEQUENCE_SIGN_RE[37] = 1'b1;
        LTF_SEQUENCE_SIGN_IM[37] = 1'b0;
        LTF_SEQUENCE_SIGN_RE[38] = 1'b1;
        LTF_SEQUENCE_SIGN_IM[38] = 1'b0;
        LTF_SEQUENCE_SIGN_RE[39] = 1'b1;
        LTF_SEQUENCE_SIGN_IM[39] = 1'b0;
        LTF_SEQUENCE_SIGN_RE[40] = 1'b1;
        LTF_SEQUENCE_SIGN_IM[40] = 1'b0;
        LTF_SEQUENCE_SIGN_RE[41] = 1'b1;
        LTF_SEQUENCE_SIGN_IM[41] = 1'b1;
        LTF_SEQUENCE_SIGN_RE[42] = 1'b0;
        LTF_SEQUENCE_SIGN_IM[42] = 1'b1;
        LTF_SEQUENCE_SIGN_RE[43] = 1'b0;
        LTF_SEQUENCE_SIGN_IM[43] = 1'b1;
        LTF_SEQUENCE_SIGN_RE[44] = 1'b1;
        LTF_SEQUENCE_SIGN_IM[44] = 1'b1;
        LTF_SEQUENCE_SIGN_RE[45] = 1'b1;
        LTF_SEQUENCE_SIGN_IM[45] = 1'b1;
        LTF_SEQUENCE_SIGN_RE[46] = 1'b0;
        LTF_SEQUENCE_SIGN_IM[46] = 1'b1;
        LTF_SEQUENCE_SIGN_RE[47] = 1'b0;
        LTF_SEQUENCE_SIGN_IM[47] = 1'b0;
        LTF_SEQUENCE_SIGN_RE[48] = 1'b0;
        LTF_SEQUENCE_SIGN_IM[48] = 1'b0;
        LTF_SEQUENCE_SIGN_RE[49] = 1'b1;
        LTF_SEQUENCE_SIGN_IM[49] = 1'b1;
        LTF_SEQUENCE_SIGN_RE[50] = 1'b0;
        LTF_SEQUENCE_SIGN_IM[50] = 1'b0;
        LTF_SEQUENCE_SIGN_RE[51] = 1'b0;
        LTF_SEQUENCE_SIGN_IM[51] = 1'b0;
        LTF_SEQUENCE_SIGN_RE[52] = 1'b1;
        LTF_SEQUENCE_SIGN_IM[52] = 1'b0;
        LTF_SEQUENCE_SIGN_RE[53] = 1'b0;
        LTF_SEQUENCE_SIGN_IM[53] = 1'b0;
        LTF_SEQUENCE_SIGN_RE[54] = 1'b0;
        LTF_SEQUENCE_SIGN_IM[54] = 1'b1;
        LTF_SEQUENCE_SIGN_RE[55] = 1'b0;
        LTF_SEQUENCE_SIGN_IM[55] = 1'b0;
        LTF_SEQUENCE_SIGN_RE[56] = 1'b1;
        LTF_SEQUENCE_SIGN_IM[56] = 1'b0;
        LTF_SEQUENCE_SIGN_RE[57] = 1'b1;
        LTF_SEQUENCE_SIGN_IM[57] = 1'b0;
        LTF_SEQUENCE_SIGN_RE[58] = 1'b0;
        LTF_SEQUENCE_SIGN_IM[58] = 1'b0;
        LTF_SEQUENCE_SIGN_RE[59] = 1'b0;
        LTF_SEQUENCE_SIGN_IM[59] = 1'b1;
        LTF_SEQUENCE_SIGN_RE[60] = 1'b0;
        LTF_SEQUENCE_SIGN_IM[60] = 1'b1;
        LTF_SEQUENCE_SIGN_RE[61] = 1'b0;
        LTF_SEQUENCE_SIGN_IM[61] = 1'b0;
        LTF_SEQUENCE_SIGN_RE[62] = 1'b1;
        LTF_SEQUENCE_SIGN_IM[62] = 1'b0;
        LTF_SEQUENCE_SIGN_RE[63] = 1'b0;
        LTF_SEQUENCE_SIGN_IM[63] = 1'b0;
    end

endmodule
















/*`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/28/2025 02:12:29 PM
// Design Name: 
// Module Name: cross_correlation
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
//  LATENCY = 9 clock cycles 
//              6 for addition, 1 for add/sub, 1 for mult, and 1 for final summation
//////////////////////////////////////////////////////////////////////////////////


module cross_correlation#(
    parameter DATAWIDTH     = 16, // DATA WIDTH BUS
    parameter PHASES        = 16, // NUMBER OF PARALLEL PHASES
    parameter PERIODICITY   = 16, // AUTO_CORRELATION PERIODICITY (# OF SAMPLES)
    parameter INT_BITS      = 0, // USED FOR DSP INTEGER PART
    parameter FRAC_BITS     = 15, // FULL_LENGTH-WORD_LEGHT = fractional PART
    parameter ARRAY_SIZE    = (DATAWIDTH * PHASES) -1,
    parameter LTF_SIZE      = 64
 )
 (
    input [LTF_SIZE*DATAWIDTH-1:0] re_i,
    input [LTF_SIZE*DATAWIDTH-1:0] im_i ,
    input                   clk_i,
    input                   rst_i,
    output signed [(DATAWIDTH*2)-1:0]           magnitude_out
    );
    
    localparam integer LOG_NUMBER = $clog2(LTF_SIZE);
    localparam integer BITRED  = 8;
    localparam integer TREESIZE = (PHASES+PHASES)-1;
//    localparam logic [63:0] LTF_RE = 64'b11000011_00011011_10001101_11001111_00100011_00000001_10110000_00010010;
//    localparam logic [63:0] LTF_IM = 64'b11011110_01110011_11000111_10111111_01011101_11111111_10100100_00100000;
     
  
    wire signed [DATAWIDTH-1:0] cross_correlated_samples_ac_wire [0:LTF_SIZE-1];
    wire signed [DATAWIDTH-1:0] cross_correlated_samples_bd_wire [0:LTF_SIZE-1];
    wire signed [DATAWIDTH-1:0] cross_correlated_samples_ad_wire [0:LTF_SIZE-1];
    wire signed [DATAWIDTH-1:0] cross_correlated_samples_bc_wire [0:LTF_SIZE-1];
    
    genvar  i;
    generate 
        for(i=0;i<LTF_SIZE;i++)begin // X[n] * H[-n] where H[n] are the known LTF Sequence. 
            assign cross_correlated_samples_ac_wire[i] = (LTF_SEQUENCE_SIGN_RE[i] == 1'b0) ? re_i[(i+1)*DATAWIDTH-1 -: DATAWIDTH] : -re_i[(i+1)*DATAWIDTH-1 -: DATAWIDTH];
            assign cross_correlated_samples_bd_wire[i] = (LTF_SEQUENCE_SIGN_IM[i] == 1'b0) ? im_i[(i+1)*DATAWIDTH-1 -: DATAWIDTH] : -im_i[(i+1)*DATAWIDTH-1 -: DATAWIDTH];
            assign cross_correlated_samples_ad_wire[i] = (LTF_SEQUENCE_SIGN_IM[i] == 1'b0) ? re_i[(i+1)*DATAWIDTH-1 -: DATAWIDTH] : -re_i[(i+1)*DATAWIDTH-1 -: DATAWIDTH];
            assign cross_correlated_samples_bc_wire[i] = (LTF_SEQUENCE_SIGN_RE[i] == 1'b0) ? im_i[(i+1)*DATAWIDTH-1 -: DATAWIDTH] : -im_i[(i+1)*DATAWIDTH-1 -: DATAWIDTH];
        end
    endgenerate

    
    wire signed [BITRED-1:0]   summation_tree_ac_wire [0:TREESIZE-1];
    reg  signed [BITRED:0] summation_tree_ac_reg  [0:TREESIZE-1];
    wire signed [BITRED-1:0]   summation_tree_bd_wire [0:TREESIZE-1];
    reg  signed [BITRED:0] summation_tree_bd_reg  [0:TREESIZE-1];
    wire signed [BITRED-1:0]   summation_tree_ad_wire [0:TREESIZE-1];
    reg  signed [BITRED:0] summation_tree_ad_reg  [0:TREESIZE-1];
    wire signed [BITRED-1:0]   summation_tree_bc_wire [0:TREESIZE-1];
    reg  signed [BITRED:0] summation_tree_bc_reg  [0:TREESIZE-1];
    
    function automatic int get_offset(input int layer);
        case (layer)
            0: get_offset = 0;
            1: get_offset = 64;
            2: get_offset = 96;
            3: get_offset = 112;
            4: get_offset = 120;
            5: get_offset = 124;
            6: get_offset = 126;
            7: get_offset = 127;
            default: get_offset = 0;
        endcase
    endfunction
        
    genvar m;        
    genvar layer,j;
    generate
        for (m = 0; m < LTF_SIZE; m = m + 1) begin : init_level
            assign summation_tree_ac_wire[m] = cross_correlated_samples_ac_wire[m][15 -: BITRED];
            assign summation_tree_bd_wire[m] = cross_correlated_samples_bd_wire[m][15 -: BITRED];
            assign summation_tree_ad_wire[m] = cross_correlated_samples_ad_wire[m][15 -: BITRED];
            assign summation_tree_bc_wire[m] = cross_correlated_samples_bc_wire[m][15 -: BITRED];
        end
    endgenerate

    generate
        for (layer = 1; layer < LOG_NUMBER+1; layer = layer + 1) begin : tree_layers // 1-clock cylce latency per layer. 
            for (j = 0; j < LTF_SIZE >> layer; j = j + 1) begin : adder_stage
               c_addsub_0 inst_ac(
                    .A(summation_tree_ac_wire[layer-1][2*j]),
                    .B(summation_tree_ac_wire[layer-1][2*j + 1]),
                    .CE(1'b1),  // Clock enable = 1
                    .CLK(clk_i),
                    .S(summation_tree_ac_reg[layer][j])
                 );
                 assign summation_tree_ac_wire[layer][j]     = summation_tree_ac_reg[layer][j][16:1];
                 
                c_addsub_0 inst_bd(
                    .A(summation_tree_bd_wire[layer-1][2*j]),
                    .B(summation_tree_bd_wire[layer-1][2*j + 1]),
                    .CE(1'b1),  // Clock enable = 1
                    .CLK(clk_i),
                    .S(summation_tree_bd_reg[layer][j])
                 );
                 assign summation_tree_bd_wire[layer][j]     = summation_tree_bd_reg[layer][j][16:1];
                 
                 c_addsub_0 inst_ad(
                    .A(summation_tree_ad_wire[layer-1][2*j]),
                    .B(summation_tree_ad_wire[layer-1][2*j + 1]),
                    .CE(1'b1),  // Clock enable = 1
                    .CLK(clk_i),
                    .S(summation_tree_ad_reg[layer][j])
                 );
                 assign summation_tree_ad_wire[layer][j]     = summation_tree_ad_reg[layer][j][16:1];
                 
                 c_addsub_0 inst_bc(
                    .A(summation_tree_bc_wire[layer-1][2*j]),
                    .B(summation_tree_bc_wire[layer-1][2*j + 1]),
                    .CE(1'b1),  // Clock enable = 1
                    .CLK(clk_i),
                    .S(summation_tree_bc_reg[layer][j])
                 );
                 assign summation_tree_bc_wire[layer][j]     = summation_tree_bc_reg[layer][j][16:1];
            end
        end
    endgenerate
    //Q0.15 -> (summation) -> Q1.14 (truncte by 1) -> Q1.13
    //Q0.15 -> (Summation+Truncation x6) -> Q6.9 (16 bits total). 
    //LATENCY = 1clock per layer = 6 clock cycles to finish summing up the 64 samples. 
    wire signed [INT_BITS+FRAC_BITS:0] AC, BD, AD, BC;
    assign AC = summation_tree_ac_wire[LOG_NUMBER][0]; // Q6.9
    assign BD = summation_tree_bd_wire[LOG_NUMBER][0]; // Q6.9
    assign AD = summation_tree_ad_wire[LOG_NUMBER][0]; // Q6.9
    assign BC = summation_tree_bc_wire[LOG_NUMBER][0]; // Q6.9
    
    reg signed [INT_BITS+FRAC_BITS+1:0] AC_BD, AD_BC;
    reg signed [(INT_BITS+FRAC_BITS+2)*2:0] re_squared, im_squared;
    reg signed [((INT_BITS+FRAC_BITS+2)*2)+1:0] magnitude;
    
    (* use_dsp = "yes" *)
    always @ (posedge clk_i)begin
        AC_BD <= AC - BD;  // Q6.9 - Q6.9 = Q7.9
        AD_BC <= AD + BC;
        re_squared <= AC_BD * AC_BD; // Q7.9 * Q7.9 = Q15.18 (34bits)
        im_squared <= AD_BC * AD_BC; // Q7.9 * Q7.9 = Q15.18
        magnitude  <= (re_squared + im_squared) <<< 5; // Q15.18 + Q15.18= Q16.18 <<< 5 = Q11.23
    end
    assign magnitude_out = magnitude[35:4];//Q11.23 -> drop 4 bits -> Q11.19
                                    
      reg [63:0] LTF_SEQUENCE_SIGN_RE; 
      reg [63:0] LTF_SEQUENCE_SIGN_IM; 
initial begin
        LTF_SEQUENCE_SIGN_RE[0] = 1'b1;
        LTF_SEQUENCE_SIGN_IM[0] = 1'b1;
        LTF_SEQUENCE_SIGN_RE[1] = 1'b0;
        LTF_SEQUENCE_SIGN_IM[1] = 1'b1;
        LTF_SEQUENCE_SIGN_RE[2] = 1'b0;
        LTF_SEQUENCE_SIGN_IM[2] = 1'b0;
        LTF_SEQUENCE_SIGN_RE[3] = 1'b0;
        LTF_SEQUENCE_SIGN_IM[3] = 1'b0;
        LTF_SEQUENCE_SIGN_RE[4] = 1'b0;
        LTF_SEQUENCE_SIGN_IM[4] = 1'b1;
        LTF_SEQUENCE_SIGN_RE[5] = 1'b1;
        LTF_SEQUENCE_SIGN_IM[5] = 1'b1;
        LTF_SEQUENCE_SIGN_RE[6] = 1'b1;
        LTF_SEQUENCE_SIGN_IM[6] = 1'b1;
        LTF_SEQUENCE_SIGN_RE[7] = 1'b0;
        LTF_SEQUENCE_SIGN_IM[7] = 1'b1;
        LTF_SEQUENCE_SIGN_RE[8] = 1'b0;
        LTF_SEQUENCE_SIGN_IM[8] = 1'b0;
        LTF_SEQUENCE_SIGN_RE[9] = 1'b0;
        LTF_SEQUENCE_SIGN_IM[9] = 1'b1;
        LTF_SEQUENCE_SIGN_RE[10] = 1'b1;
        LTF_SEQUENCE_SIGN_IM[10] = 1'b1;
        LTF_SEQUENCE_SIGN_RE[11] = 1'b0;
        LTF_SEQUENCE_SIGN_IM[11] = 1'b1;
        LTF_SEQUENCE_SIGN_RE[12] = 1'b0;
        LTF_SEQUENCE_SIGN_IM[12] = 1'b1;
        LTF_SEQUENCE_SIGN_RE[13] = 1'b1;
        LTF_SEQUENCE_SIGN_IM[13] = 1'b0;
        LTF_SEQUENCE_SIGN_RE[14] = 1'b0;
        LTF_SEQUENCE_SIGN_IM[14] = 1'b1;
        LTF_SEQUENCE_SIGN_RE[15] = 1'b0;
        LTF_SEQUENCE_SIGN_IM[15] = 1'b1;
        LTF_SEQUENCE_SIGN_RE[16] = 1'b0;
        LTF_SEQUENCE_SIGN_IM[16] = 1'b0;
        LTF_SEQUENCE_SIGN_RE[17] = 1'b1;
        LTF_SEQUENCE_SIGN_IM[17] = 1'b0;
        LTF_SEQUENCE_SIGN_RE[18] = 1'b1;
        LTF_SEQUENCE_SIGN_IM[18] = 1'b0;
        LTF_SEQUENCE_SIGN_RE[19] = 1'b0;
        LTF_SEQUENCE_SIGN_IM[19] = 1'b0;
        LTF_SEQUENCE_SIGN_RE[20] = 1'b0;
        LTF_SEQUENCE_SIGN_IM[20] = 1'b0;
        LTF_SEQUENCE_SIGN_RE[21] = 1'b1;
        LTF_SEQUENCE_SIGN_IM[21] = 1'b0;
        LTF_SEQUENCE_SIGN_RE[22] = 1'b1;
        LTF_SEQUENCE_SIGN_IM[22] = 1'b1;
        LTF_SEQUENCE_SIGN_RE[23] = 1'b1;
        LTF_SEQUENCE_SIGN_IM[23] = 1'b1;
        LTF_SEQUENCE_SIGN_RE[24] = 1'b1;
        LTF_SEQUENCE_SIGN_IM[24] = 1'b1;
        LTF_SEQUENCE_SIGN_RE[25] = 1'b1;
        LTF_SEQUENCE_SIGN_IM[25] = 1'b1;
        LTF_SEQUENCE_SIGN_RE[26] = 1'b0;
        LTF_SEQUENCE_SIGN_IM[26] = 1'b1;
        LTF_SEQUENCE_SIGN_RE[27] = 1'b1;
        LTF_SEQUENCE_SIGN_IM[27] = 1'b0;
        LTF_SEQUENCE_SIGN_RE[28] = 1'b1;
        LTF_SEQUENCE_SIGN_IM[28] = 1'b0;
        LTF_SEQUENCE_SIGN_RE[29] = 1'b0;
        LTF_SEQUENCE_SIGN_IM[29] = 1'b0;
        LTF_SEQUENCE_SIGN_RE[30] = 1'b0;
        LTF_SEQUENCE_SIGN_IM[30] = 1'b0;
        LTF_SEQUENCE_SIGN_RE[31] = 1'b1;
        LTF_SEQUENCE_SIGN_IM[31] = 1'b0;
        LTF_SEQUENCE_SIGN_RE[32] = 1'b0;
        LTF_SEQUENCE_SIGN_IM[32] = 1'b1;
        LTF_SEQUENCE_SIGN_RE[33] = 1'b0;
        LTF_SEQUENCE_SIGN_IM[33] = 1'b1;
        LTF_SEQUENCE_SIGN_RE[34] = 1'b1;
        LTF_SEQUENCE_SIGN_IM[34] = 1'b1;
        LTF_SEQUENCE_SIGN_RE[35] = 1'b1;
        LTF_SEQUENCE_SIGN_IM[35] = 1'b1;
        LTF_SEQUENCE_SIGN_RE[36] = 1'b0;
        LTF_SEQUENCE_SIGN_IM[36] = 1'b0;
        LTF_SEQUENCE_SIGN_RE[37] = 1'b1;
        LTF_SEQUENCE_SIGN_IM[37] = 1'b0;
        LTF_SEQUENCE_SIGN_RE[38] = 1'b1;
        LTF_SEQUENCE_SIGN_IM[38] = 1'b0;
        LTF_SEQUENCE_SIGN_RE[39] = 1'b1;
        LTF_SEQUENCE_SIGN_IM[39] = 1'b0;
        LTF_SEQUENCE_SIGN_RE[40] = 1'b1;
        LTF_SEQUENCE_SIGN_IM[40] = 1'b0;
        LTF_SEQUENCE_SIGN_RE[41] = 1'b1;
        LTF_SEQUENCE_SIGN_IM[41] = 1'b1;
        LTF_SEQUENCE_SIGN_RE[42] = 1'b0;
        LTF_SEQUENCE_SIGN_IM[42] = 1'b1;
        LTF_SEQUENCE_SIGN_RE[43] = 1'b0;
        LTF_SEQUENCE_SIGN_IM[43] = 1'b1;
        LTF_SEQUENCE_SIGN_RE[44] = 1'b1;
        LTF_SEQUENCE_SIGN_IM[44] = 1'b1;
        LTF_SEQUENCE_SIGN_RE[45] = 1'b1;
        LTF_SEQUENCE_SIGN_IM[45] = 1'b1;
        LTF_SEQUENCE_SIGN_RE[46] = 1'b0;
        LTF_SEQUENCE_SIGN_IM[46] = 1'b1;
        LTF_SEQUENCE_SIGN_RE[47] = 1'b0;
        LTF_SEQUENCE_SIGN_IM[47] = 1'b0;
        LTF_SEQUENCE_SIGN_RE[48] = 1'b0;
        LTF_SEQUENCE_SIGN_IM[48] = 1'b0;
        LTF_SEQUENCE_SIGN_RE[49] = 1'b1;
        LTF_SEQUENCE_SIGN_IM[49] = 1'b1;
        LTF_SEQUENCE_SIGN_RE[50] = 1'b0;
        LTF_SEQUENCE_SIGN_IM[50] = 1'b0;
        LTF_SEQUENCE_SIGN_RE[51] = 1'b0;
        LTF_SEQUENCE_SIGN_IM[51] = 1'b0;
        LTF_SEQUENCE_SIGN_RE[52] = 1'b1;
        LTF_SEQUENCE_SIGN_IM[52] = 1'b0;
        LTF_SEQUENCE_SIGN_RE[53] = 1'b0;
        LTF_SEQUENCE_SIGN_IM[53] = 1'b0;
        LTF_SEQUENCE_SIGN_RE[54] = 1'b0;
        LTF_SEQUENCE_SIGN_IM[54] = 1'b1;
        LTF_SEQUENCE_SIGN_RE[55] = 1'b0;
        LTF_SEQUENCE_SIGN_IM[55] = 1'b0;
        LTF_SEQUENCE_SIGN_RE[56] = 1'b1;
        LTF_SEQUENCE_SIGN_IM[56] = 1'b0;
        LTF_SEQUENCE_SIGN_RE[57] = 1'b1;
        LTF_SEQUENCE_SIGN_IM[57] = 1'b0;
        LTF_SEQUENCE_SIGN_RE[58] = 1'b0;
        LTF_SEQUENCE_SIGN_IM[58] = 1'b0;
        LTF_SEQUENCE_SIGN_RE[59] = 1'b0;
        LTF_SEQUENCE_SIGN_IM[59] = 1'b1;
        LTF_SEQUENCE_SIGN_RE[60] = 1'b0;
        LTF_SEQUENCE_SIGN_IM[60] = 1'b1;
        LTF_SEQUENCE_SIGN_RE[61] = 1'b0;
        LTF_SEQUENCE_SIGN_IM[61] = 1'b0;
        LTF_SEQUENCE_SIGN_RE[62] = 1'b1;
        LTF_SEQUENCE_SIGN_IM[62] = 1'b0;
        LTF_SEQUENCE_SIGN_RE[63] = 1'b0;
        LTF_SEQUENCE_SIGN_IM[63] = 1'b0;
    end

endmodule

























*/








