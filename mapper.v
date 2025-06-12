


//////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////
// Below code does only symbol mapping
// The scalling factor associated with the constellation mapping 
// is ignored here. The signals will be properly scaled after 
// IFFT to save hardware resources.  

module mapper ( 
    input clk,
    input rst,
    //input en,
    input [1:0] mod_index,
    input [2:0] bit_data_i [0: 15],
    input [2:0] bit_data_q [0: 15],
    // 4-bits used here for here to represent minus numbers
    output [3:0] constMapped_I [0:15],  
    // 4-bits here to represent minus numbers
    output [3:0] constMapped_Q [0:15]    );

parameter BPSK = 2'b00, QPSK = 2'b01, QAM16 = 2'b10, QAM64 = 2'b11;
parameter PHASES = 16;
integer phaseNo;    // integer varible for iterating through phases
integer k; // iterating variable 

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

wire trunc_bq_psk_bit_data_i [0:15];
wire trunc_bq_psk_bit_data_q [0:15];

wire [1:0] trunc_qam16_bit_data_i [0:15];
wire [1:0] trunc_qam16_bit_data_q [0:15];
wire [2:0] trunc_qam64_bit_data_i [0:15];
wire [2:0] trunc_qam64_bit_data_q [0:15];

//wire [3:0] temp [0:15];
genvar kk;
generate
for (kk = 0; kk<PHASES; kk = kk+1) begin
    assign trunc_bq_psk_bit_data_i[kk] = bit_data_i[kk][0];
    assign trunc_bq_psk_bit_data_q[kk] = bit_data_q[kk][0];

    assign trunc_qam16_bit_data_i[kk] = bit_data_i[kk][1:0];
    assign trunc_qam16_bit_data_q[kk] = bit_data_q[kk][1:0];

    assign trunc_qam64_bit_data_i[kk] = bit_data_i[kk][2:0];
    assign trunc_qam64_bit_data_q[kk] = bit_data_q[kk][2:0];

    assign constMapped_I[kk] = ((mod_index == BPSK ) || (mod_index == QPSK)) ? BQ_PSK_MAP[trunc_bq_psk_bit_data_i[kk]] : 
                    ( (mod_index == QAM16) ?  QAM16_MAP[trunc_qam16_bit_data_i[kk]] :  QAM64_MAP[trunc_qam64_bit_data_i[kk]] );

    assign constMapped_Q[kk] = ((mod_index == BPSK ) || (mod_index == QPSK)) ? BQ_PSK_MAP[trunc_bq_psk_bit_data_q[kk]] : 
                    ( (mod_index == QAM16) ?  QAM16_MAP[trunc_qam16_bit_data_q[kk]] :  QAM64_MAP[trunc_qam64_bit_data_q[kk]] );


end
endgenerate

//assign constMapped_I = temp;
//assign constMapped_Q = temp;

/*
always @(*) begin
    case(mod_index) 
        BPSK: begin
            for(phaseNo = 0; phaseNo < PHASES; phaseNo= phaseNo+1) begin
                constMapped_I[phaseNo] = BQ_PSK_MAP[trunc_bpsk_bit_data[phaseNo]];//BQ_PSK_MAP[bit_data_i[phaseNo]];
                constMapped_Q[phaseNo] = 4'b1111;//BQ_PSK_MAP[trunc_bpsk_bit_data[phaseNo]];//BQ_PSK_MAP[bit_data_q[phaseNo]];
            end
        end
        QPSK: begin
             for(phaseNo = 0; phaseNo < PHASES; phaseNo= phaseNo+1) begin
                constMapped_I[phaseNo] = BQ_PSK_MAP[bit_data_i[phaseNo]];
                constMapped_Q[phaseNo] = BQ_PSK_MAP[bit_data_i[phaseNo]];
            end   
        end
        QAM16: begin
             for(phaseNo = 0; phaseNo < PHASES; phaseNo= phaseNo+1) begin
                constMapped_I[phaseNo] = QAM16_MAP[bit_data_i[phaseNo]];
                constMapped_Q[phaseNo] = QAM16_MAP[bit_data_i[phaseNo]];;
            end   
        end
        QAM64: begin
             for(phaseNo = 0; phaseNo < PHASES; phaseNo= phaseNo+1) begin
                constMapped_I[phaseNo] = QAM64_MAP[bit_data_i[phaseNo]];
                constMapped_Q[phaseNo] = QAM64_MAP[bit_data_i[phaseNo]];;
            end   
        end
    endcase

end
*/

/*always @(posedge clk) begin
    case(mod_index) 
        BPSK: begin
            for(phaseNo = 0; phaseNo < PHASES; phaseNo= phaseNo+1) begin
                constMapped_I[phaseNo] <= BQ_PSK_MAP[bit_data_i[phaseNo]];
                constMapped_Q[phaseNo] <= BQ_PSK_MAP[bit_data_q[phaseNo]];
            end
        end
        QPSK: begin
             for(phaseNo = 0; phaseNo < PHASES; phaseNo= phaseNo+1) begin
                constMapped_I[phaseNo] <= BQ_PSK_MAP[bit_data_i[phaseNo]];
                constMapped_Q[phaseNo] <= BQ_PSK_MAP[bit_data_i[phaseNo]];;
            end   
        end
        QAM16: begin
             for(phaseNo = 0; phaseNo < PHASES; phaseNo= phaseNo+1) begin
                constMapped_I[phaseNo] <= QAM16_MAP[bit_data_i[phaseNo]];
                constMapped_Q[phaseNo] <= QAM16_MAP[bit_data_i[phaseNo]];;
            end   
        end
        QAM64: begin
             for(phaseNo = 0; phaseNo < PHASES; phaseNo= phaseNo+1) begin
                constMapped_I[phaseNo] <= QAM64_MAP[bit_data_i[phaseNo]];
                constMapped_Q[phaseNo] <= QAM64_MAP[bit_data_i[phaseNo]];;
            end   
        end
    endcase

end
*/

endmodule
