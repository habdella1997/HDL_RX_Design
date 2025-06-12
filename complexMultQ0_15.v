`timescale 1ns / 1ps

// 4 clock cylce latency -> Complex mult
module complexMultQ0_15 #(
    parameter DATAWIDTH     = 16, // DATA WIDTH BUS
    parameter INT_BITS      = 0, // USED FOR DSP INTEGER PART
    parameter FRAC_BITS     = 15 // FULL_LENGTH-WORD_LEGHT = fractional PART
)
(
    input signed [DATAWIDTH-1:0] re_val1_i,
    input signed [DATAWIDTH-1:0] re_val2_i,
    input signed [DATAWIDTH-1:0] im_val1_i,
    input signed [DATAWIDTH-1:0] im_val2_i,
    input conjugate,
    input clk, 
    output signed [DATAWIDTH-1:0] re_o,
    output signed [DATAWIDTH-1:0] im_o
    );
    
    localparam integer MULTOUT_WIDTH = 80; // grab from ip
    localparam integer COEFF_WIDTH = MULTOUT_WIDTH / 2;
    
    wire signed [MULTOUT_WIDTH-1:0] result_tdata;
    wire signed [DATAWIDTH-1:0] conjugated_im;
    assign conjugated_im = (conjugate) ? -1*im_val2_i:im_val2_i;
    // Instantiate the IP core
    cmpy_0 cmpy_inst (
        // Clock & control
        .aclk               (clk), 
        // Input A (S_AXIS_A)
        .s_axis_a_tdata     ({im_val1_i,re_val1_i}),
        .s_axis_a_tvalid    (1'b1),
        // Input B (S_AXIS_B)
        .s_axis_b_tdata     ({conjugated_im,re_val2_i}),
        .s_axis_b_tvalid    (1'b1),
        // Output
        .m_axis_dout_tdata  (result_tdata),
        .m_axis_dout_tvalid ()
    );
    
    wire signed [COEFF_WIDTH-1:0] output_re_wire;
    wire signed [COEFF_WIDTH-1:0] output_im_wire;
    
    assign output_re_wire = result_tdata[COEFF_WIDTH-1:0];
    assign output_im_wire = result_tdata[MULTOUT_WIDTH-1:COEFF_WIDTH];
//    assign re_o = (output_re_wire >>> FRAC_BITS);
//    assign im_o = (output_im_wire >>> FRAC_BITS);
    
    wire signed [COEFF_WIDTH-1:0] re_shifted = output_re_wire >>> FRAC_BITS;
    wire signed [COEFF_WIDTH-1:0] im_shifted = output_im_wire >>> FRAC_BITS;
    assign re_o = (re_shifted > 32767) ? 32767 :
                  (re_shifted < -32768) ? -32768 : re_shifted;
    assign im_o = (im_shifted > 32767) ? 32767 :
                  (im_shifted < -32768) ? -32768 : im_shifted;
   
endmodule