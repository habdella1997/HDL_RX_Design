`timescale 1ns / 1ps


module rxTop#(
    parameter DATAWIDTH     = 16, // DATA WIDTH BUS
    parameter PHASES        = 64, // NUMBER OF PARALLEL PHASES
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
    wire valid_synchronized_wire;
    
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
    
    localparam integer FFTSIZE        = 64;
    localparam integer DATASYMBOLS    = 12;
    localparam integer CPLENGTH       = 16;
    localparam integer SYMBOLS        = (320 + (FFTSIZE+CPLENGTH)*DATASYMBOLS) / FFTSIZE ; //HEADER(320) + (64+16)*12 - Modules only run with Sybols being an integer of FFT SIZE. 
    localparam integer DATASAMPLESMAX = 320 + (DATASYMBOLS * (FFTSIZE + CPLENGTH));
    localparam integer SYMTOPBOUND    = DATAWIDTH * FFTSIZE;
    localparam integer SHIFT          = (FFTSIZE - PHASES) * DATAWIDTH;
    localparam integer CPSHIFT        = (FFTSIZE - CPLENGTH) * DATAWIDTH;
    localparam integer CPSHIFT_NS     = (CPLENGTH * DATAWIDTH);
    localparam integer DS_BUF16       = 80;  //lowest common denominator of (PHASES=16, Data Symbol Size = 80 (64+16CP))=80
    localparam integer DS_BUF64       = 320; //lowest common denominator of (PHASES=64, Data Symbol Size = 80 (64+16CP))=320
    localparam integer DS_BUF16_CNTR  = DS_BUF16 / PHASES;
    localparam integer DS_BUF64_CNTR  = DS_BUF64 / PHASES;
    /*  
    Grab data and store on a 64 sample register. 
    */
    
    reg [DATAWIDTH*FFTSIZE - 1:0] re_symbol_reg;
    reg [DATAWIDTH*FFTSIZE - 1:0] im_symbol_reg;
    reg [10:0] symbol_counter; //11 bits should be fine to avoid overflow
    reg [14:0] sample_counter;

    
    always @ (posedge clk_i) begin
        if(PHASES < 64) begin
            re_symbol_reg <= {data_synchronized_re_wire , re_symbol_reg[SYMTOPBOUND-1 -:SHIFT ]}; // right shift samples.
            im_symbol_reg <= {data_synchronized_im_wire , im_symbol_reg[SYMTOPBOUND-1 -:SHIFT ]};
        end else begin
            re_symbol_reg <= data_synchronized_re_wire;
            im_symbol_reg <= data_synchronized_im_wire;
        end
    end

    parameter IDLE = 2'b00,
              STF  = 2'b01,
              LTF  = 2'b10,
              DATA = 2'b11;

    reg [1:0] rxState;
    reg [11:0] dSCounter;
    always @ (posedge clk_i) begin
        if(rst_i)begin
            rxState <= IDLE;
            sample_counter <= 0;
            symbol_counter <= 0;
            dSCounter <= 0;
        end else begin
            if(rxState == IDLE)
                symbol_counter <= 0;
            else begin
                symbol_counter <= (sample_counter[5:0] == 6'b0) ? symbol_counter+1 : symbol_counter;
            end    
            case(rxState)
                IDLE: begin
                    rxState <= (valid_synchronized_wire) ? STF:IDLE;
                    sample_counter <= (valid_synchronized_wire) ? PHASES :0 ; 
                end
                STF: begin
                    rxState <= (sample_counter >= (160 - PHASES)) ? LTF:STF;
                    sample_counter <= sample_counter + PHASES;
                end
                LTF: begin
                    rxState <= (sample_counter >= (320 -PHASES)) ? DATA:LTF;
                    sample_counter <= sample_counter + PHASES;
                end
                DATA: begin
                    rxState <= (sample_counter >= (DATASAMPLESMAX -PHASES)) ? IDLE:DATA;
                    sample_counter <= sample_counter + PHASES;
                end
            endcase
        end
    end
  
    parameter S0 = 2'b00,
              S1 = 2'b01,
              S2 = 2'b10,
              S3 = 2'b11;
    reg [1:0] dExt_state;
    integer idx2, idx3,idx4,idx5;
    always @ (posedge clk_i) begin
        if(rst_i) begin
            dExt_state <= S0;
        end else begin
            case (dExt_state)
                S0: begin
                    dExt_state <= (symValid[79]) ? S1:S0; // 79 -> 16 Samples CP + 64 Data -> 80th index. 80-1 = 79
                    d_ready    <= (symValid[79]) ? 1'b1:1'b0;
                    for(idx2 = 0 ; idx2 < 64; idx2 = idx2 + 1)begin
                        re_data_symbol[(idx2+1)*DATAWIDTH -1 -: DATAWIDTH] <= re_data_symbol_buff[idx2+16];
                        im_data_symbol[(idx2+1)*DATAWIDTH -1 -: DATAWIDTH] <= im_data_symbol_buff[idx2+16];
                    end
                end
                S1: begin 
                    dExt_state <= (symValid[159]) ? S2:S1; // 80 + 80 = 160 - 1 = 159 end of symbol 2. 
                    d_ready    <= (symValid[159]) ? 1'b1:1'b0;
                    for(idx3 = 0 ; idx3 < 64; idx3 = idx3 + 1)begin
                        re_data_symbol[(idx3+1)*DATAWIDTH -1 -: DATAWIDTH] <= re_data_symbol_buff[idx3+96];
                        im_data_symbol[(idx3+1)*DATAWIDTH -1 -: DATAWIDTH] <= im_data_symbol_buff[idx3+96];
                    end
                end
                S2: begin 
                    dExt_state <= (symValid[239]) ? S3:S2;
                    d_ready    <= (symValid[239]) ? 1'b1:1'b0;
                    for(idx4 = 0 ; idx4 < 64; idx4 = idx4 + 1)begin
                        re_data_symbol[(idx4+1)*DATAWIDTH -1 -: DATAWIDTH] <= re_data_symbol_buff[idx4+176];
                        im_data_symbol[(idx4+1)*DATAWIDTH -1 -: DATAWIDTH] <= im_data_symbol_buff[idx4+176];
                    end
                end
                S3: begin 
                    dExt_state <= (symValid[319]) ? S0:S3;
                    d_ready    <= (symValid[319]) ? 1'b1:1'b0;
                    for(idx5 = 0 ; idx5 < 64; idx5 = idx5 + 1)begin
                        re_data_symbol[(idx5+1)*DATAWIDTH -1 -: DATAWIDTH] <= re_data_symbol_buff[idx5+256];
                        im_data_symbol[(idx5+1)*DATAWIDTH -1 -: DATAWIDTH] <= im_data_symbol_buff[idx5+256];
                    end
                end
            endcase
        end
    end
    
    reg [DATAWIDTH-1:0] re_data_symbol_buff  [ 0 :DS_BUF64-1];
    reg [DATAWIDTH-1:0] im_data_symbol_buff  [ 0 :DS_BUF64-1];
    
    reg [DATAWIDTH*FFTSIZE-1:0] re_data_symbol ;
    reg [DATAWIDTH*FFTSIZE-1:0] im_data_symbol ;
    
    reg [DS_BUF64-1:0]  symValid;
    reg d_ready;
    

    reg [12:0] wr_ptr;
    integer idx;

    always @ (posedge clk_i) begin
        if(rst_i)begin
            wr_ptr <= {13{1'b0}};
            symValid <= {DS_BUF64{1'b0}};
        end else begin
            if(rxState == DATA) begin
                for(idx=0;idx<PHASES;idx=idx+1)begin
                    re_data_symbol_buff[wr_ptr + idx] <= data_synchronized_re_wire[(idx+1)*DATAWIDTH-1 -: DATAWIDTH];
                    im_data_symbol_buff[wr_ptr + idx] <= data_synchronized_im_wire[(idx+1)*DATAWIDTH-1 -: DATAWIDTH];
                end
                wr_ptr <= (wr_ptr+PHASES >= DS_BUF64) ? {13{1'b0}} : wr_ptr + PHASES;
                if(wr_ptr == 0 ) begin
                    symValid <= {{(DS_BUF64-PHASES){1'b0}} , {PHASES{1'b1}}};
                end else begin
                    symValid <= symValid << PHASES;
                end
            end else begin
                wr_ptr <= 0;
                symValid <= {(DS_BUF64){1'b0}};
            end
        end
    end

    wire [DATAWIDTH*FFTSIZE -1 : 0 ] LTF_SYM_re;
    wire [DATAWIDTH*FFTSIZE -1 : 0 ] LTF_SYM_im;
    wire ch_ready; 

    assign LTF_SYM_re = (sample_counter == 320) ? re_symbol_reg : {DATAWIDTH*FFTSIZE{1'b0}};
    assign LTF_SYM_im = (sample_counter == 320) ? im_symbol_reg : {DATAWIDTH*FFTSIZE{1'b0}};
    assign ch_ready   = (sample_counter == 320) ? 1'b1: 1'b0;
    
    parameter LTF_FFT  = 1'b0,
              DATA_FFT = 1'b1;
    reg  fft_state;
    reg [8:0] DATA_Valid_counter;
    always @ (posedge clk_i) begin
        if(rst_i) begin
            fft_state <= LTF_FFT;
        end else begin
            case(fft_state)
                LTF_FFT: begin
                    DATA_Valid_counter <= 0 ;
                    fft_state <= (ch_ready) ?  DATA_FFT:LTF_FFT;
                end
                DATA_FFT: begin
                    DATA_Valid_counter <= (d_ready) ? DATA_Valid_counter+1 : DATA_Valid_counter;
                    fft_state <= (DATA_Valid_counter >= DATASYMBOLS) ? LTF_FFT:DATA_FFT;
                end
            endcase
        end
    end
    
    
    wire [DATAWIDTH*FFTSIZE - 1:0] fft_in_re, fft_in_im;
    wire fft_in_valid;
    
    assign fft_in_re    = (fft_state == LTF_FFT)   ? re_symbol_reg: re_data_symbol;
    assign fft_in_im    = (fft_state == LTF_FFT)   ? im_symbol_reg: im_data_symbol;
    assign fft_in_valid = (fft_state == LTF_FFT)   ? ch_ready     : d_ready;

    wire [1407:0] fft_re_out,fft_im_out;
    wire fft_out_valid;
    wire [5:0] scale_o;
     
    fft64_v2_vu9p fft64_inst ( // 22 cycle latency , output is Q21.15
        .valid_i    (fft_in_valid  ),       // input  wire [0:0]
        .re_i       (fft_in_re     ),          // input  wire [1023:0]
        .im_i       (fft_in_im     ),          // input  wire [1023:0]
        .clk        (clk_i         ),           // input  wire
    
        .scale_o    (scale_o       ),       // output wire [5:0]
        .valid_o    (fft_out_valid ),       // output wire [0:0]
        .im_o       (fft_im_out    ),          // output wire [1407:0]
        .re_o       (fft_re_out    )           // output wire [1407:0]
    );
    
    
    parameter LTF_FFT_OUT  = 1'b0,
              DATA_FFT_OUT = 1'b1;
    reg  fft_state_out;
    reg [8:0] DATA_Valid_counter_out;
    always @ (posedge clk_i) begin
        if(rst_i) begin
            fft_state_out <= LTF_FFT_OUT;
        end else begin
            case(fft_state_out)
                LTF_FFT_OUT: begin
                    DATA_Valid_counter_out <= 0 ;
                    fft_state_out <= (fft_out_valid) ?  DATA_FFT_OUT:LTF_FFT_OUT;
                end
                DATA_FFT_OUT: begin
                    DATA_Valid_counter_out <= (fft_out_valid) ? DATA_Valid_counter_out+1 : DATA_Valid_counter_out;
                    fft_state_out <= (DATA_Valid_counter_out >= DATASYMBOLS) ? LTF_FFT_OUT:DATA_FFT_OUT;
                end
            endcase
        end
    end
    /*
        wire [1407:0] fft_re_out,fft_im_out;
    wire fft_out_valid;
    */
    wire [1407:0] ch_fft_re_out, ch_fft_im_out;
    wire ch_fft_out_valid;
    
    assign ch_fft_re_out = (fft_state_out == LTF_FFT_OUT) ? fft_re_out : {1408{1'b0}};
    assign ch_fft_im_out = (fft_state_out == LTF_FFT_OUT) ? fft_im_out : {1408{1'b0}};
    assign ch_fft_out_valid = (fft_state_out == LTF_FFT_OUT) ? fft_out_valid : 1'b0;
    
    
    wire [1407:0] da_fft_re_out, da_fft_im_out;
    wire da_fft_out_valid;
    
    assign da_fft_re_out    = (fft_state_out == DATA_FFT_OUT) ? fft_re_out : {1408{1'b0}};
    assign da_fft_im_out    = (fft_state_out == DATA_FFT_OUT) ? fft_im_out : {1408{1'b0}};
    assign da_fft_out_valid = (fft_state_out == DATA_FFT_OUT) ? fft_out_valid : 1'b0;
    
    
    wire [(22*64)-1:0] channel_re_wire;
    wire [(22*64)-1:0] channel_im_wire; // 23 cycle delay.
    wire channel_estimation_valid; 

    channel_estimation #(
        .DATAWIDTH      (DATAWIDTH               ),
        .PHASES         (PHASES                  ),
        .LTF_SIZE       (64                      )
    ) channel_est_uut(
        .clk_i          (clk_i                   ),
        .rst_i          (rst_i                   ),
        .re_i           (ch_fft_re_out           ),
        .im_i           (ch_fft_im_out           ),
        .valid_i        (ch_fft_out_valid        ),
        .channel_re_o   (channel_re_wire         ),
        .channel_im_o   (channel_im_wire         ),
        .channel_valid_o(channel_estimation_valid)
    );
    
    equalizer #(
        .DATAWIDTH          (DATAWIDTH                ),
        .PHASES             (PHASES                   ),
        .FFT                (FFTSIZE                  ),
        .CPLEN              (CPLENGTH                 )
    ) ch_eq_inst(
        .clk_i              (clk_i                    ),
        .rst_i              (rst_i                    ),
        .datasymbolre_i     (da_fft_re_out            ),
        .datasymbolim_i     (da_fft_im_out            ),
        .channelre_i        (channel_re_wire          ),
        .channelim_i        (channel_im_wire          ),
        .channel_est_valid_i(channel_estimation_valid ),
        .datasymbol_valid_i (da_fft_out_valid         ),
        .eq_datare_o        (eqDataRe_o               ),
        .eq_dataim_o        (eqDataIM_o               ),
        .eq_valid_o         (eqValid_o                )
    );

    
endmodule
