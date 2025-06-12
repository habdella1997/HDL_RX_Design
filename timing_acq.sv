`timescale 1ns / 1ps



module timing_acq
 #(
    parameter DATAWIDTH     = 16, // DATA WIDTH BUS
    parameter PHASES        = 64, // NUMBER OF PARALLEL PHASES
    parameter PERIODICITY   = 16, // AUTO_CORRELATION PERIODICITY (# OF SAMPLES)
    parameter INT_BITS      = 0, // USED FOR DSP INTEGER PART
    parameter FRAC_BITS     = 15, // FULL_LENGTH-WORD_LEGHT = fractional PART
    parameter ARRAY_SIZE    = (DATAWIDTH * PHASES) -1,
    parameter LTF_SIZE      = 64
 )
 (
    input [ARRAY_SIZE:0]    re_i ,
    input [ARRAY_SIZE:0]    im_i ,
    input                   clk_i,
    input                   rst_i,
    output [(DATAWIDTH*2)*PHASES -1:0] crossCorrelator_o
    );
        
    localparam integer BUFFER_SHIFT_VALUE   = (LTF_SIZE-PHASES)*DATAWIDTH;
    localparam integer BUFFER_SHIFT_VALUE_2 = (PHASES-LTF_SIZE)*DATAWIDTH;
        
    wire [ARRAY_SIZE:0] re_i_reversed;
    wire [ARRAY_SIZE:0] im_i_reversed;
    genvar j;
    generate
        for (j = 0; j < PHASES; j = j + 1) begin : REVERSE_RE_I
          assign re_i_reversed[(j+1)*DATAWIDTH-1 -: DATAWIDTH] = re_i[(PHASES-j)*DATAWIDTH-1 -: DATAWIDTH];
          assign im_i_reversed[(j+1)*DATAWIDTH-1 -: DATAWIDTH] = im_i[(PHASES-j)*DATAWIDTH-1 -: DATAWIDTH];
        end
    endgenerate

    reg [(DATAWIDTH*LTF_SIZE)-1:0] input_buffer_re_reg;
    reg [(DATAWIDTH*LTF_SIZE)-1:0] input_buffer_im_reg;
    
    
    integer i1;
    generate
        if (PHASES > 64) begin : GEN_PHASE_GT_64
            always @(posedge clk_i) begin
                if (rst_i) begin
                    input_buffer_re_reg <= {(DATAWIDTH*LTF_SIZE){1'b0}};
                    input_buffer_im_reg <= {(DATAWIDTH*LTF_SIZE){1'b0}};
                end else begin
                    input_buffer_re_reg <= re_i_reversed[BUFFER_SHIFT_VALUE_2-1:0];
                    input_buffer_im_reg <= im_i_reversed[BUFFER_SHIFT_VALUE_2-1:0];
                end
            end
        end else if(PHASES == 64)begin: GEN_PHASE_EQ_64
            always @ (posedge clk_i) begin
                if(rst_i) begin
                    input_buffer_re_reg <= {(DATAWIDTH*LTF_SIZE){1'b0}};
                    input_buffer_im_reg <= {(DATAWIDTH*LTF_SIZE){1'b0}};
                end else begin
                    input_buffer_re_reg <= re_i_reversed;
                    input_buffer_im_reg <= im_i_reversed;
                end
            end
        end else begin : GEN_PHASE_LE_64
            always @(posedge clk_i) begin
                if (rst_i) begin
                    input_buffer_re_reg <= {(DATAWIDTH*LTF_SIZE){1'b0}};
                    input_buffer_im_reg <= {(DATAWIDTH*LTF_SIZE){1'b0}};
                end else begin
                    input_buffer_re_reg <= {input_buffer_re_reg[BUFFER_SHIFT_VALUE-1:0], re_i_reversed};
                    input_buffer_im_reg <= {input_buffer_im_reg[BUFFER_SHIFT_VALUE-1:0], im_i_reversed};
                end
            end
        end
    endgenerate


    wire signed [31:0] cross_correlation_output_wire [0:PHASES-1];
    
    genvar i; 
    generate 
        for(i=0;i<PHASES;i++)begin
            if(i >= 63) begin
                wire [(LTF_SIZE*DATAWIDTH)-1:0] cross_correlation_phase_re;
                wire [(LTF_SIZE*DATAWIDTH)-1:0] cross_correlation_phase_im;
                assign cross_correlation_phase_re = re_i_reversed[ARRAY_SIZE -: (i+1)*DATAWIDTH];
                assign cross_correlation_phase_im = im_i_reversed[ARRAY_SIZE -: (i+1)*DATAWIDTH];
                // PERFORM CROSS CORRELATION
                cross_correlation #( // 9 clock cycle latency. 
                    .DATAWIDTH   (DATAWIDTH   ),
                    .PHASES      (PHASES      ),
                    .PERIODICITY (PERIODICITY ),
                    .INT_BITS    (INT_BITS    ),
                    .FRAC_BITS   (FRAC_BITS   ),
                    .ARRAY_SIZE  (ARRAY_SIZE  ),
                    .LTF_SIZE    (LTF_SIZE    )
                )cross_correlation_phase(
                    .re_i(cross_correlation_phase_re),
                    .im_i(cross_correlation_phase_im),
                    .clk_i(clk_i),
                    .rst_i(rst_i),
                    .magnitude_out(cross_correlation_output_wire[i])
                );
            end else begin 
                wire [(LTF_SIZE*DATAWIDTH)-1:0] cross_correlation_phase_re;
                wire [(LTF_SIZE*DATAWIDTH)-1:0] cross_correlation_phase_im;
                assign cross_correlation_phase_re = {input_buffer_re_reg[(LTF_SIZE-(i+1))*DATAWIDTH-1:0], re_i_reversed[ARRAY_SIZE -: (i+1)*DATAWIDTH] };
                assign cross_correlation_phase_im = {input_buffer_im_reg[(LTF_SIZE-(i+1))*DATAWIDTH-1:0], im_i_reversed[ARRAY_SIZE -: (i+1)*DATAWIDTH] };

                // PERFORM CROSS CORRELATION
                cross_correlation #(
                    .DATAWIDTH   (DATAWIDTH   ),
                    .PHASES      (PHASES      ),
                    .PERIODICITY (PERIODICITY ),
                    .INT_BITS    (INT_BITS    ),
                    .FRAC_BITS   (FRAC_BITS   ),
                    .ARRAY_SIZE  (ARRAY_SIZE  ),
                    .LTF_SIZE    (LTF_SIZE    )
                )cross_correlation_phase(
                    .re_i(cross_correlation_phase_re),
                    .im_i(cross_correlation_phase_im),
                    .clk_i(clk_i),
                    .rst_i(rst_i),
                    .magnitude_out(cross_correlation_output_wire[i])
                );
                
            end
        end
    endgenerate
    
    generate
    for (i = 0; i < PHASES; i = i + 1) begin : PACK_OUTPUT
        assign crossCorrelator_o[(i+1)*32-1 : i*32] = cross_correlation_output_wire[i];//slidingAvg_va_re_wire[i][DATAWIDTH-1:0];
    end
    endgenerate
      


endmodule