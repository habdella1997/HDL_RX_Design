
module rate_convert(
    input [127:0] data_256_i,
    input [127:0] data_256_q,
    input rst,  // this reset has to be after the clocks are stablized from the data converter IP,
    input clk_128,
    input clk_256,
    input locked,   // indicates that the clock divider outputs are stable to use when asserted
    input ILA_trig
    //output [255:0] data128_i,
    //output clk_128
    );
    
    reg state, state_z = 1'b0;
    reg [127 :0] state1_data_i;
    reg [127 :0] state2_data_i;
    reg [127 :0] state1_data_q;
    reg [127 :0] state2_data_q;
    
    reg [255 :0] data128i;
    reg [255 :0] data128q;
    
    reg locked_128 = 0;
    
    //wire clk_256;
    //wire locked; 
    integer iter;
    
    always @ (posedge clk_256) begin
        if (!locked_128) begin 
            #1 state <= 0;
               state_z <= state;
        end 
        else begin 
            #1 state_z <= state;
            if(state == 1'b0) begin
                state <= 1'b1;
            end
            else begin
                state <= 1'b0;
            end
        end
    end
    
    always @ (posedge clk_256) begin 
        if (!locked_128) begin 
            state1_data_i <= 0;
            state2_data_i <= 0;
            state1_data_q <= 0;
            state2_data_q <= 0;
        end 
        else begin 
            if(state_z == 1'b0) begin
                #1 state1_data_i <= data_256_i;
                   state1_data_q <= data_256_q;
            end
            else begin
                #1 state2_data_i <= data_256_i;
                   state2_data_q <= data_256_q;
            end
        end
    end
    
    always @ (posedge clk_128) begin
        if(!locked_128) begin
            #1 data128i <= 0;
               data128q <= 0;
        end
        else begin
            #1 data128i <= {state2_data_i,state1_data_i};
               data128q <= {state2_data_q,state1_data_q};
        end
    end
    

   always @ (posedge clk_128) begin
        if(!locked) begin
            #1 locked_128 <= 0;
        end
        else 
            #1 locked_128 <= 1;
   end
   
reg [11:0] i_data [0:15];
reg [11:0] q_data [0:15];
always @ (posedge clk_128) begin
    if(!locked) begin
        for (iter = 0; iter < 16; iter = iter+1) begin
            i_data[iter] <= { data128i[16*iter+15 -: 12]} ; 
            q_data[iter] <= { data128q[16*iter+15 -: 12]} ; 
        end
    end
    else begin
        for (iter = 0; iter < 16; iter = iter+1) begin
            i_data[iter] <= { data128i[16*iter+15 -: 12]} ; 
            q_data[iter] <= { data128q[16*iter+15 -: 12]} ; 
        end
    end
end
   
// instantiate the ILA for ADC data loggging
ila_1 adc_i_q (
	.clk(clk_128), // input wire clk 
	.probe0(i_data[0]), // input wire [11:0]  probe0  
	.probe1(i_data[1]), // input wire [11:0]  probe1 
	.probe2(i_data[2]), // input wire [11:0]  probe2 
	.probe3(i_data[3]), // input wire [11:0]  probe3 
	.probe4(i_data[4]), // input wire [11:0]  probe4 
	.probe5(i_data[5]), // input wire [11:0]  probe5 
	.probe6(i_data[6]), // input wire [11:0]  probe6 
	.probe7(i_data[7]), // input wire [11:0]  probe7 
	.probe8(i_data[8]), // input wire [11:0]  probe8 
	.probe9(i_data[9]), // input wire [11:0]  probe9 
	.probe10(i_data[10]), // input wire [11:0]  probe10 
	.probe11(i_data[11]), // input wire [11:0]  probe11 
	.probe12(i_data[12]), // input wire [11:0]  probe12 
	.probe13(i_data[13]), // input wire [11:0]  probe13 
	.probe14(i_data[14]), // input wire [11:0]  probe14 
	.probe15(i_data[15]), // input wire [11:0]  probe15 
	.probe16(q_data[0]), // input wire [0:0]  probe16
	.probe17(q_data[1]), // input wire [11:0]  probe17 
	.probe18(q_data[2]), // input wire [11:0]  probe18 
	.probe19(q_data[3]), // input wire [11:0]  probe19 
	.probe20(q_data[4]), // input wire [11:0]  probe20 
	.probe21(q_data[5]), // input wire [11:0]  probe21 
	.probe22(q_data[6]), // input wire [11:0]  probe22 
	.probe23(q_data[7]), // input wire [11:0]  probe23 
	.probe24(q_data[8]), // input wire [11:0]  probe24 
	.probe25(q_data[9]), // input wire [11:0]  probe25 
	.probe26(q_data[10]), // input wire [11:0]  probe26 
	.probe27(q_data[11]), // input wire [11:0]  probe27 
	.probe28(q_data[12]), // input wire [11:0]  probe28 
	.probe29(q_data[13]), // input wire [11:0]  probe29 
	.probe30(q_data[14]), // input wire [11:0]  probe30 
	.probe31(q_data[15]), // input wire [11:0]  probe31 
	.probe32(ILA_trig) // input wire [0:0]  probe32
);


/* Instantiate the timing aquisition module */
wire [15:0] pd_assert_high;
wire [15:0] pd_assert_low;
rx_timing_acq_0 rx_timing_acq (
  .inim0(q_data[0]),                  // input wire [11 : 0] inim0
  .inim1(q_data[1]),                  // input wire [11 : 0] inim1
  .inim10(q_data[10]),                // input wire [11 : 0] inim10
  .inim11(q_data[11]),                // input wire [11 : 0] inim11
  .inim12(q_data[12]),                // input wire [11 : 0] inim12
  .inim13(q_data[13]),                // input wire [11 : 0] inim13
  .inim14(q_data[14]),                // input wire [11 : 0] inim14
  .inim15(q_data[15]),                // input wire [11 : 0] inim15
  .inim2(q_data[2]),                  // input wire [11 : 0] inim2
  .inim3(q_data[3]),                  // input wire [11 : 0] inim3
  .inim4(q_data[4]),                  // input wire [11 : 0] inim4
  .inim5(q_data[5]),                  // input wire [11 : 0] inim5
  .inim6(q_data[6]),                  // input wire [11 : 0] inim6
  .inim7(q_data[7]),                  // input wire [11 : 0] inim7
  .inim8(q_data[8]),                  // input wire [11 : 0] inim8
  .inim9(q_data[9]),                  // input wire [11 : 0] inim9
  .inre0(i_data[0]),                  // input wire [11 : 0] inre0
  .inre1(i_data[1]),                  // input wire [11 : 0] inre1
  .inre10(i_data[10]),                // input wire [11 : 0] inre10
  .inre11(i_data[11]),                // input wire [11 : 0] inre11
  .inre12(i_data[12]),                // input wire [11 : 0] inre12
  .inre13(i_data[13]),                // input wire [11 : 0] inre13
  .inre14(i_data[14]),                // input wire [11 : 0] inre14
  .inre15(i_data[15]),                // input wire [11 : 0] inre15
  .inre2(i_data[2]),                  // input wire [11 : 0] inre2
  .inre3(i_data[3]),                  // input wire [11 : 0] inre3
  .inre4(i_data[4]),                  // input wire [11 : 0] inre4
  .inre5(i_data[5]),                  // input wire [11 : 0] inre5
  .inre6(i_data[6]),                  // input wire [11 : 0] inre6
  .inre7(i_data[7]),                  // input wire [11 : 0] inre7
  .inre8(i_data[8]),                  // input wire [11 : 0] inre8
  .inre9(i_data[9]),                  // input wire [11 : 0] inre9
  .clk(clk_128),                      // input wire clk
  .fir_out_pwr0(P[0]),    // output wire [36 : 0] fir_out_pwr0
  .fir_out_pwr1(P[1]),    // output wire [36 : 0] fir_out_pwr1
  .fir_out_pwr10(P[10]),  // output wire [36 : 0] fir_out_pwr10
  .fir_out_pwr11(P[11]),  // output wire [36 : 0] fir_out_pwr11
  .fir_out_pwr12(P[12]),  // output wire [36 : 0] fir_out_pwr12
  .fir_out_pwr13(P[13]),  // output wire [36 : 0] fir_out_pwr13
  .fir_out_pwr14(P[14]),  // output wire [36 : 0] fir_out_pwr14
  .fir_out_pwr15(P[15]),  // output wire [36 : 0] fir_out_pwr15
  .fir_out_pwr2(P[2]),    // output wire [36 : 0] fir_out_pwr2
  .fir_out_pwr3(P[3]),    // output wire [36 : 0] fir_out_pwr3
  .fir_out_pwr4(P[4]),    // output wire [36 : 0] fir_out_pwr4
  .fir_out_pwr5(P[5]),    // output wire [36 : 0] fir_out_pwr5
  .fir_out_pwr6(P[6]),    // output wire [36 : 0] fir_out_pwr6
  .fir_out_pwr7(P[7]),    // output wire [36 : 0] fir_out_pwr7
  .fir_out_pwr8(P[8]),    // output wire [36 : 0] fir_out_pwr8
  .fir_out_pwr9(P[9]),    // output wire [36 : 0] fir_out_pwr9
  .lower_thresh(pd_assert_low),    // output wire [15 : 0] lower_thresh
  .upper_thresh(pd_assert_high)    // output wire [15 : 0] upper_thresh
);


wire [11:0] data_in_re[0:15];
wire [11:0] data_in_im[0:15];
wire [36:0] P[0:15];

genvar tmp;
generate
for (tmp = 0; tmp < 16; tmp = tmp+1) begin
    assign data_in_re[tmp] = i_data[tmp] ; 
    assign data_in_im[tmp] = q_data[tmp] ; 
end
endgenerate


agc_fd_cntrl uut(
    .clk(clk_128), 
    .ce(clk_en),
    .rst(rst),
    .en(en),
    .ILA_trig(ILA_trig),
    .data_re0(data_in_re[0]),
    .data_re1(data_in_re[1]),
    .data_re2(data_in_re[2]),
    .data_re3(data_in_re[3]),
    .data_re4(data_in_re[4]),
    .data_re5(data_in_re[5]),
    .data_re6(data_in_re[6]),
    .data_re7(data_in_re[7]),
    .data_re8(data_in_re[8]),
    .data_re9(data_in_re[9]),
    .data_re10(data_in_re[10]),
    .data_re11(data_in_re[11]),
    .data_re12(data_in_re[12]),
    .data_re13(data_in_re[13]),
    .data_re14(data_in_re[14]),
    .data_re15(data_in_re[15]),   
    .data_im0(data_in_im[0]),
    .data_im1(data_in_im[1]),
    .data_im2(data_in_im[2]),
    .data_im3(data_in_im[3]),
    .data_im4(data_in_im[4]),
    .data_im5(data_in_im[5]),
    .data_im6(data_in_im[6]),
    .data_im7(data_in_im[7]),
    .data_im8(data_in_im[8]),
    .data_im9(data_in_im[9]),
    .data_im10(data_in_im[10]),
    .data_im11(data_in_im[11]),
    .data_im12(data_in_im[12]),
    .data_im13(data_in_im[13]),
    .data_im14(data_in_im[14]),
    .data_im15(data_in_im[15]),  
    .comp_high_thresh(pd_assert_high),  //the MSB has the latest sample 
    .p_d_flag(p_d_flag), // *one cycle delayed packet_detect_flag
    .t_acq_abs_sq0(P[0]),
    .t_acq_abs_sq1(P[1]),
    .t_acq_abs_sq2(P[2]),
    .t_acq_abs_sq3(P[3]),
    .t_acq_abs_sq4(P[4]),
    .t_acq_abs_sq5(P[5]),
    .t_acq_abs_sq6(P[6]),
    .t_acq_abs_sq7(P[7]),
    .t_acq_abs_sq8(P[8]),
    .t_acq_abs_sq9(P[9]),
    .t_acq_abs_sq10(P[10]),
    .t_acq_abs_sq11(P[11]),
    .t_acq_abs_sq12(P[12]),
    .t_acq_abs_sq13(P[13]),
    .t_acq_abs_sq14(P[14]),
    .t_acq_abs_sq15(P[15])
    );

endmodule
