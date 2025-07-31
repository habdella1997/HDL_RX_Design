//`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////////
//// Company: 
//// Engineer: 
//// 
//// Create Date: 05/23/2025 05:31:23 PM
//// Design Name: 
//// Module Name: sim_tree
//// Project Name: 
//// Target Devices: 
//// Tool Versions: 
//// Description: 
//// 
//// Dependencies: 
//// 
//// Revision:
//// Revision 0.01 - File Created
//// Additional Comments:
//// 
////////////////////////////////////////////////////////////////////////////////////


//module sim_tree #(    
//    parameter DATAWIDTH     = 16, // DATA WIDTH BUS
//    parameter PHASES        = 16, // NUMBER OF PARALLEL PHASES
//    parameter PERIODICITY   = 16, // AUTO_CORRELATION PERIODICITY (# OF SAMPLES)
//    parameter INT_BITS      = 0, // USED FOR DSP INTEGER PART
//    parameter FRAC_BITS     = 15, // FULL_LENGTH-WORD_LEGHT = fractional PART
//    parameter ARRAY_SIZE    = (DATAWIDTH * PHASES) -1,
//    parameter LOG_NUMBER    = $clog2(PHASES)

//)(
//     input signed [INT_BITS+FRAC_BITS:0] data_in [0:PHASES-1], 
//     input clk_i,
//     output signed [INT_BITS+FRAC_BITS:0] data_out
//    );
    
//        localparam integer LAG_SAMPLES = PERIODICITY; // IEEE802.11a = 16 
//        localparam integer DELAY_WIDTH = (LAG_SAMPLES * DATAWIDTH) -1; // 16 Samples @ 16 bits => 256 BITS
//        localparam integer ARRAY_MULT_WIDTH = ((DATAWIDTH) * (PERIODICITY+PHASES))-1;
//        localparam integer SLICE_LEFT  = PHASES-PERIODICITY;
//        localparam integer SLICE_RIGHT = SLICE_LEFT + PERIODICITY;
        
    
//        wire signed [INT_BITS+FRAC_BITS:0]   summation_tree_wire [0:LOG_NUMBER][0:PHASES-1];
//        reg  signed [INT_BITS+FRAC_BITS+1:0] summation_tree_reg [0:LOG_NUMBER][0:PHASES-1];
        
//        genvar i;        
//        genvar layer,j;
//        generate
//            for (i = 0; i < PHASES; i = i + 1) begin : init_level
//                assign summation_tree_wire[0][i] = data_in[i];
//            end
//        endgenerate

//        generate
//            for (layer = 1; layer < LOG_NUMBER+1; layer = layer + 1) begin : tree_layers
//                for (j = 0; j < PHASES >> layer; j = j + 1) begin : adder_stage
//                   c_addsub_0 inst_ac_re (
//                        .A(summation_tree_wire[layer-1][2*j]),
//                        .B(summation_tree_wire[layer-1][2*j + 1]),
//                        .CE(1'b1),  // Clock enable = 1
//                        .CLK(clk_i),
//                        .S(summation_tree_reg[layer][j])
//                     );
//                     assign summation_tree_wire[layer][j]     = summation_tree_reg[layer][j][16:1];
//                end
//            end
//        endgenerate
    
//        assign data_out = summation_tree_wire[LOG_NUMBER][0];
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
//endmodule


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
        localparam integer TREESIZE    = (PHASES + PHASES) - 1;    
        
        localparam integer BITRED = 13; //Dropping to 8 BITS;
    
        wire signed [BITRED-1:0]     summation_tree_wire [0:TREESIZE-1];
        reg  signed [BITRED:0]     summation_tree_reg  [0:TREESIZE-1];
      
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
        
        
        
        genvar i;        
        genvar layer,j;
        generate
            for (i = 0; i < PHASES; i = i + 1) begin : init_level //in is Q1.15
                assign summation_tree_wire[i] = data_in[i][15 -: BITRED]; // Q1.10
            end
        endgenerate

        generate
            for (layer = 1; layer < LOG_NUMBER+1; layer = layer + 1) begin : tree_layers
                for (j = 0; j < PHASES >> layer; j = j + 1) begin : adder_stage
                      always @ (posedge clk_i) begin
                        summation_tree_reg[get_offset(layer)+j] <= (summation_tree_wire[get_offset(layer-1) + (2*j) ] + 
                                                      summation_tree_wire[get_offset(layer-1) + (2*j+1)]);// Q1.10 + Q1.10 = Q2.10 
                      end
                     assign summation_tree_wire[get_offset(layer)+j] = summation_tree_reg[get_offset(layer)+j][BITRED:1]; //Q2.10=? Q1.10
                end
            end
        endgenerate
        
        // EACH Addition Op -> Q1.7 +Q1.7 => Q1.8
        //Convert to Q5.11
        //{000000 00000000}
        assign data_out =  {summation_tree_wire[TREESIZE-1], 4'b0000000}; // {{4{summation_tree_wire[TREESIZE-1][BITRED]}},summation_tree_wire[TREESIZE-1],3'b000 } ;   //{summation_tree_wire[TREESIZE-1], 8'b00000000};//summation_tree_wire[TREESIZE-1]; //    // summation_tree_wire[LOG_NUMBER][0];
    
 
endmodule













/*

*/











