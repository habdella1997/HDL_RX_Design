`timescale 1ns / 1ps

module mapper #(
    parameter PHASES  = 16,
    parameter WIDTH   =  3 //QPSK -> 2 bits {-1,1} , 16-QAM 3 bits {-3,-1,1,3} , 64-QAM 4 bits {
)(
    input clk_i,
    input rst_i,
    input enable_i,
    input [1:0] modScheme_i, // {QPSK = 0, 16-QAM = 1 , 64-QAM 2}
    input [PHASES*WIDTH - 1 :0] data_q_i,
    input [PHASES*WIDTH - 1 :0] data_i_i,
    output reg [PHASES*16 - 1 :0] data_i_scaled_o,
    output reg [PHASES*16 -1 : 0] data_q_scaled_o
    );
    
    
    parameter QPSK = 2'b00, QAM16 = 2'b10, QAM64=2'b11;
    
    reg [PHASES*WIDTH - 1:0] data_q_reg;
    reg [PHASES*WIDTH - 1:0] data_i_reg;
    
    always @ (posedge clk_i)begin
        data_q_reg <= data_q_i;
        data_i_reg <= data_i_i;
    end
    
    // Gray mapping for the incoming bits
    // BPSK and QPSK can be directly mapped
    localparam [3:0] BQ_PSK_MAP [0:1] = '{4'b1111, 4'b0001}; // -1 for incoming bit 0, +1 for incoming bit 0 
    localparam [3:0] QAM16_MAP  [0:3] = '{4'b1101, 4'b1111, 4'b0011, 4'b0001}; // 00 --> -3 , 01 --> -1, 10 --> +3, 11 --> +1
    // 64 QAM case
    //Binary: 000, 001, 010, 011, 100, 101, 110, 111
    //Dec   :  -7,  -5,  -3,  -1,  +1, +3,   +5,  +7
    //Gray  : 000, 001, 011, 010, 110, 111, 101, 100
    //Tx sequence                          -7       -5       -1        -3      +5       +7       +3       +1
    localparam [3:0] QAM64_MAP [0:7] = '{4'b1001, 4'b1011, 4'b1101, 4'b1111, 4'b0001, 4'b0011, 4'b0101, 4'b0111}; 
    
    wire trunc_bq_psk_bit_data_i [0:PHASES-1];
    wire trunc_bq_psk_bit_data_q [0:PHASES-1];
    
    wire [1:0] trunc_qam16_bit_data_i [0:PHASES-1];
    wire [1:0] trunc_qam16_bit_data_q [0:PHASES-1];
    wire [2:0] trunc_qam64_bit_data_i [0:PHASES-1];
    wire [2:0] trunc_qam64_bit_data_q [0:PHASES-1];

    genvar kk;
    generate
    for (kk = 0; kk<PHASES; kk = kk+1) begin
        assign trunc_bq_psk_bit_data_i[kk] = data_i_reg[kk];
        assign trunc_bq_psk_bit_data_q[kk] = data_q_reg[kk];
    
        assign trunc_qam16_bit_data_i[kk] = data_i_reg[(kk+1)*2 -1 -: 2];
        assign trunc_qam16_bit_data_q[kk] = data_q_reg[(kk+1)*2 -1 -: 2];
    
        assign trunc_qam64_bit_data_i[kk] = data_i_reg[(kk+1)*3 -1 -: 3];
        assign trunc_qam64_bit_data_q[kk] = data_q_reg[(kk+1)*3 -1 -: 3];
    
        assign data_i_prescale[(kk+1)*4 -1 -:4] = (modScheme_i == QPSK) ? BQ_PSK_MAP[trunc_bq_psk_bit_data_i[kk]] : 
                        ( (modScheme_i == QAM16) ?  QAM16_MAP[trunc_qam16_bit_data_i[kk]] :  QAM64_MAP[trunc_qam64_bit_data_i[kk]] );
    
        assign data_q_prescale[(kk+1)*4 -1 -:4] = ( modScheme_i == QPSK) ? BQ_PSK_MAP[trunc_bq_psk_bit_data_q[kk]] : 
                        ( (modScheme_i == QAM16) ?  QAM16_MAP[trunc_qam16_bit_data_q[kk]] :  QAM64_MAP[trunc_qam64_bit_data_q[kk]] );
    
    
    end
    endgenerate
    wire [PHASES*4 -1 :0] data_i_prescale, data_q_prescale;
    
    parameter QPSK_SCALING = 11'h5A9, //0.707
              QAM16_SCALING = 11'h289, // 0.303
              QAM64_SCALING = 11'h13C; // 0.15
    //Q4.0 * Q0.11 = Q5.11; //16bits;
    reg [PHASES*16 - 1 :0] data_i_scaled, data_q_scaled;
    integer s_i;              
    always @(posedge clk_i) begin
        if(modScheme_i == QPSK)begin
            for(s_i=0; s_i < PHASES ; s_i = s_i + 1)begin
                data_i_scaled[(s_i+1)*16 -1 -: 16] <= data_i_prescale[(s_i+1)*4 -1 -: 4] *QPSK_SCALING;
                data_q_scaled[(s_i+1)*16 -1 -: 16] <= data_q_prescale[(s_i+1)*4 -1 -: 4] *QPSK_SCALING;
                data_i_scaled_o[(s_i+1)*16 -1 -: 16] <= data_i_scaled[(s_i+1)*16 -1 -: 16];
                data_q_scaled_o[(s_i+1)*16 -1 -: 16] <= data_q_scaled[(s_i+1)*16 -1 -: 16];
            end
        end else if(modScheme_i == QAM16)begin
            for(s_i=0; s_i < PHASES ; s_i = s_i + 1)begin
                data_i_scaled[(s_i+1)*16 -1 -: 16] <= data_i_prescale[(s_i+1)*4 -1 -: 4] *QAM16_SCALING;
                data_q_scaled[(s_i+1)*16 -1 -: 16] <= data_q_prescale[(s_i+1)*4 -1 -: 4] *QAM16_SCALING;
                data_i_scaled_o[(s_i+1)*16 -1 -: 16] <= data_i_scaled[(s_i+1)*16 -1 -: 16];
                data_q_scaled_o[(s_i+1)*16 -1 -: 16] <= data_q_scaled[(s_i+1)*16 -1 -: 16];
            end        
        end else if(modScheme_i == QAM64)begin
            for(s_i=0; s_i < PHASES ; s_i = s_i + 1)begin
                data_i_scaled[(s_i+1)*16 -1 -: 16] <= data_i_prescale[(s_i+1)*4 -1 -: 4] *QAM64_SCALING;
                data_q_scaled[(s_i+1)*16 -1 -: 16] <= data_q_prescale[(s_i+1)*4 -1 -: 4] *QAM64_SCALING;
                data_i_scaled_o[(s_i+1)*16 -1 -: 16] <= data_i_scaled[(s_i+1)*16 -1 -: 16];
                data_q_scaled_o[(s_i+1)*16 -1 -: 16] <= data_q_scaled[(s_i+1)*16 -1 -: 16];
            end   
        end
    end

    endmodule