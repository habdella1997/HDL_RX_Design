`timescale 1ns / 1ps



module txTop #(
    parameter PHASES   = 64,
    parameter BITWIDTH = 16,
    parameter FFTN     = 64,
    parameter CPLEN    = 16,
    parameter NUMSYM   = 12 
)(
    input clk_i,
    input rst_i,
    input enable_i,
    output [12*PHASES-1 : 0] tx_re_o,
    output [12*PHASES-1 : 0] tx_im_o
    );
    
    assign tx_re_o = (enable_i && safe_startup==40) ? data_out_re_reg:0;
    assign tx_im_o = (enable_i && safe_startup==40) ? data_out_im_reg:0;
    
    localparam integer FFTLAT = 22;
    localparam integer HEADER = 320 / PHASES;
    localparam integer DATA   = (12*80) / PHASES;
    localparam integer FFTC   = $clog2(FFTLAT);
    localparam integer HDRC   = $clog2(HEADER);
    localparam integer DATC   = $clog2(DATA)  ;
    localparam integer BOFFC  = 4;
    
       /*Safe startup just to avoid synchronizing data w/ header.... just a quick shortcut to get something up and running*/
    reg [10:0] safe_startup;
    always @(posedge clk_i)begin
        if(rst_i)begin
            safe_startup <= 0;
        end else begin
            safe_startup <= (safe_startup < 40) ? safe_startup+1:safe_startup;
        end
    end
    
    
    
    reg [FFTC-1:0] fft_counter;
    reg [HDRC-1:0] header_counter;
    reg [DATC-1:0] data_counter;
    reg [3:0]      backoff_counter;
    
    parameter IDLE = 2'b00,
              HDR  = 2'b01,
              DTA  = 2'b10,
              BOF  = 2'b11; // 3 cycle backoff to clear states;
              
    reg [1:0] state;
    
    always @(posedge clk_i)begin
        if(rst_i)begin
            state <= IDLE;
            header_counter <=0;
            data_counter <= 0;
            backoff_counter <= 0;
        end else begin
            case(state)
                IDLE: begin
                    backoff_counter <= 0;
                    state <= (enable_i && safe_startup==40) ? HDR:IDLE;
                end
                HDR:begin
                    state <= (header_counter >=HEADER-1) ? DTA:HDR;
                    header_counter <= header_counter +1;
                end
                DTA: begin
                    header_counter <= 0;
                    state <= (data_counter >= DATA-1) ? BOF:DTA;
                    data_counter <= data_counter + 1;
                end
                BOF: begin
                    data_counter <= 0;
                    state <= (backoff_counter >= BOFFC-1) ? IDLE:BOF;
                    backoff_counter <= backoff_counter + 1;
                end
            endcase
        end
    end
    
    wire [(12*PHASES)-1:0] header_symbol_re ; 
    wire [(12*PHASES)-1:0] header_symbol_im ; 
    wire header_en;
    assign header_en  = (state == HDR)  ? 1'b1:1'b0;
    genSTF #(
        .PHASES (PHASES),
        .BITWIDTH(12)
    )header_ext(
        clk_i,
        rst_i,
        header_en,
        header_symbol_re,
        header_symbol_im
        );
    
    wire[PHASES*3 -1:0] rndm_data_i,rndm_data_q;
    datagen #(
        .PHASES(PHASES),
        .WIDTH(3)
    )data_generator(
        clk_i,
        rst_i,
        1'b1,
        2'b00, // {QPSK = 0, 16-QAM = 1 , 64-QAM 2}
        rndm_data_i,
        rndm_data_q
    );
    
    wire[PHASES*16 -1:0] fft_i_i,fft_q_i;
    mapper #(
        .PHASES(PHASES),
        .WIDTH(3)
    )mapperut(
       clk_i,
       rst_i,
       1'b1,
       2'b00, // {QPSK = 0, 16-QAM = 1 , 64-QAM 2}
       rndm_data_i,
       rndm_data_q,
       fft_i_i,
       fft_q_i
    );
    
    
    wire [1407:0] fft_re_out,fft_im_out;
    wire fft_out_valid;
    wire [5:0] scale_o;
     
    fft64_v2_vu9p fft64_inst ( // 22 cycle latency , output is Q21.15
        .valid_i    (1'b1          ),       // input  wire [0:0]
        .re_i       (fft_i_i       ),          // input  wire [1023:0]
        .im_i       (fft_q_i       ),          // input  wire [1023:0]
        .clk        (clk_i         ),           // input  wire
    
        .scale_o    (scale_o       ),       // output wire [5:0]
        .valid_o    (fft_out_valid ),       // output wire [0:0]
        .im_o       (fft_im_out    ),          // output wire [1407:0]
        .re_o       (fft_re_out    )           // output wire [1407:0]
    );
    
    
    wire [12*64-1:0] fft_re_cp ;
    wire [12*64-1:0] fft_im_cp ;
    /*
        22BITS_Q7.15
        Convert Q7.15 -> Q1.11
        <<6 
        Q1.21 take MSB 12 bits. 
    */
    
    genvar x;
    generate
        for(x=0; x<64;x=x+1)begin
            wire [21:0] re_temp, im_temp;
            assign re_temp = fft_re_out[(x+1)*22 -1 -:22]<<6;
            assign im_temp = fft_im_out[(x+1)*22 -1 -:22]<<6;
            assign fft_re_cp[(x+1)*12-1 -: 12] =  (state == BOF) ? {12{1'b0}} :re_temp[21 -: 12];
            assign fft_im_cp[(x+1)*12-1 -: 12] =  (state == BOF) ? {12{1'b0}} :im_temp[21 -: 12];
        end
    endgenerate
    
    
    
//    reg [11:0] fft_re_buff [0:319];
//    reg [11:0] fft_im_buff [0:319];
//    reg [11:0] buf_addr;
//    integer cp_i;
    
//    always @(posedge clk_i)begin
//        if(rst_i)begin
//            for(cp_i=0; cp_i <320; cp_i=cp_i+1)begin
//                fft_re_buff[cp_i] <= 0 ;
//                fft_im_buff[cp_i] <= 0 ;
//            end
//            buf_addr <= 0;
//        end else begin
//            if (state == DTA)begin
//                buf_addr <= (buf_addr < 3) ? buf_addr + 1 : 0;
//            end else begin
//                buf_addr <= 0;
//            end
//            for(cp_i=0;cp_i < 80;cp_i = cp_i +1) begin
//                fft_re_buff[(buf_addr*80) + cp_i] <= (cp_i <16) ? fft_re_cp[cp_i + 48]: fft_re_cp[cp_i - 16];
//                fft_im_buff[(buf_addr*80) + cp_i] <= (cp_i <16) ? fft_im_cp[cp_i + 48]: fft_re_cp[cp_i - 16];
//            end
//        end
//    end


    reg [12*320 -1 :0] fft_re_buff;
    reg [12*320 -1 :0] fft_im_buff;
    
    reg [12*PHASES -1 :0] data_out_re_reg;
    reg [12*PHASES -1 :0] data_out_im_reg;
    
    parameter S0 = 3'b000,
              S1 = 3'b001, // Symbol 1
              S2 = 3'b010, 
              S3 = 3'b011,
              S4 = 3'b100,
              S5 = 3'b101; // Symbol 5 
    reg [2:0] data_state;
    always @(posedge clk_i)begin
        if(rst_i)begin
            data_state <= S0;
        end else begin
            case(data_state)
                S0: begin
                    data_state <= (state == DTA) ? S0:S1;
                    data_out_re_reg <=  header_symbol_re;
                    data_out_im_reg <= header_symbol_im;
                end
                S1:begin
                    data_state <= (state == HDR) ? S0:S2;
                    fft_re_buff[959:0] <=  {fft_re_cp, fft_re_cp[64*12-1 -: 16*12]};
                    fft_im_buff[959:0] <=  {fft_im_cp, fft_im_cp[64*12-1 -: 16*12]};
                    data_out_re_reg    <=  {fft_re_cp[48*12-1:0] , fft_re_cp[64*12-1 -: 16*12]}; // CP_SYM1, SYM1[0:48]
                    data_out_im_reg    <=  {fft_im_cp[48*12-1:0] , fft_im_cp[64*12-1 -: 16*12]};  
                end
                S2: begin
                    data_state <= (state == HDR) ? S0:S3;
                    fft_re_buff[1919:960] <=  {fft_re_cp, fft_re_cp[64*12-1 -: 16*12]};
                    fft_im_buff[1919:960] <=  {fft_im_cp, fft_im_cp[64*12-1 -: 16*12]};
                    data_out_re_reg       <=  {fft_re_cp[32*12-1:0],fft_re_cp[64*12-1 -: 16*12],fft_re_buff[959 -: 192]}; // SYM1[49:64], CP_SYM2, SYM2[0:32]
                    data_out_im_reg       <=  {fft_re_cp[32*12-1:0],fft_re_cp[64*12-1 -: 16*12],fft_re_buff[959 -: 192]};
                end
                S3: begin
                    data_state <= (state == HDR) ? S0:S4;
                    fft_re_buff[2879:1920] <= {fft_re_cp, fft_re_cp[64*12-1 -: 16*12]};
                    fft_im_buff[2879:1920] <= {fft_im_cp, fft_im_cp[64*12-1 -: 16*12]};
                    data_out_re_reg        <= {fft_re_cp[16*12-1:0],fft_re_cp[64*12-1 -: 16*12],fft_re_buff[1919 -: 384] }; //SYM2[33:64], SYM3_CP, SYM3[0:16]
                    data_out_im_reg        <= {fft_im_cp[16*12-1:0],fft_im_cp[64*12-1 -: 16*12],fft_im_buff[1919 -: 384] };
                end
                S4: begin
                    data_state <= (state == HDR) ? S0:S5;
                    fft_re_buff[3839:2880] <= {fft_re_cp, fft_re_cp[64*12-1 -: 16*12]};
                    fft_im_buff[3839:2880] <= {fft_im_cp, fft_im_cp[64*12-1 -: 16*12]};
                    data_out_re_reg        <= {fft_re_cp[64*12-1 -: 16*12],fft_re_buff[2879 -: 576] }; //SYM3[17:64], SYM4CP
                    data_out_im_reg        <= {fft_im_cp[64*12-1 -: 16*12],fft_im_buff[2879 -: 576] }; 
                end
                S5: begin
                    data_state <= (state == HDR) ? S0:S1;
                    data_out_re_reg <= fft_re_buff[3839 -: 768]; //SYM 4
                    data_out_im_reg <= fft_im_buff[3839 -: 768];
                end
            endcase
        end
    end 

    /*
       SYM 1 -> 2 -> 3 -> 4   [4]
       SYM 1 -> 2 -> 3 -> 4   [4]
       SYM 1 -> 2 -> 3 -> 4   [4] 
       3 Iterations of the state machine. 
    */
endmodule
