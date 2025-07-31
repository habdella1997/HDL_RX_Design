`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////


module rxTop2#(
    parameter DATAWIDTH     = 16, // DATA WIDTH BUS
    parameter PHASES        = 16, // NUMBER OF PARALLEL PHASES
    parameter PERIODICITY   = 16, // AUTO_CORRELATION PERIODICITY (# OF SAMPLES)
    parameter INT_BITS      = 0, // USED FOR DSP INTEGER PART
    parameter FRAC_BITS     = 15, // FULL_LENGTH-WORD_LEGHT = fractional PART
    parameter ARRAY_SIZE    = (DATAWIDTH * PHASES) -1
 )
 (
    input [ARRAY_SIZE:0]    re_i ,
    input [ARRAY_SIZE:0]    im_i ,
    input                   clk_i,
    input                   rst_i,
    output [2047:0]         eqDataRe_o,
    output [2047:0]         eqDataIM_o,
    output [63:0]           eqValid_o
    );
    
    wire [ARRAY_SIZE:0] data_synchronized_re_wire;
    wire [ARRAY_SIZE:0] data_synchronized_im_wire;
    wire [PHASES-1  :0] valid_synchronized_wire;
    
    synchronizer#(
        .DATAWIDTH   (DATAWIDTH                  ),
        .PHASES      (PHASES                     ),
        .PERIODICITY (PERIODICITY                ),
        .INT_BITS    (INT_BITS                   ),
        .FRAC_BITS   (FRAC_BITS                  ),
        .ARRAY_SIZE  (ARRAY_SIZE                 )
    )
    sync_inst(
        .re_i        (re_i                       ),
        .im_i        (im_i                       ),
        .clk_i       (clk_i                      ),
        .rst_i       (rst_i                      ),
        .data_re_o   (data_synchronized_re_wire  ),
        .data_im_o   (data_synchronized_im_wire  ),
        .valid_o     (valid_synchronized_wire    )
    );
    
//    localparam integer LTF_SIZE    = 64 * DATAWIDTH; //1024 bits for 16bit sample.
//    localparam integer FFT_SIZE    = 64;
//    localparam integer CP_LEN      = 16;
//    localparam integer NUMSYMB     = 12;
//    localparam integer STF_CYCLES  = (160+PHASES-1) / PHASES;
//    localparam integer LTF_CYCLES  = (160+PHASES-1) / PHASES;
//    localparam integer DATA_CYCLES = (((FFT_SIZE+CP_LEN) * NUMSYMB)+PHASES-1) / PHASES; //ceil <-> num+denom-1 / denom
//    localparam integer STF_COUNTER = $clog2(STF_CYCLES);
//    localparam integer DATA_COUNTER = $clog2(DATA_CYCLES);
//    localparam integer PACKET_SIZE  = 160+160+ ((FFT_SIZE + CP_LEN)*NUMSYMB);
//    localparam integer PACKET_CYCLES = $clog2(PACKET_SIZE / PHASES);
    
//    parameter IDLE = 2'b00,
//              STF  = 2'b01,
//              LTF  = 2'b10,
//              DATA = 2'b11;
    
//    reg [PACKET_CYCLES-1:0] packet_counter;
//    always @(clk_i)begin
//        if(rst_i)begin
//            packet_counter <= 1;
//        end else begin
//            if(valid_synchronized_wire)
//                packet_counter <= packet_counter + 1;
//            else 
//                packet_counter <= 1;
//        end
//    end
    
//    reg [1:0] state, next_state;
//    always @(posedge clk_i) begin
//        if(rst_i) begin
//            state <= IDLE;
//        end else begin
//            case(state)
//                IDLE: begin
//                    state = (valid_synchronized_wire) ? STF:LTF;
//                end
//                STF : begin
//                    state = (packet_counter == 
//                end
//            endcase
//        end
//    end
    
    
    
    
endmodule
