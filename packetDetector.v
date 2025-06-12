`timescale 1ns / 1ps

// NUMBER OF PHASES NEEDS TO BE A POWER OF 2 (MIN SUPPORTED 16) , 2^4 = 16, 2^5 = 32 .. 
module packetDetector
 #(
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
//    output [(32*PHASES)-1:0]    var_o,
//    output [(32*PHASES)-1:0] auto_corr_o,
    output [0:PHASES-1] threshold_decision_o
    );
    
    localparam integer LAG_SAMPLES = PERIODICITY; // IEEE802.11a = 16 
    localparam integer DELAY_WIDTH = (LAG_SAMPLES * DATAWIDTH) -1; // 16 Samples @ 16 bits => 256 BITS
    localparam integer ARRAY_MULT_WIDTH = ((DATAWIDTH) * (PERIODICITY+PHASES))-1;
    localparam integer SLICE_LEFT  = PHASES-PERIODICITY;
    localparam integer SLICE_RIGHT = SLICE_LEFT + PERIODICITY;
    localparam integer LOG_NUMBER = $clog2(PHASES);
    localparam signed [15:0] LOWWERTHRESH_Q015 =  16'h59CA; // q_fixed_val = round(LOWWERTHRESH * 2^15);  % = 22938 (decimal) = 16'h59CA (hex)
    
    
    reg  [DELAY_WIDTH:0] re_delay_line_reg ; // holds the delayed 16 samples (period of auto-correlation)
    reg  [DELAY_WIDTH:0] im_delay_line_reg ; // holds the delayed 16 samples
    
    wire  [ARRAY_MULT_WIDTH:0] re_buffer_mult_wire ; // holds current and delayed samples for auto-correlation 
    wire  [ARRAY_MULT_WIDTH:0] im_buffer_mult_wire ; // holds current and delayed samples for auto-correlation
    
    // SLICE THE INPUT DATA INTO THE DELAY LINE
    // IF PHASES = 16 then re_delay_line_reg should hold the entire input.
    // IF PHASES >= 32 then re_delay_line_reg should hold the last 16 phases.
    /*
        SLICE THE INPUT DATA INTO THE DELAY LINE
            1. IF PHASES = 16 then re_delay_line_reg should hold the entire input.
            2. IF PHASES >= 32 then re_delay_line_reg should hold the last 16 phases.
                2.a This is because s[0]*s[16] + ... + s[15]*s[31] happens during the incoming cycle.
                2.b Next Cycle we receive <s[32] .... s[63]>
                2.c we need <s[16] ... s[31]> stored for the operation s[16]*s[32] + ... + s[31]*s[47]
                3.a Similarily, in the same cycle we also do s[32]*s[48] + s[33]*s[49]
                4.a s[0]*s[16] + ... + s[15]*s[31] <cycle-1>
                4.b s[16]*s[32] + s[17]*s[33] + .... + s[32]*s[48] + ... + s[47]*s[63]
                   <Delayed Array*incoming[0:15]>     <incoming[0:15] * incoming[16:31]>
    */
   
    
    
    // GRAB THE LAST <PERIOD> SAMPLES FROM INPUT
    always @ (posedge clk_i) begin
        if(rst_i) begin
            re_delay_line_reg <= {(DELAY_WIDTH+1){1'b0}};
            im_delay_line_reg <= {(DELAY_WIDTH+1){1'b0}};
        end else begin // Adds a 1-cycle delay to the samples.
            re_delay_line_reg <= re_i[SLICE_RIGHT*DATAWIDTH-1 : SLICE_LEFT*DATAWIDTH]; // Grab the last 16 Samples. Each Sample is 16 bits.
            im_delay_line_reg <= im_i[SLICE_RIGHT*DATAWIDTH-1 : SLICE_LEFT*DATAWIDTH];
        end
    end
    
    assign re_buffer_mult_wire = {re_delay_line_reg , re_i};
    assign im_buffer_mult_wire = {im_delay_line_reg , im_i};
    
    wire signed [INT_BITS+FRAC_BITS:0] auto_correlation_re_wire [0:PHASES-1]; // holds the output of the autocorrelation real
    wire signed [INT_BITS+FRAC_BITS:0] auto_correlation_im_wire [0:PHASES-1]; // holds the output of the autocorrelation imaginary
    wire signed [INT_BITS+FRAC_BITS:0] variance_re_wire [0:PHASES-1]; // holds the output of the variance real (imaginary = 0) 
    
    /*
        PREFORM AUTOCORRELATION => 
        sample <= current_sample * conjugate(delayed_sample)
        re_buffer_mult_wire = {re_delay_line_reg , re_i} <--> bits [0,phases*datawith] is current samples
        last 16 samples in this buffer are delayed. 
        re_val1_i(re_buffer_mult_wire[((i+1)*DATAWIDTH)-1 -:DATAWIDTH]), <-- current sample
        re_val2_i(re_buffer_mult_wire[((i+PERIODICITY+1)*DATAWIDTH)-1 -:DATAWIDTH]), <-- delayed samples
    */
    genvar i;
    generate
        for (i = 0; i < PHASES; i = i + 1) begin : AUTOCORRELATION_BLOCK
            complexMultQ0_15 #(
                .DATAWIDTH(DATAWIDTH),
                .INT_BITS (INT_BITS),
                .FRAC_BITS(FRAC_BITS)
            ) autoCorrelation_inst_complex(
                .re_val2_i(re_buffer_mult_wire[((i+PERIODICITY+1)*DATAWIDTH)-1 -:DATAWIDTH]),
                .re_val1_i(re_buffer_mult_wire[((i+1)*DATAWIDTH)-1 -:DATAWIDTH]),
                .im_val2_i(im_buffer_mult_wire[((i+PERIODICITY+1)*DATAWIDTH)-1 -:DATAWIDTH]),
                .im_val1_i(im_buffer_mult_wire[((i+1)*DATAWIDTH)-1 -:DATAWIDTH]), 
                .conjugate(1'b1), // a+bj * (c+dj)^*
                .clk(clk_i),
                .re_o(auto_correlation_re_wire[i]),
                .im_o(auto_correlation_im_wire[i])
                );
        end
    endgenerate
    
    /*
        PERFORM VARIANCE COMPUTATION FOR SCALING.
        OPTIMIZATION - Can be swapped for a regular mult -> (a+bj)(a-bj) = a^2 + b^2.
        No Need for Complex Mult IP. 
        WARNING: If using complex make sure Sysnthesis is not optimizing it into a regular mult, 
        delay will differ, and auto-corr and var computation will be out of sync leading to 
        incorrect values. 
    */
    generate
        for (i = 0; i < PHASES; i = i + 1) begin : VARIANCE_BLOCK
            complexMultQ0_15 #(
                .DATAWIDTH(DATAWIDTH),
                .INT_BITS (INT_BITS),
                .FRAC_BITS(FRAC_BITS)
            ) autoCorrelation_inst_complex(
                .re_val2_i(re_buffer_mult_wire[(i+PERIODICITY+1)*DATAWIDTH -1 -:DATAWIDTH]),
                .re_val1_i(re_buffer_mult_wire[(i+PERIODICITY+1)*DATAWIDTH -1 -:DATAWIDTH]),
                .im_val2_i(im_buffer_mult_wire[(i+PERIODICITY+1)*DATAWIDTH -1 -:DATAWIDTH]),
                .im_val1_i(im_buffer_mult_wire[(i+PERIODICITY+1)*DATAWIDTH -1 -:DATAWIDTH]), 
                .conjugate(1'b1), // a+bj * (c+dj)^*
                .clk(clk_i),
                .re_o(variance_re_wire[i]),
                .im_o() // complex * cong(complex) = Re only ...
                );
        end
    endgenerate
    
    /*
        PERFORM SLIDING AVERAGE -> WIDTH OF SLIDING AVERAGE SHOULD EQUAL TO
        THAT OF THE PERIODICITY
        ESSENTIALLY INSERT A 16 WIDE BUFFER TO PUSH INTO AND SUM UP AND DIVIDE BY 16. 
        S64,...,S2,S1,S0---> < 0 0 0 . . .  0 0 0>
        <S0 0 0 0 .... 0 0 0> S0 / 16
        <S1 S0 0 0 . . . . 0 0 > ->S1 + S0 / 16
        ....
        <S15 S14 ... S1 S0> -> SUM(<>) / 16 

        Summation can be broken down into parallel reusable stages:
        
        SUM_16 <= (A0= S0 + S1), (A1 = S2 + S3) , ... , (A7 = S14+S15) Total of 8 Signals 
        SUM_8  <= (B0= A0 + A1), (B1 = A2 + A3), ... , (B3 = A6 + A7)  Total of 4 Signals
        SUM_4  <= (C0= B0 + B1), (C1 = B2+B3)                          Total of 2 Signals
        SUM_1  <= (D0 = C0+C1)                                         Total of 1 Signal
        
        NOW To Generalize to P-PHASES ...
        1. NEED to COMPUTE NUMBER OF LAYERS - Case 16 PHASES -> log2(16) = 4, 32-PHASES log2(32) = 5. 
        signaln to hold the sum [SUM_16, SUM_8, SUM_4, SUM_1] w/ size being log2(PHASES). 
        wire signed accumlate_sum_ac_re [log2(PHASES-1):0]
        sum_0
      */     
        //wire signed [INT_BITS+FRAC_BITS:0] auto_correlation_re_wire [0:PHASES-1]; // holds the output of the autocorrelation real
        
        reg signed [INT_BITS+FRAC_BITS:0] auto_correlation_re_reg [0:PHASES-1];
        wire signed [INT_BITS+FRAC_BITS:0] auto_correlation_re_wirez [0:PHASES-1];
        
        reg  signed [INT_BITS+FRAC_BITS:0] auto_correlation_im_reg [0:PHASES-1];
        wire signed [INT_BITS+FRAC_BITS:0] auto_correlation_im_wirez [0:PHASES-1];
        
        reg  signed [INT_BITS+FRAC_BITS:0] variance_re_reg [0:PHASES-1];
        wire signed [INT_BITS+FRAC_BITS:0] variance_re_wirez [0:PHASES-1];
        
        genvar idx;
        generate
          for (idx = 0; idx < PHASES; idx = idx + 1) begin
            assign auto_correlation_re_wirez[idx] = auto_correlation_re_reg[idx];
            assign auto_correlation_im_wirez[idx] = auto_correlation_im_reg[idx];
            assign variance_re_wirez[idx]        = variance_re_reg[idx];
          end
        endgenerate

        integer i1;
        always @ (posedge clk_i) begin
            for(i1=0;i1<PHASES;i1=i1+1)begin
                auto_correlation_re_reg[i1] <= auto_correlation_re_wire[i1];
                auto_correlation_im_reg[i1] <= auto_correlation_im_wire[i1];
                variance_re_reg[i1]         <= variance_re_wire[i1];
            end
        end
        
      wire signed [INT_BITS+FRAC_BITS:0] summation_tree_ac_re_wire [0:PHASES-1];  // Q4.11
      wire signed [INT_BITS+FRAC_BITS:0] summation_tree_ac_im_wire [0:PHASES-1];  // Q4.11
      wire signed [INT_BITS+FRAC_BITS:0] summation_tree_va_re_wire [0:PHASES-1];  // Q4.11 
      
      generate
        for(i=0; i<PHASES-1;i++)begin
              sim_tree 
                    #(    
                        .DATAWIDTH     (DATAWIDTH   ),
                        .PHASES        (PHASES      ),
                        .PERIODICITY   (PERIODICITY ),
                        .INT_BITS      (INT_BITS    ),
                        .FRAC_BITS     (FRAC_BITS   ),
                        .ARRAY_SIZE    (ARRAY_SIZE  ),
                        .LOG_NUMBER    (LOG_NUMBER  )
                    )auto_correlation_treeAdder_re
                    (
                     .data_in ({auto_correlation_re_wire[0:i],auto_correlation_re_wirez[i+1:PHASES-1]}), // holds the output of the autocorrelation real
                     .clk_i(clk_i),
                     .data_out(summation_tree_ac_re_wire[i])
                    );
                    
              sim_tree 
                    #(    
                        .DATAWIDTH     (DATAWIDTH   ),
                        .PHASES        (PHASES      ),
                        .PERIODICITY   (PERIODICITY ),
                        .INT_BITS      (INT_BITS    ),
                        .FRAC_BITS     (FRAC_BITS   ),
                        .ARRAY_SIZE    (ARRAY_SIZE  ),
                        .LOG_NUMBER    (LOG_NUMBER  )
                    )auto_correlation_treeAdder_im
                    (
                     .data_in ({auto_correlation_im_wire[0:i],auto_correlation_im_wirez[i+1:PHASES-1]}), // holds the output of the autocorrelation real
                     .clk_i(clk_i),
                     .data_out(summation_tree_ac_im_wire[i])
                    );
                    
              sim_tree 
                    #(    
                        .DATAWIDTH     (DATAWIDTH   ),
                        .PHASES        (PHASES      ),
                        .PERIODICITY   (PERIODICITY ),
                        .INT_BITS      (INT_BITS    ),
                        .FRAC_BITS     (FRAC_BITS   ),
                        .ARRAY_SIZE    (ARRAY_SIZE  ),
                        .LOG_NUMBER    (LOG_NUMBER  )
                    )variance_treeAdder_re
                    (
                     .data_in ({variance_re_wire[0:i],variance_re_wirez[i+1:PHASES-1]}), // holds the output of the autocorrelation real
                     .clk_i(clk_i),
                     .data_out(summation_tree_va_re_wire[i])
                    );
                    
                    
        end
      endgenerate
      
      sim_tree 
      #(    
          .DATAWIDTH     (DATAWIDTH   ),
          .PHASES        (PHASES      ),
          .PERIODICITY   (PERIODICITY ),
          .INT_BITS      (INT_BITS    ),
          .FRAC_BITS     (FRAC_BITS   ),
          .ARRAY_SIZE    (ARRAY_SIZE  ),
          .LOG_NUMBER    (LOG_NUMBER  )
      ) auto_correlation_treeAdder_last_sample_re
      (
           .data_in (auto_correlation_re_wire), // holds the output of the autocorrelation real
           .clk_i(clk_i),
           .data_out(summation_tree_ac_re_wire[PHASES-1])
      );
      sim_tree 
      #(    
          .DATAWIDTH     (DATAWIDTH   ),
          .PHASES        (PHASES      ),
          .PERIODICITY   (PERIODICITY ),
          .INT_BITS      (INT_BITS    ),
          .FRAC_BITS     (FRAC_BITS   ),
          .ARRAY_SIZE    (ARRAY_SIZE  ),
          .LOG_NUMBER    (LOG_NUMBER  )
      ) auto_correlation_treeAdder_last_sample_im
      (
       .data_in (auto_correlation_im_wire), // holds the output of the autocorrelation real
       .clk_i(clk_i),
       .data_out(summation_tree_ac_im_wire[PHASES-1])
      );
      sim_tree 
      #(    
          .DATAWIDTH     (DATAWIDTH   ),
          .PHASES        (PHASES      ),
          .PERIODICITY   (PERIODICITY ),
          .INT_BITS      (INT_BITS    ),
          .FRAC_BITS     (FRAC_BITS   ),
          .ARRAY_SIZE    (ARRAY_SIZE  ),
          .LOG_NUMBER    (LOG_NUMBER  )
      ) variance_treeAdder_last_sample_re
      (
       .data_in (variance_re_wire), // holds the output of the autocorrelation real
       .clk_i(clk_i),
       .data_out(summation_tree_va_re_wire[PHASES-1])
      );
      
      
      
      /*
        NEXT:
        Divide by PHASES To get the mean of the sliding average. 
        Take the abs of the correlation values or square. 
        Multiply the variance square with the ratio value
        take the comparison of those to detect the packet.
      */
      
      // summation_tree_ac_re_wire^2 + summation_tree_ac_im_wire^2
      
      /*
        wire [31:0] mult_out;
        assign c_o = (mult_out >>> 15);
        // Instantiate the Multiplier IP core
        mult_gen_0 mult_inst (
            .CLK (clk_i),   // clock input
            .A   (a_i),     // 16-bit signed input A
            .B   (b_i),     // 16-bit signed input B
            .P   (mult_out)      // 32-bit signed output product
        );
      */
      //wire signed [INT_BITS+FRAC_BITS:0] summation_tree_ac_re_wire [0:PHASES-1];  
      wire signed [(INT_BITS+FRAC_BITS+1)*2-1:0] ac_re_squared [0:PHASES-1];
      wire signed [(INT_BITS+FRAC_BITS+1)*2-1:0] ac_im_squared [0:PHASES-1];
      wire signed [(INT_BITS+FRAC_BITS+1)*2-1:0] va_re_squared [0:PHASES-1];
      wire signed [(INT_BITS+FRAC_BITS+1)*2  :0] ac_sum_square [0:PHASES-1];
      
      reg  signed [(INT_BITS+FRAC_BITS+1)*2-1:0]  va_re_squared_reg [0:PHASES-1]; //delay
      wire  signed [(INT_BITS+FRAC_BITS+1)*2-1:0] va_re_squared_z [0:PHASES-1];
      
      assign va_re_squared_z = va_re_squared_reg; // 1-cycle delay for the variance to compensate for the cycle in the addition
      always @ (posedge clk_i) begin
        va_re_squared_reg <= va_re_squared;
      end
      
      wire signed  [(INT_BITS+FRAC_BITS+4):0] ac_re_divide16 [0:PHASES-1];
      wire signed [(INT_BITS+FRAC_BITS+4):0] ac_im_divide16 [0:PHASES-1];
      wire signed [(INT_BITS+FRAC_BITS+4):0] va_re_divide16 [0:PHASES-1];
      wire signed [47:0] lower_threshold_compute [0:PHASES-1];
      wire signed [(INT_BITS+FRAC_BITS+1)*2:0] lower_threshold_compute_q2_30 [0:PHASES-1];
      reg signed [(INT_BITS+FRAC_BITS+1)*2:0] ac_registered_delay1_reg [0:PHASES-1];
      reg signed [(INT_BITS+FRAC_BITS+1)*2:0] ac_registered_delay2_reg [0:PHASES-1];
      wire signed [(INT_BITS+FRAC_BITS+1)*2:0] ac_regiseted_delay2_wired [0:PHASES-1];
      

      
      integer i3;
      always @ (posedge clk_i) begin
        for(i3 = 0; i3<PHASES;i3=i3+1) begin
            ac_registered_delay1_reg[i3] <= ac_sum_square[i3]; //1 cycle 
            ac_registered_delay2_reg[i3] <= ac_registered_delay1_reg[i3]; // 2 cycle Latency. 
        end
      end
      
      
      generate
        for(i=0;i<PHASES;i++)begin
            assign ac_re_divide16[i] = {summation_tree_ac_re_wire[i],4'b0000} >>> 4; //{Q4.11 , 4'b0000} => Q4.15 >>> 4 => Q0.15.
            assign ac_im_divide16[i] = {summation_tree_ac_im_wire[i],4'b0000} >>> 4; //{Q4.11 , 4'b0000} => Q4.15 >>> 4 => Q0.15.
            assign va_re_divide16[i] = {summation_tree_va_re_wire[i],4'b0000} >>> 4; //{Q4.11 , 4'b0000} => Q4.15 >>> 4 => Q0.15.
            mult_gen_0 mult_inst_ac_re(
                .CLK(clk_i),
                .A(ac_re_divide16[i][15:0]), //  Q0.15
                .B(ac_re_divide16[i][15:0]), //  Q0.15
                .P(ac_re_squared[i])              // Q0.15 * Q0.15 => Q1.30 -> 32 bits. 
            );
            mult_gen_0 mult_inst_ac_im(
                .CLK(clk_i),
                .A(ac_im_divide16[i][15:0]),
                .B(ac_im_divide16[i][15:0]),
                .P(ac_im_squared[i]) 
            );
            
            mult_gen_0 mult_inst_va_re(
                .CLK(clk_i),
                .A(va_re_divide16[i][15:0]),
                .B(va_re_divide16[i][15:0]),
                .P(va_re_squared[i]) 
            );
            
            constant_pd_mult mult_inst_va_lower_ratio(
                .CLK(clk_i),
                .A(va_re_squared[i]), //Q1.30
                .B(LOWWERTHRESH_Q015), //Q0.15
                .P(lower_threshold_compute[i]) //Q2.45
            );
            assign lower_threshold_compute_q2_30[i] = lower_threshold_compute[i][47:15];   //{lower_threshold_compute[i][31],lower_threshold_compute[i]};
            
            c_addsub_1 ac_summation (
                .A(ac_re_squared[i]), // Q1.30
                .B(ac_im_squared[i]), // Q1.30
                .CE(1'b1),  // Clock enable = 1
                .CLK(clk_i),
                .S(ac_sum_square[i]) // Q1.30 + Q1.30 => Q2.30
             );
             assign ac_regiseted_delay2_wired[i] = ac_registered_delay2_reg[i];
             assign threshold_decision_o[i] = (ac_regiseted_delay2_wired[i] > lower_threshold_compute_q2_30[i] && lower_threshold_compute_q2_30[i]!=0) ? 1'b1:1'b0;
        end
      endgenerate
    

//    generate
//    for (i = 0; i < PHASES; i = i + 1) begin : PACK_OUTPUT
//        assign var_o[(i+1)*32-1 : i*32] = va_re_squared_reg[i];//slidingAvg_va_re_wire[i][DATAWIDTH-1:0];
//        assign auto_corr_o[(i+1)*32-1 : i*32] = ac_sum_square[i][32:1];
//    end
//    endgenerate
      
      

        
               

    
    
    
    
    
endmodule
