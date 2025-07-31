`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/14/2025 11:09:09 PM
// Design Name: 
// Module Name: channel_equalize
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


module channel_equalize #(
    parameter DATAWIDTH     = 16,
    parameter PHASES        = 16,
    parameter FFT           = 64,
    parameter CHANNEL_WIDTH = 22*FFT,
    parameter SYM_WIDTH    = DATAWIDTH * FFT,
    parameter NUMSYMBS     = 12,
    parameter CPLEN        = 16

)(
    input clk_i,
    input rst_i,
    input [SYM_WIDTH-1:0] datasymbolre_i,
    input [SYM_WIDTH-1:0] datasymbolim_i,
    input [CHANNEL_WIDTH-1:0] channelre_i,
    input [CHANNEL_WIDTH-1:0] channelim_i,
    input channel_est_valid_i,
    input datasymbol_valid_i
    );
    
    
    /*
        FFT the DATA SYMBOLS :) 
        THE FFT in the channel est can be reused but at the cost of additional synchronizatino
        I think the FFT being of size 64 is not a big deal to re-instantiate and use here. 
        If DSP resources are getting over-utilized, we can move the channel equialization to the 
        channel estimation and reuse the FFT since the FFT there will be unitilized until the next packet 
        where the LTF needs to re-estimated. 
    */
    
    wire [1407:0] fft_re_wire;
    wire [1407:0] fft_im_wire;
    wire valid_o;
    wire [5:0] scale_o;
    
    fft64_v2_5 fft64_inst_2 ( // 22 cycle latency , output is Q22.15
    .valid_i    (datasymbol_valid_i),       // input  wire [0:0]
    .re_i       (datasymbolre_i),          // input  wire [1023:0]
    .im_i       (datasymbolim_i),          // input  wire [1023:0]
    .clk        (clk_i),           // input  wire
    
    .scale_o    (scale_o),       // output wire [5:0]
    .valid_o    (valid_o),       // output wire [0:0]
    .im_o       (fft_im_wire),          // output wire [1407:0]
    .re_o       (fft_re_wire)           // output wire [1407:0]
    );
    
    
    
    /*
    Channel Eq.. ZF Algo
    (a+bj) / (c+dj) 
    (a+bj) * (c-dj)  * (1/(c^2 + d^2)) 
    part-1: Do the division once -> 1 / C^2 + d^2;
    part-2: Complex Mult -> (a+bj) * (c-dj) {Make sure to take conjugate of the channel term}
    */
    
    
    /* Part 1 Division*/
    wire signed [21:0] channel_re_wire [0:FFT-1];
    wire signed [21:0] channel_im_wire [0:FFT-1];
    
    genvar ch_i;
    generate
        for(ch_i = 0; ch_i < FFT; ch_i = ch_i + 1) begin
            assign channel_re_wire[ch_i] = channelre_i[(ch_i+1)*22-1 -: 22];
            assign channel_im_wire[ch_i] = channelim_i[(ch_i+1)*22-1 -: 22];
        end
    endgenerate
    
    /*
        channel_coeff -> 22 bits Q21.15 
        Channel Term = (c+dj) 
        c^2 = Q21.15 * Q21.15 <=> Q43.30 <44 bits>
        Rescale back to Q21.15
            Q43.30 << 7 = Q43.37 [42:21]_22bits = Q21.15 
        Rule of thumb if you forget:
            Q21.15 -> 22-15 = 7 bits for integer. 
            To transform Q43.30 to Q21.15 by truncation 
                1. left shift by an amount that causes the integer to be 7
                    in this case 44 - y = 7 -> y = 37 
                    Q43.30 << 7 -> Q43.37 then take MSB 22 bits -> 22-7 = 15 -> Q22.15
           Latency 1 Cycle
    */
    reg signed [43:0] ch_re_squared [0:FFT-1];
    reg signed [43:0] ch_im_squared [0:FFT-1];
    integer chsq_i;
    reg quotient_valid;
    always @ (posedge clk_i) begin
        if(channel_est_valid_i) begin
            for(chsq_i=0; chsq_i < FFT; chsq_i = chsq_i + 1)begin
                ch_re_squared[chsq_i] <= (channel_re_wire[chsq_i] * channel_re_wire[chsq_i]) << 7;
                ch_im_squared[chsq_i] <= (channel_im_wire[chsq_i] * channel_im_wire[chsq_i]) << 7;
            end
            quotient_valid <= channel_est_valid_i;
        end else begin
            quotient_valid <= 1'b0;
        end
    end
    
    /*
        Q21.15 + Q21.15 = Q22.15 _ 23bits -> Correct Notation is Q8.15 {23 bits}
        (pepare for the division which is setup for Q3.13)
        Q8.15 << 5 = Q3.20.
    */
    wire signed  [22:0] denom_term_wire [0:FFT-1];
    genvar denom_i;
    generate
        for(denom_i=0 ; denom_i < FFT; denom_i = denom_i + 1)begin
            assign denom_term_wire[denom_i] =
                             (ch_re_squared[denom_i][43:22] + ch_im_squared[denom_i][43:22]) << 5;     
        end
    endgenerate
    
    /*
        take the inverse. 
        Input is Q4.0 / Q3.13 <16bits>  
        Output is 31 bits   Q19.12
        Latency = 10 Cycles
    */
    
    wire signed [31:0]  m_axis_dout_tdata [0: FFT-1];   
    wire [0:FFT-1] m_axis_dout_tvalid;
    wire signed [15:0] divisor_temp [0:FFT-1];
    genvar div_i;
    generate 
        for(div_i = 0 ; div_i < FFT; div_i = div_i + 1)begin
            assign divisor_temp[div_i] = (denom_term_wire[div_i] == 0) ? 16'd1: denom_term_wire[div_i][22:7];
            div_gen_1 div_inst (
                .aclk                   (clk_i                    ),
                .s_axis_dividend_tdata  (8'b00000001              ), 
                .s_axis_dividend_tvalid (quotient_valid           ),
                .s_axis_divisor_tdata   (divisor_temp[div_i]      ),
                .s_axis_divisor_tvalid  (quotient_valid           ),
                .m_axis_dout_tdata      (m_axis_dout_tdata[div_i] ),
                .m_axis_dout_tvalid     (m_axis_dout_tvalid[div_i])
            );
        end
    endgenerate
    
    /*
        Register the  Channel Divison Output
        1 cycle 
    */

    reg signed [31:0] ch_coef_recepricol_reg [0:FFT-1];
    integer recp_i;
    always @ (posedge clk_i) begin
        for(recp_i=0;recp_i<FFT;recp_i=recp_i+1)begin
            if(m_axis_dout_tvalid[recp_i]) begin
                ch_coef_recepricol_reg[recp_i] <= m_axis_dout_tdata[recp_i];
            end else begin
                ch_coef_recepricol_reg[recp_i] <= {32{1'b0}};
            end
        end
    end
   
   
    /*
    
    Latency Matching Between Channel Coeffecients and Recieved Data Symbols. 
    
    Channel Coefficient Path: Total Latency = 23+1+10+1 = 35 Cycles 
        1. 23 Cycles For Channel Estimation
        2. 1 Cycle For Multipication 
        3. 10 Cycles for Division
        4. 1 Cycle to Register the coefficients. 
    
    Data Path Relative to Channel coefficient Path:
        1. (Data_symbol_width)/PHASES . Ex FFT=64 and CP=16 and Phases = 16 <-> 80/16 = 5 Cycles
        2. 1 Cycle To register. 
        3. 22 Cycles For FFT    
            a. 16 Phases = 5+1+22 = 28 Cycles 
            b. 32 Phases = 2.5+1+22 = 26 Cycles
            c. 64 Phases = 1.25+1+22 = 25 Cycles. 
    
    Seems Like Data Path would align with the channel (pre-divison) so we can compute the second part which 
    is the complex multipication. 
    */
    
   
    

    
    integer dreg_i;
    

    
    /*
        Complex Multipication
        Input-1 = Q7.15
        Input-2 = Q7.15
        Output  => Q14.30
    */
    
    
    
    
    
    
    /*
    Do the equalization
    */
    
    
    
    
    
    /*
        State machien to contorl the flow 
        You need to signal a valid equalization .... 
        this should also be influenced by a packet detection...
     
    */
  
    localparam integer LTF_2_DATA  = (FFT + CPLEN + PHASES -1) / PHASES ; 
    
    parameter IDLE = 2'b00,
              HOLD = 2'b01,
              EQZ  = 2'b10;
              
    reg [1:0] state;
    reg [31:0] counter; // we will change the width later

    reg [21:0] fft_chre_reg [0:FFT-1];
    reg [21:0] fft_chim_reg [0:FFT-1];
    
    reg [21:0] fft_datare_reg [0:FFT-1];
    reg [21:0] fft_dataim_reg [0:FFT-1];
    
    integer chfft_i;
    always @ (posedge clk_i) begin
        if(channel_est_valid_i) begin
            for(chfft_i = 0 ; chfft_i < FFT; chfft_i = chfft_i + 1) begin
                fft_chre_reg[chfft_i] <= channel_re_wire[chfft_i];
                fft_chim_reg[chfft_i] <= channel_im_wire[chfft_i];
            end 
        end
        
    end
    
    
    //    always @ (posedge clk_i)begin
//        for(dreg_i = 0; dreg_i < FFT; dreg_i = dreg_i+1)begin
//            if(valid_o)begin
//                fft_re_reg[dreg_i] <= fft_re_wire[dreg_i];
//                fft_im_reg[dreg_i] <= fft_im_wire[dreg_i];
//            end else begin
//                fft_re_reg[dreg_i] <= {22{1'b0}};
//                fft_im_reg[dreg_i] <= {22{1'b0}};
//            end
//            if(channel_est_valid_i) begin
//                fft_chre_reg[dreg_i] <= channel_re_wire[chsq_i];
//                fft_chim_reg[dreg_i] <= channel_im_wire[chsq_i] * -1; // Take the conjugate
//            end
//        end
//    end
    
    
    
    
    
    
    
    
    
    
    
endmodule
