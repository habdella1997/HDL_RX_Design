`timescale 1ns / 1ps
   
    /*
    Channel Eq.. ZF Algo
    (a+bj) / (c+dj) 
    (a+bj) * (c-dj)  * (1/(c^2 + d^2)) 
    part-1: Do the division once -> 1 / C^2 + d^2;
    part-2: Complex Mult -> (a+bj) * (c-dj) {Make sure to take conjugate of the channel term}
    */


    module equalizer #(
        parameter DATAWIDTH     = 16,
        parameter PHASES        = 16,
        parameter FFT           = 64,
        parameter CHANNEL_WIDTH = 22*FFT,
        parameter SYM_WIDTH    = DATAWIDTH * FFT,
        parameter CPLEN        = 16,
        parameter DATASYMS     = 12
    
    )(
        input clk_i,
        input rst_i,
        input [1407:0] datasymbolre_i,
        input [1407:0] datasymbolim_i,
        input [CHANNEL_WIDTH-1:0] channelre_i,
        input [CHANNEL_WIDTH-1:0] channelim_i,
        input channel_est_valid_i,
        input datasymbol_valid_i,
        output [32*FFT -1 :0] eq_datare_o,
        output [32*FFT -1 :0] eq_dataim_o,
        output [FFT-1:0] eq_valid_o
    );
    
    /*
        Process Data Symbols
    */
    
    // Step 1 - FFT. 
    
    wire [1407:0] fft_re_wire;
    wire [1407:0] fft_im_wire;
    wire valid_o;
    reg [$clog2(DATASYMS):0] valid_counter;
    reg sample_flag;
    
    assign fft_re_wire = datasymbolre_i ;
    assign fft_im_wire = datasymbolim_i ;
    assign valid_o     = datasymbol_valid_i;
    
    
    localparam integer DATA_CYCLES = (FFT + CPLEN + PHASES -1) / PHASES ; 
    localparam integer CHANNEL_LATENCY = 22 + 2 + 1 +12; //check PPT SLIDE.
    localparam integer DATA_LATENCY    = DATA_CYCLES + 22 + 4;
    localparam integer DATA_DELAY      = (CHANNEL_LATENCY - DATA_LATENCY)+1; 
    
//    reg  [1407:0] data_symbolsfft_re_mem [0:DATA_DELAY-1];
//    reg  [1407:0] data_symbolsfft_im_mem [0:DATA_DELAY-1];
//    reg  [DATA_DELAY-1:0]   data_validfft          ;


    
    bram #(
        .DATAWIDTH(22),
        .PHASES   (64),
        .DELAY    (DATA_DELAY)
    )data_delay_line_ut(
        .clk_i(clk_i),
        .rst_i(rst_i),
        .data_in_re(fft_re_wire),
        .data_in_im(fft_im_wire),
        .data_out_re(data_symbolsfft_re_mem_del),
        .data_out_im(data_symbolsfft_im_mem_del)
    );
    
    
    
    reg [1407:0] re_delay_line [0:DATA_DELAY-1];
    reg [1407:0] im_delay_line [0:DATA_DELAY-1];
    
    wire[1407:0] re_packet_delayed_wire;
    wire[1407:0] im_packet_delayed_wire;
    
    wire[1407:0] re_packet_delayed_wire_early; 
    wire[1407:0] im_pakcet_delayed_wire_early;
    
    

    reg  [DATA_DELAY-1:0]   data_validfft;
    
    always @ (posedge clk_i)begin
//        re_delay_line[0] <= fft_re_wire;
//        im_delay_line[0] <= fft_im_wire;
        data_validfft[0] <= valid_o;
    end
    
 
    genvar k;
    generate
        for(k = 1; k<DATA_DELAY; k = k + 1) begin
            always @ (posedge clk_i) begin
//                re_delay_line[k] <= re_delay_line[k-1];
//                im_delay_line[k] <= im_delay_line[k-1];
                data_validfft[k] <= data_validfft[k-1];
            end
        end
    endgenerate
    
    wire  [1407:0] data_symbolsfft_re_mem_del ;
    wire  [1407:0] data_symbolsfft_im_mem_del ;
    
//    assign data_symbolsfft_re_mem_del = re_delay_line[DATA_DELAY-1];
//    assign data_symbolsfft_im_mem_del = im_delay_line[DATA_DELAY-1];

  

    /*
    Prefrom complex mult 4 cycle latency
    */
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
        channel_coeff -> 22 bits Q7.15 
        (^2 ops) => Q7.15 * Q7.15 = Q15.30 << 9  => Q6.39
           Latency 1 Cycle
    */
    
    
    
    reg signed [44:0] ch_re_squared [0:FFT-1];
    reg signed [44:0] ch_im_squared [0:FFT-1];
    
    reg signed [21:0] ch_re [0:FFT-1];
    reg signed [21:0] ch_im [0:FFT-1];
    
    integer chsq_i;
    reg quotient_valid;
   
    always @ (posedge clk_i) begin
        if(channel_est_valid_i) begin
            for(chsq_i=0; chsq_i < FFT; chsq_i = chsq_i + 1)begin
                ch_re_squared[chsq_i] <= (channel_re_wire[chsq_i] * channel_re_wire[chsq_i]) << 9;
                ch_im_squared[chsq_i] <= (channel_im_wire[chsq_i] * channel_im_wire[chsq_i]) << 9;
                ch_re[chsq_i] <= channel_re_wire[chsq_i];
                ch_im[chsq_i] <= channel_im_wire[chsq_i] * -1;
            end
            quotient_valid <= channel_est_valid_i;
        end else begin
            quotient_valid <= 1'b0;
        end
    end
    
    /*
        Ok Preform CMULT . 
        Change(7/3/2025) -> 
        Need Output to be in format of Q6.15
        Q7.15 * Q7.15 = q15.30
        Lets get the output to Q6.15 -> 
         -> -> -> -> -> Q15.30 << 9 = Q6.39 then take MSB 21 <- <- <- <- <- 
        
    */
    wire signed [20:0] cmult_out_re [0:FFT-1];
    wire signed [20:0] cmult_out_im [0:FFT-1];
    wire cmult_out_valid[0:FFT-1];
    genvar cmu_i;
    generate 
        for(cmu_i = 0; cmu_i < FFT; cmu_i = cmu_i + 1)begin
            wire signed [21:0] temp_data_re, temp_data_im;
            wire [95:0] cmult_out;
//            assign temp_data_re = data_symbolsfft_re_mem[DATA_DELAY-1][(cmu_i+1)*22 -1 -:22];data_symbolsfft_re_mem_del
//            assign temp_data_im = data_symbolsfft_im_mem[DATA_DELAY-1][(cmu_i+1)*22 -1 -:22];
            assign temp_data_re = data_symbolsfft_re_mem_del[(cmu_i+1)*22 -1 -:22];
            assign temp_data_im = data_symbolsfft_im_mem_del[(cmu_i+1)*22 -1 -:22];
            wire [44:0] re_pretrunc, im_pretrunc;
            assign re_pretrunc = cmult_out[44:0] << 9;
            assign im_pretrunc = cmult_out[92:48] << 9;
            assign cmult_out_re[cmu_i] = re_pretrunc[44:24];
            assign cmult_out_im[cmu_i] = im_pretrunc[44:24];
            eq_cmult eqcmult_inst(
                .aclk(clk_i),
                .s_axis_a_tdata({2'b00,temp_data_im,2'b00,temp_data_re}),
                .s_axis_a_tvalid(data_validfft[DATA_DELAY-1]),
                .s_axis_b_tdata({2'b00,ch_im[cmu_i],2'b00,ch_re[cmu_i]}),
                .s_axis_b_tvalid(data_validfft[DATA_DELAY-1]),
                .m_axis_dout_tdata(cmult_out),
                .m_axis_dout_tvalid(cmult_out_valid[cmu_i])
            );
        end
    endgenerate

    /*
    Input is Q6.39 take 21 bits -> Q6.15
    Q6.15 + Q6.15 = Q7.15. => 22 bits.
    Q7.15 << 1 = Q6.16;
    */
    (* use_dsp = "yes" *)
    wire signed  [21:0] denom_term_wire [0:FFT-1];
    genvar denom_i;
    generate
        for(denom_i=0 ; denom_i < FFT; denom_i = denom_i + 1)begin
            assign denom_term_wire[denom_i] =
                             (ch_re_squared[denom_i][44:24] + ch_im_squared[denom_i][44:24])<<1;     
        end
    endgenerate
       
        /*
        take the inverse.
        Q6.16 -> (16 bits) -> take MSB 16 = Q6.10 
        Input is Q4.0 / Q6.10 <16bits>  
        Output is Q6.26 Take 21 bits => Q6.15
        Latency = 10 Cycles
    */
    
    wire signed [31:0]  m_axis_dout_tdata [0: FFT-1];   
    wire [0:FFT-1] m_axis_dout_tvalid;
    wire signed [15:0] divisor_temp [0:FFT-1];
    genvar div_i;
    generate 
        for(div_i = 0 ; div_i < FFT; div_i = div_i + 1)begin
            assign divisor_temp[div_i] = (denom_term_wire[div_i] == 0) ? 16'd1: denom_term_wire[div_i][21:6];
            wire signed [31:0] out_temp; // (q17.15  ... << 11) then q6.26 and take 21 bits then q6.15
            assign m_axis_dout_tdata[div_i] = out_temp<<11; //Q17.15
            div_gen_1 div_inst (
                .aclk                   (clk_i                          ),
                .s_axis_dividend_tdata  (8'b00000001                    ), 
                .s_axis_dividend_tvalid (quotient_valid                 ),
                .s_axis_divisor_tdata   (divisor_temp[div_i]            ),
                .s_axis_divisor_tvalid  (quotient_valid                 ),
                .m_axis_dout_tdata      (out_temp                       ),
                .m_axis_dout_tvalid     (m_axis_dout_tvalid[div_i]      )
            );
        end
    endgenerate
    
     /*
        Register the  Channel Divison Output
        1 cycle 
        Q6.15
    */

    reg signed [20:0] ch_coef_recepricol_reg [0:FFT-1];
    integer recp_i;
    always @ (posedge clk_i) begin
        for(recp_i=0;recp_i<FFT;recp_i=recp_i+1)begin
            if(m_axis_dout_tvalid[recp_i]) begin
                ch_coef_recepricol_reg[recp_i] <= m_axis_dout_tdata[recp_i][31 -: 21];
            end else begin
                ch_coef_recepricol_reg[recp_i] <= ch_coef_recepricol_reg[recp_i];
            end
        end
    end
    
    /*
    Final Step Preform Equalization ... 
    cmult_out_re cmult_out_im , cmult_out_valid
    
    Q6.15*Q6.15 = Q13.30 convert to Q6.26
    Q13.30 << 7 = Q6.37 and take 32 bit MSB

    */
    
    reg signed [42:0] data_eq_re [0:FFT-1];
    reg signed [42:0] data_eq_im [0:FFT-1];
    reg [FFT-1:0] data_eq_valid ;
    integer eq_j;
    always @(posedge clk_i)begin
        for (eq_j = 0 ; eq_j < FFT; eq_j = eq_j + 1)begin
            if (cmult_out_valid[eq_j]) begin
                if(eq_j == 0 || eq_j >= 27 && eq_j<=37) begin
                    data_eq_valid[eq_j] <= 1'b0;
                end else begin
                    data_eq_re[eq_j] <= (cmult_out_re[eq_j] * ch_coef_recepricol_reg[eq_j]) << 7;
                    data_eq_im[eq_j] <= (cmult_out_im[eq_j] * ch_coef_recepricol_reg[eq_j]) << 7;
                    data_eq_valid[eq_j] <= 1'b1;
                end
            end else begin
                data_eq_valid[eq_j] <= 1'b0;
            end
        end
    end
    
    genvar eq_k;
    generate
        for(eq_k = 0 ; eq_k < FFT ; eq_k = eq_k+1)begin
            assign eq_datare_o[(eq_k+1)*32 -1 -: 32] = data_eq_re[eq_k][42 -: 32];
            assign eq_dataim_o[(eq_k+1)*32 -1 -: 32] = data_eq_im[eq_k][42 -: 32];
            assign eq_valid_o[eq_k] = data_eq_valid[eq_k];
        end
    endgenerate
    
    
    
    
endmodule