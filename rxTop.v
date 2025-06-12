`timescale 1ns / 1ps


module rxTop#(
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
    input                   rst_i
    );
    
    /* 
    Packet Detection: 
    INPUT: re_i Q0.15, im_i Q0.15, rst_i <active high>, 
    OUTPUT: threshold_decision_0: a 1 bit for every phase indicating packet detection or not
    LATENCY:
        1. Complex Multipication: 4 Cycles
        2. Pipeline(1-Stage) Pre-adder: 1 Cycle
        3. Sliding Average: 1Cycle / Layer -> Layers=log2(PHASES)
            ** You are feeding a register to the output of adder so could be 2cycle/layer
        4. Multiplier: 3-Cycles. A^2, Var^2
        5. Variance Mult: 3-cycles: Var^2 * Threshold
              (Ac_re + AC_im 1 cycle, delay 2 = matched with Variance. 
    Total Latency:
        4Cycles + 1Cycle + 1*log2(PHASES) + 3 + 3 = 11 + Log2(PHASES)
    */
    
    wire [0:PHASES-1] pd_threshold_output_wire;
    packetDetector #(
        .DATAWIDTH  (DATAWIDTH  ),    
        .PHASES     (PHASES     ),
        .PERIODICITY(PERIODICITY),
        .INT_BITS   (INT_BITS   ),
        .FRAC_BITS  (FRAC_BITS  ),
        .ARRAY_SIZE (ARRAY_SIZE )
    ) pd_module_inst(
        .re_i                (re_i                    ),
        .im_i                (im_i                    ),
        .clk_i               (clk_i                   ),
        .rst_i               (rst_i                   ),
        .threshold_decision_o(pd_threshold_output_wire)
    );
    
    /*
        Timing Acquisiton: 
        Input: Same as PD.
        Output: Cross Correlation Output Values Q12.19
            1. Summation Tree: 1Clock Cycle / Layer. Layers = log2(64)
            2. Complex Subtraction/Addition 1 Cycle
            3. Magnitude 1 Cycle
            4. Summation: 1 cycle. 
        Total Latency : 3 Cycles + 6 Cycles = 9 Cycles Independent of Phase. 
    
    */
    wire [(DATAWIDTH*2)*PHASES -1:0] tacq_crossCorrelation_output_wire;
    timing_acq#(
        .DATAWIDTH  (DATAWIDTH  ),        
        .PHASES     (PHASES     ),
        .PERIODICITY(PERIODICITY),
        .INT_BITS   (INT_BITS   ),
        .FRAC_BITS  (FRAC_BITS  ),
        .ARRAY_SIZE (ARRAY_SIZE )
    )taq_module_isnt(
        .re_i(re_delay_4_wire),
        .im_i(im_delay_4_wire),
        .clk_i(clk_i),
        .rst_i(rst_i),
        .crossCorrelator_o(tacq_crossCorrelation_output_wire)
    );
    
    
    
    /*
        Delay Data Bus:
        PD_FLAG_Latency ---> 11 + Log2(PHASES)
        Tacq_Latency    ---> 9 Cycle.
        Tacq_Search     ---> log2(PHASES) Cycle. 
        Delay Timing ACQ by their latency diff + 1; -> 11-9 = 2+1 = 3+1 = 4;
    */
    localparam integer latency_mismatch_tac_timing = 3;
    reg [ARRAY_SIZE:0] re_delay_1, im_delay_1, re_delay_2, im_delay_2, re_delay_3, im_delay_3,re_delay_4, im_delay_4;
    always @(posedge clk_i)begin
        re_delay_1 <= re_i;
        re_delay_2 <= re_delay_1;
        re_delay_3 <= re_delay_2;
        re_delay_4 <= re_delay_3;
        im_delay_1 <= im_i;
        im_delay_2 <= im_delay_1;
        im_delay_3 <= im_delay_2;
        im_delay_4 <= im_delay_3;
    end
    wire [ARRAY_SIZE:0] re_delay_4_wire, im_delay_4_wire; 
    assign re_delay_4_wire = re_delay_4;
    assign im_delay_4_wire = im_delay_4;
    
    
    /*
        Delay DATA BUS BY the amount incurred by timing acquisition.  
        9 + log2(PHASES). 
    */
    
    reg [ARRAY_SIZE:0] re_delay_line [0:DATA_LINE_DELAY-1];
    reg [ARRAY_SIZE:0] im_delay_line [0:DATA_LINE_DELAY-1];
    
    wire[ARRAY_SIZE:0] re_packet_delayed_wire;
    wire[ARRAY_SIZE:0] im_packet_delayed_wire;
    
    wire[ARRAY_SIZE:0] re_packet_delayed_wire_early; 
    wire[ARRAY_SIZE:0] im_pakcet_delayed_wire_early;
    
    always @ (posedge clk_i) begin
        re_delay_line[0] <= re_i;
        im_delay_line[0] <= im_i;
    end
    
    genvar k;
    generate
        for(k = 1; k<DATA_LINE_DELAY; k = k + 1) begin
            always @ (posedge clk_i) begin
                re_delay_line[k] <= re_delay_line[k-1];
                im_delay_line[k] <= im_delay_line[k-1];
            end
        end
    endgenerate
    
    assign re_packet_delayed_wire = re_delay_line[DATA_LINE_DELAY-1];
    assign im_packet_delayed_wire = im_delay_line[DATA_LINE_DELAY-1];
    assign re_packet_delayed_wire_early = re_delay_line[DATA_LINE_DELAY-2];
    assign im_packet_delayed_wire_early = im_delay_line[DATA_LINE_DELAY-2];
    
    
    
    /*
        Detect and Flag an incoming Packet. 
        We are comparing against finding 16 consecutive high bits in the detection. 
        If SNR is low, a bit might drop, and thus we wont detect a packet for another 16 phases. 
        Even at very low SNR, 16 consecuitive high bits should be found somewhere in the duration of the STF.
        Now in the case of PHASES > 16 we need to slice that wire into 16 bit interval and check for 16'FFFF. 
        STF PATTERN -> 0xFFFF 0xFFFF 0xFFFF ... 0xFFFFF   Should last 10 cycles so you are guranteed to find it. 
        This Method should work for SNR > 8dB roguhly. anything under might cause instability. Anyhow, to decode a QPSK you
        need atleast ~12 dB SNR.
    */
    
    localparam integer pd_windows = PHASES >> 4; // Divide by 16;
    wire [pd_windows-1:0] pd_threshold_flags ;
    genvar pd_refactor_i;
    generate
        for(pd_refactor_i = 0; pd_refactor_i < pd_windows; pd_refactor_i=pd_refactor_i+1)begin
            assign pd_threshold_flags[pd_refactor_i] = 
                    (pd_threshold_output_wire[((pd_refactor_i+1)*16)-1 -: 16] >= 16'hFFFF)?1'b1:1'b0;
        end
    endgenerate
    
    reg packet_detected;
    reg packet_detection_late;
    reg alert_system;
    always @ (posedge clk_i) begin
        if(rst_i)begin
            packet_detected <= 1'b0;
            alert_system <= 1'b0; packet_detection_late <= 1'b0;
        end else begin
            packet_detection_late <= (pd_threshold_output_wire > 1) ? 1'b1:1'b0;
            if(|pd_threshold_flags) begin
                packet_detected <= 1'b1;
                if(packet_detection_late)
                    alert_system <= 1'b1;
                else 
                    alert_system <= 1'b0;
            end else begin
                packet_detected <= 1'b0;
            end
        end
    end
    
    
    /*
        RX Main State Machine
    */
    
    parameter IDLE                  = 4'b0000,
              PD_FLAG               = 4'b0001,
              TACQ_SEARCH           = 4'b0010,
              ADDRESS_COMPUTATION   = 4'b0011,
              DATA_EXTRACTION       = 4'b0100;
    
    localparam integer PD_LATENCY            = 11 + $clog2(PHASES);  
    localparam integer TACQ_LATENCY          = 13 + $clog2(PHASES); // Added an +4 intential delay added at the start 
    localparam integer STF_2_LTF_DIFF        = 160/PHASES; //automatically gets floored by synth.    
    
    localparam integer PD_FLAG_ASSERTION_LAT = 1; // asserting the PD flag REGISTER consumes 1 clock cycle;
    localparam integer STATE_TRANSITION_LAT  = 1; // lcycle state transtion
        
    localparam integer LTF_START_BOUNDARY = (STF_2_LTF_DIFF + TACQ_LATENCY) - (PD_LATENCY + PD_FLAG_ASSERTION_LAT+STATE_TRANSITION_LAT+STATE_TRANSITION_LAT);
    localparam integer LTF_STOP_BOUNDARY  = ((160+PHASES-1)/PHASES) + 1; //x+y-1/y <=> ceil(x/y) , 1 is grace period for late detection
    
    localparam integer IDLE_STATE_DURATION  = PD_LATENCY + PD_FLAG_ASSERTION_LAT + STATE_TRANSITION_LAT; //computing the PD, Asserting the PD reg, and state transition reg.
    localparam integer PD_STATE_DURATION    = LTF_START_BOUNDARY + STATE_TRANSITION_LAT;
    localparam integer TA_STATE_DURATION    = LTF_STOP_BOUNDARY + STATE_TRANSITION_LAT;
    
    localparam integer DATA_LINE_DELAY    = IDLE_STATE_DURATION+PD_STATE_DURATION+TA_STATE_DURATION+4;
    localparam integer CP_LENGTH          = 16;
    localparam integer DATA_SYMB          = 12;
    localparam integer FFT_SIZE           = 64;
    localparam integer DATA_SIZE          = (FFT_SIZE + CP_LENGTH) * DATA_SYMB;
    localparam integer DATA_CYCLES        = (DATA_SIZE + PHASES -1) / PHASES;
    localparam integer HEADER_CYCLES      = (320 + PHASES - 1) / PHASES; 
    localparam integer PACKET_SIZE        = DATA_CYCLES + HEADER_CYCLES;
    localparam integer ADDR_SHIFT         = $clog2(PHASES); 
    localparam integer COUNTER_WIDTH      = 32;
    localparam integer LTF_END_DEFINED_CYCLE = (320/PHASES) ;
    
    reg [3:0] rx_state_current;
    reg [$clog2(LTF_START_BOUNDARY):0] pd_2_ltf_counter;
    reg [$clog2(LTF_STOP_BOUNDARY):0] ltf_duration_counter;
    
    reg [$clog2(PACKET_SIZE)  :0] global_counter;
    
    reg [$clog2(PHASES)-1:0]            LTF_boundary_index_selected;
    reg signed [(DATAWIDTH*2)-1 :0]     LTF_boundary_value_selected;
    reg [31:0]                          LTF_boundary_clock_selected;

    reg [COUNTER_WIDTH-1:0] STF_START;
    reg [COUNTER_WIDTH-1:0] STF_END;
    reg [COUNTER_WIDTH-1:0] LTF_START;
    reg [COUNTER_WIDTH-1:0] LTF_END;
    reg [COUNTER_WIDTH-1:0] DATA_START;
    reg [COUNTER_WIDTH-1:0] DATA_END;
    
    reg        packet_valid_flag;
    
    parameter PACKET_IDLE                     = 1'b0,
              PACKET_ACTIVE                   = 1'b1;

    reg [1:0] extraction_state; 
    
    wire [DATAWIDTH-1:0] data_extraction_line_re_wire [0:PHASES-1];
    reg  [DATAWIDTH-1:0] data_extraction_line_re_regz [0:PHASES-1];
    genvar d_extract_i;
    integer d_extract_reg_i;
    generate
        for(d_extract_i=0;d_extract_i<PHASES;d_extract_i=d_extract_i+1)begin
            assign data_extraction_line_re_wire[d_extract_i] = (alert_system) ? re_packet_delayed_wire[(d_extract_i+1)*DATAWIDTH-1 -: DATAWIDTH]:
                                                                                re_packet_delayed_wire_early[(d_extract_i+1)*DATAWIDTH-1 -: DATAWIDTH]    ;
        end
    endgenerate
    
    always @ (posedge clk_i) begin
        if(rst_i) begin
            extraction_state <= PACKET_IDLE;
            sym_valid <= {PHASES{1'b0}};
            sym_counter <= {COUNTER_WIDTH{1'b0}};
        end else begin
            for(d_extract_reg_i=0;d_extract_reg_i<PHASES;d_extract_reg_i=d_extract_reg_i+1)begin
                data_extraction_line_re_regz[d_extract_reg_i] <= data_extraction_line_re_wire[d_extract_reg_i];
            end
            case(extraction_state) 
                PACKET_IDLE: begin
                    extraction_state <= (packet_valid_flag) ? PACKET_ACTIVE:PACKET_IDLE;
                    sym_valid <= {PHASES{1'b0}};
                    sym_counter <= {COUNTER_WIDTH{1'b0}};
                end
                PACKET_ACTIVE: begin
                    sym_counter <= sym_counter + 1;
                    extraction_state <= (sym_counter > (DATA_END >> ADDR_SHIFT)) ? PACKET_IDLE:PACKET_ACTIVE;
                    if(sym_counter == (STF_START >> ADDR_SHIFT)) begin // Sample 0 -> 0, Sample 15->0 , bit 17 -> 1, ....
                        sym_valid <= {PHASES{1'b1}} << ((STF_START & {ADDR_SHIFT{1'b1}})); // Valid_signal <<mod(STF_START,PHASES) 
                    end else if(sym_counter > (STF_START >> ADDR_SHIFT) && sym_counter < (DATA_END >> ADDR_SHIFT)) begin
                        sym_valid <= {PHASES{1'b1}};
                    end else if(sym_counter == (DATA_END >> ADDR_SHIFT)) begin
                            sym_valid <= {PHASES{1'b1}} >> ( (PHASES) - (DATA_END & {ADDR_SHIFT{1'b1}})); 
                    end else begin
                        sym_valid <= {PHASES{1'b0}};
                    end
                end
            endcase
        end
    end

    
    reg [PHASES-1:0] sym_valid;
    reg [COUNTER_WIDTH-1:0]       sym_counter;
    
    always @ (posedge clk_i)begin
        if(rst_i) begin
            rx_state_current <= IDLE;
            pd_2_ltf_counter     <= 0 ;
            ltf_duration_counter <= 0;
            LTF_boundary_index_selected <= {($clog2(PHASES)){1'b0}};
            LTF_boundary_value_selected <=  {((DATAWIDTH*2)){1'b0}};
            LTF_boundary_clock_selected <=  {COUNTER_WIDTH{1'b0}};
            STF_START  <= {COUNTER_WIDTH{1'b0}};  
            STF_END    <= {COUNTER_WIDTH{1'b0}};   
            LTF_START  <= {COUNTER_WIDTH{1'b0}}; 
            LTF_END    <= {COUNTER_WIDTH{1'b0}};
            DATA_START <= {COUNTER_WIDTH{1'b0}};
            DATA_END   <= {COUNTER_WIDTH{1'b0}};   
            global_counter          <= 1;
            packet_valid_flag <= 1'b0;
        end else begin
            if(rx_state_current != IDLE)
                global_counter <= global_counter+1;
            case(rx_state_current) 
                IDLE: begin // PD Goes High -> 2 cycles to enter PD_FLAG.
                    rx_state_current <= (packet_detected) ? PD_FLAG:IDLE; // packet_detected. 
                    global_counter          <= 1;
                    LTF_boundary_index_selected <= {($clog2(PHASES)){1'b0}};
                    LTF_boundary_value_selected <=  {((DATAWIDTH*2)){1'b0}};
                    LTF_boundary_clock_selected <=  {COUNTER_WIDTH{1'b0}};
                    packet_valid_flag <=1'b0;
                end
                PD_FLAG: begin // 1-cycle to enter the TACQ Search.
                    rx_state_current <= (pd_2_ltf_counter >= LTF_START_BOUNDARY) ? TACQ_SEARCH:PD_FLAG;
                    pd_2_ltf_counter <= pd_2_ltf_counter + 1;
                end 
                TACQ_SEARCH: begin
                    pd_2_ltf_counter <= 0;
                    rx_state_current <= (ltf_duration_counter >= LTF_STOP_BOUNDARY) ? ADDRESS_COMPUTATION:TACQ_SEARCH;
                    ltf_duration_counter <= ltf_duration_counter + 1;
                    if(ltf_duration_counter == LTF_STOP_BOUNDARY) begin // select the LTF peak one cycle before transition
                        if(ssrSort_maxCLK_set_reg > ssrSort_maxCLK2_set_reg) begin                          
                            LTF_boundary_index_selected <= ssrSort_maxindex_set_reg;
                            LTF_boundary_value_selected <= ssrSort_maxValue_set_reg;
                            LTF_boundary_clock_selected <= ssrSort_maxCLK_set_reg; 
                        end else if(ssrSort_maxCLK2_set_reg > ssrSort_maxCLK_set_reg) begin
                            LTF_boundary_index_selected <= ssrSort_maxindex2_set_reg;
                            LTF_boundary_value_selected <= ssrSort_maxValue2_set_reg;
                            LTF_boundary_clock_selected <= ssrSort_maxCLK2_set_reg; 
                        end else begin 
                            if(ssrSort_maxindex_set_reg > ssrSort_maxindex2_set_reg) begin
                                LTF_boundary_index_selected <= ssrSort_maxindex_set_reg;
                                LTF_boundary_value_selected <= ssrSort_maxValue_set_reg;
                                LTF_boundary_clock_selected <= ssrSort_maxCLK_set_reg;
                            end else begin
                                LTF_boundary_index_selected <= ssrSort_maxindex2_set_reg;
                                LTF_boundary_value_selected <= ssrSort_maxValue2_set_reg;
                                LTF_boundary_clock_selected <= ssrSort_maxCLK2_set_reg; 
                            end
                        end                   
                    end
                end
                ADDRESS_COMPUTATION: begin
                    ltf_duration_counter <= 0;
                    rx_state_current     <= DATA_EXTRACTION;
                    // Compute the start address and end address of head <STF , LTF> 
                    STF_START  <= ((LTF_boundary_clock_selected << ADDR_SHIFT) + LTF_boundary_index_selected) - 319;
                    STF_END    <= ((LTF_boundary_clock_selected << ADDR_SHIFT) + LTF_boundary_index_selected) - 160;
                    LTF_START  <= ((LTF_boundary_clock_selected << ADDR_SHIFT) + LTF_boundary_index_selected) - 159; 
                    LTF_END    <= (LTF_boundary_clock_selected  << ADDR_SHIFT) + LTF_boundary_index_selected; 
                    DATA_START <= (LTF_boundary_clock_selected  << ADDR_SHIFT) + LTF_boundary_index_selected + 1;
                    DATA_END   <= (LTF_boundary_clock_selected  << ADDR_SHIFT) + LTF_boundary_index_selected + 1+  DATA_SIZE;
                    
                end
                DATA_EXTRACTION: begin
                    packet_valid_flag <= 1'b1;   
                    rx_state_current <= IDLE;
                end
            endcase
        end
    end 
    
    
    /*
        FIND TACQ PEAK.
        Find Peak Phase and Peak Value. 
        LATENCY = 1ClockCylce / Layer -> Layers = log2(PHASES)
    */
    wire [$clog2(PHASES)-1:0] ssrSort_maxindex_wire;
    wire signed [(DATAWIDTH*2)-1 :0] ssrSort_maxValue_wire;
    wire [$clog2(PHASES)-1:0] ssrSort_maxindex2_wire;
    wire signed [(DATAWIDTH*2)-1 :0] ssrSort_maxValue2_wire;
    ssr_sort_2 #(
        .DATAWIDTH  (DATAWIDTH  ),
        .PHASES     (PHASES     ),
        .PERIODICITY(PERIODICITY),
        .INT_BITS   (INT_BITS   ),
        .FRAC_BITS  (FRAC_BITS  ),
        .ARRAY_SIZE (ARRAY_SIZE )
    ) ssrsort_module_inst(
        .clk_i(clk_i),
        .rst_i(rst_i),
        .crossCorrelator_i(tacq_crossCorrelation_output_wire),
        .index_max_o(ssrSort_maxindex_wire),
        .value_max_o(ssrSort_maxValue_wire),
        .index_max2_o(ssrSort_maxindex2_wire),
        .value_max2_o(ssrSort_maxValue2_wire)
    );
    
    maxDetector 
    #(
        .DATAWIDTH   (DATAWIDTH                  ),
        .PHASES      (PHASES                     ),
        .PERIODICITY (PERIODICITY                ),
        .INT_BITS    (INT_BITS                   ),
        .FRAC_BITS   (FRAC_BITS                  ),
        .ARRAY_SIZE  (ARRAY_SIZE                 ),
        .CLOCKWIDTH  ($clog2(PACKET_SIZE)        )
     )
     maxDetinst(
        .max_1_p(ssrSort_maxValue_set_reg ),
        .max_2_p(ssrSort_maxValue2_set_reg ),
        .idx_1_p(ssrSort_maxindex_set_reg ),
        .idx_2_p(ssrSort_maxindex2_set_reg ),
        .clk_1_p(ssrSort_maxCLK_set_reg ),
        .clk_2_p(ssrSort_maxCLK2_set_reg ),
                
        .max_1_c(ssrSort_maxValue_wire ),
        .max_2_c(ssrSort_maxValue2_wire ),
        .idx_1_c(ssrSort_maxindex_wire ),
        .idx_2_c(ssrSort_maxindex2_wire ),
        .clk_1_c(global_counter ),
        .clk_2_c(global_counter ),
        
        .max_1_o(ssrSort_maxValue_unset_wire  ) , 
        .max_2_o(ssrSort_maxValue2_unset_wire  ) , 
        .idx_1_o(ssrSort_maxindex_unset_wire  ) ,
        .idx_2_o(ssrSort_maxindex2_unset_wire  ) ,
        .clk_1_o(ssrSort_maxCLK_unset_wire  ) ,
        .clk_2_o(ssrSort_maxCLK2_unset_wire ) 
        );
    
    
    reg [$clog2(PHASES)-1:0]            ssrSort_maxindex_set_reg;
    reg signed [(DATAWIDTH*2)-1 :0]            ssrSort_maxValue_set_reg;
    reg [$clog2(PACKET_SIZE):0]         ssrSort_maxCLK_set_reg;
    reg [$clog2(PHASES)-1:0]            ssrSort_maxindex2_set_reg;
    reg signed [(DATAWIDTH*2)-1 :0]            ssrSort_maxValue2_set_reg;
    reg [$clog2(PACKET_SIZE):0]         ssrSort_maxCLK2_set_reg;
    
    wire [$clog2(PHASES)-1:0]            ssrSort_maxindex_unset_wire;
    wire signed [(DATAWIDTH*2)-1 :0]            ssrSort_maxValue_unset_wire;
    wire [$clog2(PACKET_SIZE):0]   ssrSort_maxCLK_unset_wire;
    wire [$clog2(PHASES)-1:0]            ssrSort_maxindex2_unset_wire;
    wire signed [(DATAWIDTH*2)-1 :0]            ssrSort_maxValue2_unset_wire;
    wire [$clog2(PACKET_SIZE):0]   ssrSort_maxCLK2_unset_wire;
    
    
    always @ (posedge clk_i) begin
        if(rst_i) begin
            ssrSort_maxindex_set_reg  <= 0;   
            ssrSort_maxValue_set_reg  <= 0;   
            ssrSort_maxCLK_set_reg    <= 0;     
            ssrSort_maxindex2_set_reg <= 0;  
            ssrSort_maxValue2_set_reg <= 0;  
            ssrSort_maxCLK2_set_reg   <= 0;    
        end else begin
            if(rx_state_current == TACQ_SEARCH ) begin
                /* At this stage we need to asses the maximum values arrived.*/
                ssrSort_maxindex_set_reg  <=   ssrSort_maxindex_unset_wire;         
                ssrSort_maxValue_set_reg  <=   ssrSort_maxValue_unset_wire;         
                ssrSort_maxCLK_set_reg    <=   ssrSort_maxCLK_unset_wire;             
                ssrSort_maxindex2_set_reg <=   ssrSort_maxindex2_unset_wire;        
                ssrSort_maxValue2_set_reg <=   ssrSort_maxValue2_unset_wire;        
                ssrSort_maxCLK2_set_reg   <=   ssrSort_maxCLK2_unset_wire;            
            end else if (rx_state_current ==DATA_EXTRACTION) begin
                ssrSort_maxindex_set_reg  <= 0;   
                ssrSort_maxValue_set_reg  <= 0;   
                ssrSort_maxCLK_set_reg    <= 0;     
                ssrSort_maxindex2_set_reg <= 0;  
                ssrSort_maxValue2_set_reg <= 0;  
                ssrSort_maxCLK2_set_reg   <= 0; 
            end
        end
    end
    
    
    
    
    
endmodule
