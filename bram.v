`timescale 1ns / 1ps

module bram #(
    parameter DATAWIDTH = 16,
    parameter PHASES    = 16,
    parameter INWIDTH   = DATAWIDTH * PHASES,
    parameter RAM_WIDTH = DATAWIDTH,
    parameter DELAY     = 32,  //Cycle of Delays needed
    parameter RAM_DEPTH = DELAY
)(
    input clk_i,
    input rst_i,
    input [INWIDTH-1:0] data_in_re,
    input [INWIDTH-1:0] data_in_im,
    output reg [INWIDTH-1:0] data_out_re,
    output reg [INWIDTH-1:0] data_out_im
    );
    
    localparam integer ADDR_WIDTH = $clog2(RAM_DEPTH); 
    
    reg [ADDR_WIDTH : 0] write_addr;
    reg [ADDR_WIDTH : 0] read_addr;
    reg  mem_enable;
    
    genvar p;
    generate
      for (p = 0; p < PHASES; p=p+1) begin : phase_bank
        (* ram_style = "block" *) reg [DATAWIDTH-1:0] bram_re [0:RAM_DEPTH-1];
        (* ram_style = "block" *) reg [DATAWIDTH-1:0] bram_im [0:RAM_DEPTH-1];
    
        always @(posedge clk_i) begin
          if (mem_enable) begin
            bram_re[write_addr] <= data_in_re[(p+1)*DATAWIDTH-1 -: DATAWIDTH];
            bram_im[write_addr] <= data_in_im[(p+1)*DATAWIDTH-1 -: DATAWIDTH];
            data_out_re[(p+1)*DATAWIDTH-1 -: DATAWIDTH] <= bram_re[read_addr];
            data_out_im[(p+1)*DATAWIDTH-1 -: DATAWIDTH] <= bram_im[read_addr];
          end
        end
      end
    endgenerate
    
    always @ (posedge clk_i) begin
        if(rst_i)begin
            write_addr <= {(ADDR_WIDTH+1){1'b0}};
            read_addr  <=  1;
            mem_enable <= 1'b0;
        end else begin
            mem_enable <= 1'b1;
            write_addr <= (write_addr < RAM_DEPTH-1) ? write_addr + 1 : {(ADDR_WIDTH+1){1'b0}};
            read_addr  <= (read_addr  < RAM_DEPTH-1) ? read_addr  + 1 : {(ADDR_WIDTH+1){1'b0}};
        end
    end
    
//    integer demux;
//    always @ (posedge clk_i) begin
//        if(mem_enable) begin
//            for(demux = 0 ; demux < PHASES; demux =demux+1)begin
//                  bram_1[write_addr][demux] <= data_in_re[(demux+1)*DATAWIDTH -1 -: DATAWIDTH];
//                  bram_2[write_addr][demux] <= data_in_im[(demux+1)*DATAWIDTH -1 -: DATAWIDTH];
//                  data_out_re[(demux+1)*DATAWIDTH -1 -: DATAWIDTH] <= bram_1[read_addr][demux];
//                  data_out_im[(demux+1)*DATAWIDTH -1 -: DATAWIDTH] <= bram_2[read_addr][demux];
//            end
//        end
//    end

endmodule
