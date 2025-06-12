`timescale 1ns / 1ps

module pd_tb;

    parameter DATAWIDTH = 16;
    parameter PHASES = 16;
    parameter PERIODICITY = 16;
    parameter INT_BITS = 0;
    parameter FRAC_BITS = 15;
    parameter ARRAY_SIZE = (DATAWIDTH * PHASES) - 1;
    parameter TOTAL_SAMPLES = 15470;

    // DUT signals
    reg clk_i = 0;
    reg rst_i = 1;
    reg [ARRAY_SIZE:0] re_i;
    reg [ARRAY_SIZE:0] im_i;
    wire [PHASES-1:0] detection_o;
    wire [(32*PHASES)-1:0] var_o;
    wire [(32*PHASES)-1:0] ac_o;
    wire [0:PHASES-1] threshold_cmpr;
    
    // Instantiate DUT
//    packetDetector #(
//        .DATAWIDTH(DATAWIDTH),
//        .PHASES(PHASES),
//        .PERIODICITY(PERIODICITY),
//        .INT_BITS(INT_BITS),
//        .FRAC_BITS(FRAC_BITS)
//    ) dut (
//        .re_i(re_i),
//        .im_i(im_i),
//        .clk_i(clk_i),
//        .rst_i(rst_i),
//        .detection_o(detection_o),
//        .var_o(var_o),
//        .auto_corr_o(ac_o),
//        .threshold_decision_o(threshold_cmpr)
//    );
    
    rxTop
 #(
        .DATAWIDTH(DATAWIDTH),
        .PHASES(PHASES),
        .PERIODICITY(PERIODICITY),
        .INT_BITS(INT_BITS),
        .FRAC_BITS(FRAC_BITS)
 )dut_2
 (
        .re_i(re_i),
        .im_i(im_i),
        .clk_i(clk_i),
        .rst_i(rst_i)
        //.crossCorrelator_o(var_o)
    );
    
    

    // Clock generation
    always #5 clk_i = ~clk_i;

    // Input storage
    reg [15:0] re_mem [0:TOTAL_SAMPLES-1];
    reg [15:0] im_mem [0:TOTAL_SAMPLES-1];
    integer sample_index = 0;
    integer file_out;

   initial begin
    $readmemh("re_q15.mem", re_mem);
    $readmemh("im_q15.mem", im_mem);
    file_out = $fopen("var_ac.txt", "w");

    #20 rst_i = 0;
end

always @ (posedge clk_i) begin
    if(rst_i) begin
        sample_index <= 0;
    end else begin
        sample_index <= ( (sample_index + PHASES) > (TOTAL_SAMPLES+64) ) ? 0 : (sample_index + PHASES);
    end
end


always_ff @(posedge clk_i) begin
    if (!rst_i) begin
        for (int i = 0; i < PHASES; i++) begin
            if( (sample_index+i) < TOTAL_SAMPLES) begin
                re_i[(i+1)*DATAWIDTH -1 -: DATAWIDTH]  <= re_mem[sample_index + i];
                im_i[(i+1)*DATAWIDTH -1 -: DATAWIDTH]  <= im_mem[sample_index + i];
            end else begin
                re_i[(i+1)*DATAWIDTH -1 -: DATAWIDTH] <= {DATAWIDTH{1'b0}};
                im_i[(i+1)*DATAWIDTH -1 -: DATAWIDTH] <= {DATAWIDTH{1'b0}};
            end
        end
        $fwrite(file_out, "%h,%h,%h\n", var_o,ac_o,threshold_cmpr);
    end else begin
        re_i <= {(ARRAY_SIZE+1){1'b0}};
        im_i <= {(ARRAY_SIZE+1){1'b0}};
    end
end


//always_ff @(posedge clk_i) begin
//    if (!rst_i) begin
//        for (int i = 0; i < PHASES; i++) begin
//            re_i[(i+1)*DATAWIDTH -1 -: DATAWIDTH] <= re_mem[(sample_index + i) % TOTAL_SAMPLES];
//            im_i[(i+1)*DATAWIDTH -1 -: DATAWIDTH] <= im_mem[(sample_index + i) % TOTAL_SAMPLES];
//        end
//        sample_index <= (sample_index + PHASES) % TOTAL_SAMPLES;

//        $fwrite(file_out, "%h,%h,%h\n", var_o,ac_o,threshold_cmpr);
//    end else begin
//        re_i <= {(ARRAY_SIZE+1){1'b0}};
//        im_i <= {(ARRAY_SIZE+1){1'b0}};
//    end
//end

endmodule
