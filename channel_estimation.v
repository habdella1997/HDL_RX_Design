`timescale 1ns / 1ps

module channel_estimation #(
        parameter DATAWIDTH  = 16,
        parameter PHASES     = 16,
        parameter LTF_SIZE   = 64,
        parameter ARRAY_SIZE =(DATAWIDTH * LTF_SIZE) -1,
        parameter DATASYMS   =12 
    )(
        input clk_i,
        input rst_i,
        input [1407:0] re_i,
        input [1407:0] im_i,
        input valid_i,
        output [(22*LTF_SIZE)-1:0] channel_re_o,
        output [(22*LTF_SIZE)-1:0] channel_im_o,
        output channel_valid_o
    );
    
    /*
    LATENCY 23 Cycles : 22 for FFT, and 1 Cycle to compute the arithmatic for channel estimation
    */
    
    assign channel_re_o = channel_estimation_re;
    assign channel_im_o = channel_estimation_im;
    assign channel_valid_o = channel_estimation_valid;
    
    /*
    Perform FFT . 
    */
    wire [1407:0] fft_re_wire;
    wire [1407:0] fft_im_wire;
    wire valid_o;    
    reg [$clog2(DATASYMS):0] valid_counter;
    reg sample_flag;
    
    assign fft_re_wire = re_i ;
    assign fft_im_wire = im_i ;
    assign valid_o     = valid_i;
    
//    always @ (posedge clk_i) begin 
//        if(rst_i)begin
//            valid_counter <= 0;
//            sample_flag <= 1'b0;
//        end else begin
//            if (valid_i) begin
//                valid_counter <= (valid_counter < DATASYMS) ? valid_counter + 1:0;
//            end
//            sample_flag   <= (valid_counter >= 1) ? 1'b0:1'b1;
//        end
//    end
   
   wire signed [21:0] fft_re_ssr_wire [0:LTF_SIZE-1];
   wire signed [21:0] fft_im_ssr_wire [0:LTF_SIZE-1];
   
   genvar fft_i;
   generate
        for(fft_i = 0 ; fft_i < 64; fft_i = fft_i + 1)begin
            assign fft_re_ssr_wire[fft_i] = fft_re_wire[(fft_i+1)*22 -1 -: 22];
            assign fft_im_ssr_wire[fft_i] = fft_im_wire[(fft_i+1)*22 -1 -: 22];
        end
   endgenerate 
   
   // Lets Estimate the channel. 
   
   reg signed [(22*LTF_SIZE)-1:0] channel_estimation_re;
   reg signed [(22*LTF_SIZE)-1:0] channel_estimation_im;
   integer chest_i;
   reg channel_estimation_valid;
   always @ (posedge clk_i)begin
        if(rst_i) begin
            for(chest_i = 0; chest_i < LTF_SIZE ; chest_i = chest_i + 1)begin
                channel_estimation_re[(chest_i+1)*(22) -1 -: 22] <= {22{1'b0}};
                channel_estimation_im[(chest_i+1)*(22) -1 -: 22] <= {22{1'b0}};
            end
            channel_estimation_valid <=1'b0;
        end else begin
            channel_estimation_valid <= valid_o;
            if(valid_o) begin
                for(chest_i = 0; chest_i < LTF_SIZE; chest_i = chest_i + 1)begin
                    channel_estimation_re[(chest_i+1)*(22) -1 -: 22] <= (fft_re_ssr_wire[chest_i] * ltf_reference_seq[chest_i]);
                    channel_estimation_im[(chest_i+1)*(22) -1 -: 22] <= (fft_im_ssr_wire[chest_i] * ltf_reference_seq[chest_i]);
                end
            end else begin
                for(chest_i = 0; chest_i < LTF_SIZE; chest_i = chest_i + 1)begin
                    channel_estimation_re[chest_i] <= channel_estimation_re[chest_i];
                    channel_estimation_im[chest_i] <= channel_estimation_im[chest_i];
                end
            end
        end
   end
   


reg signed [1:0] ltf_reference_seq [0:LTF_SIZE-1];

initial begin
    ltf_reference_seq[ 0] = 0;
    ltf_reference_seq[ 1] = 1;
    ltf_reference_seq[ 2] = -1;
    ltf_reference_seq[ 3] = -1;
    ltf_reference_seq[ 4] = 1;
    ltf_reference_seq[ 5] = 1;
    ltf_reference_seq[ 6] = -1;
    ltf_reference_seq[ 7] = 1;
    ltf_reference_seq[ 8] = -1;
    ltf_reference_seq[ 9] = 1;
    ltf_reference_seq[10] = -1;
    ltf_reference_seq[11] = -1;
    ltf_reference_seq[12] = -1;
    ltf_reference_seq[13] = -1;
    ltf_reference_seq[14] = -1;
    ltf_reference_seq[15] = 1;
    ltf_reference_seq[16] = 1;
    ltf_reference_seq[17] = -1;
    ltf_reference_seq[18] = -1;
    ltf_reference_seq[19] = 1;
    ltf_reference_seq[20] = -1;
    ltf_reference_seq[21] = 1;
    ltf_reference_seq[22] = -1;
    ltf_reference_seq[23] = 1;
    ltf_reference_seq[24] = 1;
    ltf_reference_seq[25] = 1;
    ltf_reference_seq[26] = 1;
    ltf_reference_seq[27] = 0;
    ltf_reference_seq[28] = 0;
    ltf_reference_seq[29] = 0;
    ltf_reference_seq[30] = 0;
    ltf_reference_seq[31] = 0;
    ltf_reference_seq[32] = 0;
    ltf_reference_seq[33] = 0;
    ltf_reference_seq[34] = 0;
    ltf_reference_seq[35] = 0;
    ltf_reference_seq[36] = 0;
    ltf_reference_seq[37] = 0;
    ltf_reference_seq[38] = 1;
    ltf_reference_seq[39] = 1;
    ltf_reference_seq[40] = -1;
    ltf_reference_seq[41] = -1;
    ltf_reference_seq[42] = 1;
    ltf_reference_seq[43] = 1;
    ltf_reference_seq[44] = -1;
    ltf_reference_seq[45] = 1;
    ltf_reference_seq[46] = -1;
    ltf_reference_seq[47] = 1;
    ltf_reference_seq[48] = 1;
    ltf_reference_seq[49] = 1;
    ltf_reference_seq[50] = 1;
    ltf_reference_seq[51] = 1;
    ltf_reference_seq[52] = 1;
    ltf_reference_seq[53] = -1;
    ltf_reference_seq[54] = -1;
    ltf_reference_seq[55] = 1;
    ltf_reference_seq[56] = 1;
    ltf_reference_seq[57] = -1;
    ltf_reference_seq[58] = 1;
    ltf_reference_seq[59] = -1;
    ltf_reference_seq[60] = 1;
    ltf_reference_seq[61] = 1;
    ltf_reference_seq[62] = 1;
    ltf_reference_seq[63] = 1;
end  
   
   
    
endmodule
