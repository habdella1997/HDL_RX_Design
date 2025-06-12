
module LFSRv2 (
    input clk, 
    input ce,
    input [15:0] initSeq,
    input rst,
    input en,
    output [15:0] dOut );


reg [15:0] lfsr; 
wire xored;

always @ (posedge clk) begin
    if(rst) begin 
        lfsr <= initSeq;
    end 
    else begin
        if(en) begin
            lfsr <= {lfsr[14:0], xored};
        end
        else begin      
            lfsr <= lfsr;
        end
    end
end

// optimum max length polynomial for 16 bit SR
assign xored = lfsr[15] ^~ lfsr[14] ^~ lfsr[12] ^~ lfsr[3]; // XNOR
assign dOut = lfsr; //lfsr[15];

endmodule
