`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/30/2025 06:30:53 PM
// Design Name: 
// Module Name: genSTF
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module genSTF #(
    parameter PHASES = 64,
    parameter BITWIDTH = 12,
    parameter ARRAYSIZE = PHASES * BITWIDTH
)(
    input clk_i,
    input rst_i,
    input header_en_i,
    output reg [ARRAYSIZE-1:0] header_re,
    output reg [ARRAYSIZE-1:0] header_im
    );
    
    localparam integer HEADERSIZE    = 320;
    localparam integer HEADERCYCLES  = HEADERSIZE / PHASES;
    localparam integer HEADERCOUNTER = $clog2(HEADERCYCLES) + 1;  
    
    reg [HEADERCOUNTER-1 : 0] header_addr;
    
    integer hd_i;
    always @ (posedge clk_i) begin
        if(rst_i)begin
            for(hd_i = 0 ; hd_i < PHASES ; hd_i = hd_i + 1)begin
                header_re[hd_i] <= {BITWIDTH{1'b0}};
                header_im[hd_i] <= {BITWIDTH{1'b0}};
            end
            header_addr <= {$clog2(HEADERSIZE){1'b0}};
        end else begin
            for(hd_i = 0 ; hd_i < PHASES; hd_i = hd_i +1) begin 
                header_im[hd_i + header_addr] <= header_seq[hd_i + header_addr][23 -: 12];
                header_re[hd_i + header_addr] <= header_seq[hd_i + header_addr][11:0];
            end
            header_addr <= (header_en_i) ? header_addr+1 : {HEADERCOUNTER{1'b0}};
        end
    end
    
    
reg [23:0] header_seq [0:HEADERSIZE-1]; //{im,re}

initial begin
    header_seq[0] = 24'h05E05E; // Re: 0.045999, Im: 0.045999
    header_seq[1] = 24'h005EF1; // Re: -0.132444, Im: 0.002340
    header_seq[2] = 24'hF5FFE4; // Re: -0.013473, Im: -0.078525
    header_seq[3] = 24'hFE6124; // Re: 0.142755, Im: -0.012651
    header_seq[4] = 24'h0000BC; // Re: 0.091998, Im: 0.000000
    header_seq[5] = 24'hFE6124; // Re: 0.142755, Im: -0.012651
    header_seq[6] = 24'hF5FFE4; // Re: -0.013473, Im: -0.078525
    header_seq[7] = 24'h005EF1; // Re: -0.132444, Im: 0.002340
    header_seq[8] = 24'h05E05E; // Re: 0.045999, Im: 0.045999
    header_seq[9] = 24'hEF1005; // Re: 0.002340, Im: -0.132444
    header_seq[10] = 24'hFE4F5F; // Re: -0.078525, Im: -0.013473
    header_seq[11] = 24'h124FE6; // Re: -0.012651, Im: 0.142755
    header_seq[12] = 24'h0BC000; // Re: 0.000000, Im: 0.091998
    header_seq[13] = 24'h124FE6; // Re: -0.012651, Im: 0.142755
    header_seq[14] = 24'hFE4F5F; // Re: -0.078525, Im: -0.013473
    header_seq[15] = 24'hEF1005; // Re: 0.002340, Im: -0.132444
    header_seq[16] = 24'h05E05E; // Re: 0.045999, Im: 0.045999
    header_seq[17] = 24'h005EF1; // Re: -0.132444, Im: 0.002340
    header_seq[18] = 24'hF5FFE4; // Re: -0.013473, Im: -0.078525
    header_seq[19] = 24'hFE6124; // Re: 0.142755, Im: -0.012651
    header_seq[20] = 24'h0000BC; // Re: 0.091998, Im: 0.000000
    header_seq[21] = 24'hFE6124; // Re: 0.142755, Im: -0.012651
    header_seq[22] = 24'hF5FFE4; // Re: -0.013473, Im: -0.078525
    header_seq[23] = 24'h005EF1; // Re: -0.132444, Im: 0.002340
    header_seq[24] = 24'h05E05E; // Re: 0.045999, Im: 0.045999
    header_seq[25] = 24'hEF1005; // Re: 0.002340, Im: -0.132444
    header_seq[26] = 24'hFE4F5F; // Re: -0.078525, Im: -0.013473
    header_seq[27] = 24'h124FE6; // Re: -0.012651, Im: 0.142755
    header_seq[28] = 24'h0BC000; // Re: 0.000000, Im: 0.091998
    header_seq[29] = 24'h124FE6; // Re: -0.012651, Im: 0.142755
    header_seq[30] = 24'hFE4F5F; // Re: -0.078525, Im: -0.013473
    header_seq[31] = 24'hEF1005; // Re: 0.002340, Im: -0.132444
    header_seq[32] = 24'h05E05E; // Re: 0.045999, Im: 0.045999
    header_seq[33] = 24'h005EF1; // Re: -0.132444, Im: 0.002340
    header_seq[34] = 24'hF5FFE4; // Re: -0.013473, Im: -0.078525
    header_seq[35] = 24'hFE6124; // Re: 0.142755, Im: -0.012651
    header_seq[36] = 24'h0000BC; // Re: 0.091998, Im: 0.000000
    header_seq[37] = 24'hFE6124; // Re: 0.142755, Im: -0.012651
    header_seq[38] = 24'hF5FFE4; // Re: -0.013473, Im: -0.078525
    header_seq[39] = 24'h005EF1; // Re: -0.132444, Im: 0.002340
    header_seq[40] = 24'h05E05E; // Re: 0.045999, Im: 0.045999
    header_seq[41] = 24'hEF1005; // Re: 0.002340, Im: -0.132444
    header_seq[42] = 24'hFE4F5F; // Re: -0.078525, Im: -0.013473
    header_seq[43] = 24'h124FE6; // Re: -0.012651, Im: 0.142755
    header_seq[44] = 24'h0BC000; // Re: 0.000000, Im: 0.091998
    header_seq[45] = 24'h124FE6; // Re: -0.012651, Im: 0.142755
    header_seq[46] = 24'hFE4F5F; // Re: -0.078525, Im: -0.013473
    header_seq[47] = 24'hEF1005; // Re: 0.002340, Im: -0.132444
    header_seq[48] = 24'h05E05E; // Re: 0.045999, Im: 0.045999
    header_seq[49] = 24'h005EF1; // Re: -0.132444, Im: 0.002340
    header_seq[50] = 24'hF5FFE4; // Re: -0.013473, Im: -0.078525
    header_seq[51] = 24'hFE6124; // Re: 0.142755, Im: -0.012651
    header_seq[52] = 24'h0000BC; // Re: 0.091998, Im: 0.000000
    header_seq[53] = 24'hFE6124; // Re: 0.142755, Im: -0.012651
    header_seq[54] = 24'hF5FFE4; // Re: -0.013473, Im: -0.078525
    header_seq[55] = 24'h005EF1; // Re: -0.132444, Im: 0.002340
    header_seq[56] = 24'h05E05E; // Re: 0.045999, Im: 0.045999
    header_seq[57] = 24'hEF1005; // Re: 0.002340, Im: -0.132444
    header_seq[58] = 24'hFE4F5F; // Re: -0.078525, Im: -0.013473
    header_seq[59] = 24'h124FE6; // Re: -0.012651, Im: 0.142755
    header_seq[60] = 24'h0BC000; // Re: 0.000000, Im: 0.091998
    header_seq[61] = 24'h124FE6; // Re: -0.012651, Im: 0.142755
    header_seq[62] = 24'hFE4F5F; // Re: -0.078525, Im: -0.013473
    header_seq[63] = 24'hEF1005; // Re: 0.002340, Im: -0.132444
    header_seq[64] = 24'h05E05E; // Re: 0.045999, Im: 0.045999
    header_seq[65] = 24'h005EF1; // Re: -0.132444, Im: 0.002340
    header_seq[66] = 24'hF5FFE4; // Re: -0.013473, Im: -0.078525
    header_seq[67] = 24'hFE6124; // Re: 0.142755, Im: -0.012651
    header_seq[68] = 24'h0000BC; // Re: 0.091998, Im: 0.000000
    header_seq[69] = 24'hFE6124; // Re: 0.142755, Im: -0.012651
    header_seq[70] = 24'hF5FFE4; // Re: -0.013473, Im: -0.078525
    header_seq[71] = 24'h005EF1; // Re: -0.132444, Im: 0.002340
    header_seq[72] = 24'h05E05E; // Re: 0.045999, Im: 0.045999
    header_seq[73] = 24'hEF1005; // Re: 0.002340, Im: -0.132444
    header_seq[74] = 24'hFE4F5F; // Re: -0.078525, Im: -0.013473
    header_seq[75] = 24'h124FE6; // Re: -0.012651, Im: 0.142755
    header_seq[76] = 24'h0BC000; // Re: 0.000000, Im: 0.091998
    header_seq[77] = 24'h124FE6; // Re: -0.012651, Im: 0.142755
    header_seq[78] = 24'hFE4F5F; // Re: -0.078525, Im: -0.013473
    header_seq[79] = 24'hEF1005; // Re: 0.002340, Im: -0.132444
    header_seq[80] = 24'h05E05E; // Re: 0.045999, Im: 0.045999
    header_seq[81] = 24'h005EF1; // Re: -0.132444, Im: 0.002340
    header_seq[82] = 24'hF5FFE4; // Re: -0.013473, Im: -0.078525
    header_seq[83] = 24'hFE6124; // Re: 0.142755, Im: -0.012651
    header_seq[84] = 24'h0000BC; // Re: 0.091998, Im: 0.000000
    header_seq[85] = 24'hFE6124; // Re: 0.142755, Im: -0.012651
    header_seq[86] = 24'hF5FFE4; // Re: -0.013473, Im: -0.078525
    header_seq[87] = 24'h005EF1; // Re: -0.132444, Im: 0.002340
    header_seq[88] = 24'h05E05E; // Re: 0.045999, Im: 0.045999
    header_seq[89] = 24'hEF1005; // Re: 0.002340, Im: -0.132444
    header_seq[90] = 24'hFE4F5F; // Re: -0.078525, Im: -0.013473
    header_seq[91] = 24'h124FE6; // Re: -0.012651, Im: 0.142755
    header_seq[92] = 24'h0BC000; // Re: 0.000000, Im: 0.091998
    header_seq[93] = 24'h124FE6; // Re: -0.012651, Im: 0.142755
    header_seq[94] = 24'hFE4F5F; // Re: -0.078525, Im: -0.013473
    header_seq[95] = 24'hEF1005; // Re: 0.002340, Im: -0.132444
    header_seq[96] = 24'h05E05E; // Re: 0.045999, Im: 0.045999
    header_seq[97] = 24'h005EF1; // Re: -0.132444, Im: 0.002340
    header_seq[98] = 24'hF5FFE4; // Re: -0.013473, Im: -0.078525
    header_seq[99] = 24'hFE6124; // Re: 0.142755, Im: -0.012651
    header_seq[100] = 24'h0000BC; // Re: 0.091998, Im: 0.000000
    header_seq[101] = 24'hFE6124; // Re: 0.142755, Im: -0.012651
    header_seq[102] = 24'hF5FFE4; // Re: -0.013473, Im: -0.078525
    header_seq[103] = 24'h005EF1; // Re: -0.132444, Im: 0.002340
    header_seq[104] = 24'h05E05E; // Re: 0.045999, Im: 0.045999
    header_seq[105] = 24'hEF1005; // Re: 0.002340, Im: -0.132444
    header_seq[106] = 24'hFE4F5F; // Re: -0.078525, Im: -0.013473
    header_seq[107] = 24'h124FE6; // Re: -0.012651, Im: 0.142755
    header_seq[108] = 24'h0BC000; // Re: 0.000000, Im: 0.091998
    header_seq[109] = 24'h124FE6; // Re: -0.012651, Im: 0.142755
    header_seq[110] = 24'hFE4F5F; // Re: -0.078525, Im: -0.013473
    header_seq[111] = 24'hEF1005; // Re: 0.002340, Im: -0.132444
    header_seq[112] = 24'h05E05E; // Re: 0.045999, Im: 0.045999
    header_seq[113] = 24'h005EF1; // Re: -0.132444, Im: 0.002340
    header_seq[114] = 24'hF5FFE4; // Re: -0.013473, Im: -0.078525
    header_seq[115] = 24'hFE6124; // Re: 0.142755, Im: -0.012651
    header_seq[116] = 24'h0000BC; // Re: 0.091998, Im: 0.000000
    header_seq[117] = 24'hFE6124; // Re: 0.142755, Im: -0.012651
    header_seq[118] = 24'hF5FFE4; // Re: -0.013473, Im: -0.078525
    header_seq[119] = 24'h005EF1; // Re: -0.132444, Im: 0.002340
    header_seq[120] = 24'h05E05E; // Re: 0.045999, Im: 0.045999
    header_seq[121] = 24'hEF1005; // Re: 0.002340, Im: -0.132444
    header_seq[122] = 24'hFE4F5F; // Re: -0.078525, Im: -0.013473
    header_seq[123] = 24'h124FE6; // Re: -0.012651, Im: 0.142755
    header_seq[124] = 24'h0BC000; // Re: 0.000000, Im: 0.091998
    header_seq[125] = 24'h124FE6; // Re: -0.012651, Im: 0.142755
    header_seq[126] = 24'hFE4F5F; // Re: -0.078525, Im: -0.013473
    header_seq[127] = 24'hEF1005; // Re: 0.002340, Im: -0.132444
    header_seq[128] = 24'h05E05E; // Re: 0.045999, Im: 0.045999
    header_seq[129] = 24'h005EF1; // Re: -0.132444, Im: 0.002340
    header_seq[130] = 24'hF5FFE4; // Re: -0.013473, Im: -0.078525
    header_seq[131] = 24'hFE6124; // Re: 0.142755, Im: -0.012651
    header_seq[132] = 24'h0000BC; // Re: 0.091998, Im: 0.000000
    header_seq[133] = 24'hFE6124; // Re: 0.142755, Im: -0.012651
    header_seq[134] = 24'hF5FFE4; // Re: -0.013473, Im: -0.078525
    header_seq[135] = 24'h005EF1; // Re: -0.132444, Im: 0.002340
    header_seq[136] = 24'h05E05E; // Re: 0.045999, Im: 0.045999
    header_seq[137] = 24'hEF1005; // Re: 0.002340, Im: -0.132444
    header_seq[138] = 24'hFE4F5F; // Re: -0.078525, Im: -0.013473
    header_seq[139] = 24'h124FE6; // Re: -0.012651, Im: 0.142755
    header_seq[140] = 24'h0BC000; // Re: 0.000000, Im: 0.091998
    header_seq[141] = 24'h124FE6; // Re: -0.012651, Im: 0.142755
    header_seq[142] = 24'hFE4F5F; // Re: -0.078525, Im: -0.013473
    header_seq[143] = 24'hEF1005; // Re: 0.002340, Im: -0.132444
    header_seq[144] = 24'h05E05E; // Re: 0.045999, Im: 0.045999
    header_seq[145] = 24'h005EF1; // Re: -0.132444, Im: 0.002340
    header_seq[146] = 24'hF5FFE4; // Re: -0.013473, Im: -0.078525
    header_seq[147] = 24'hFE6124; // Re: 0.142755, Im: -0.012651
    header_seq[148] = 24'h0000BC; // Re: 0.091998, Im: 0.000000
    header_seq[149] = 24'hFE6124; // Re: 0.142755, Im: -0.012651
    header_seq[150] = 24'hF5FFE4; // Re: -0.013473, Im: -0.078525
    header_seq[151] = 24'h005EF1; // Re: -0.132444, Im: 0.002340
    header_seq[152] = 24'h05E05E; // Re: 0.045999, Im: 0.045999
    header_seq[153] = 24'hEF1005; // Re: 0.002340, Im: -0.132444
    header_seq[154] = 24'hFE4F5F; // Re: -0.078525, Im: -0.013473
    header_seq[155] = 24'h124FE6; // Re: -0.012651, Im: 0.142755
    header_seq[156] = 24'h0BC000; // Re: 0.000000, Im: 0.091998
    header_seq[157] = 24'h124FE6; // Re: -0.012651, Im: 0.142755
    header_seq[158] = 24'hFE4F5F; // Re: -0.078525, Im: -0.013473
    header_seq[159] = 24'hEF1005; // Re: 0.002340, Im: -0.132444
    header_seq[160] = 24'h000EC0; // Re: -0.156250, Im: 0.000000
    header_seq[161] = 24'hF38019; // Re: 0.012285, Im: -0.097600
    header_seq[162] = 24'hF270BC; // Re: 0.091717, Im: -0.105872
    header_seq[163] = 24'hF14F44; // Re: -0.091888, Im: -0.115129
    header_seq[164] = 24'hF92FFA; // Re: -0.002806, Im: -0.053774
    header_seq[165] = 24'h09809A; // Re: 0.075074, Im: 0.074040
    header_seq[166] = 24'h02AEFB; // Re: -0.127324, Im: 0.020501
    header_seq[167] = 24'h022F06; // Re: -0.121887, Im: 0.016566
    header_seq[168] = 24'h135FB8; // Re: -0.035041, Im: 0.150888
    header_seq[169] = 24'h02DF8C; // Re: -0.056455, Im: 0.021804
    header_seq[170] = 24'hF5AF84; // Re: -0.060310, Im: -0.081286
    header_seq[171] = 24'hFE308E; // Re: 0.069557, Im: -0.014122
    header_seq[172] = 24'hF430A8; // Re: 0.082218, Im: -0.092357
    header_seq[173] = 24'hF7AEF3; // Re: -0.131263, Im: -0.065227
    header_seq[174] = 24'hFB0F8B; // Re: -0.057206, Im: -0.039299
    header_seq[175] = 24'hF3704C; // Re: 0.036918, Im: -0.098344
    header_seq[176] = 24'h080080; // Re: 0.062500, Im: 0.062500
    header_seq[177] = 24'h0080F4; // Re: 0.119239, Im: 0.004096
    header_seq[178] = 24'hEB7FD2; // Re: -0.022483, Im: -0.160657
    header_seq[179] = 24'h01F078; // Re: 0.058669, Im: 0.014939
    header_seq[180] = 24'h078032; // Re: 0.024476, Im: 0.058532
    header_seq[181] = 24'h061EE8; // Re: -0.136805, Im: 0.047380
    header_seq[182] = 24'h0EC002; // Re: 0.000989, Im: 0.115005
    header_seq[183] = 24'hFF806D; // Re: 0.053338, Im: -0.004076
    header_seq[184] = 24'h0350C8; // Re: 0.097541, Im: 0.025888
    header_seq[185] = 24'h0D9FB2; // Re: -0.038316, Im: 0.106171
    header_seq[186] = 24'h071F14; // Re: -0.115131, Im: 0.055180
    header_seq[187] = 24'h0B407B; // Re: 0.059824, Im: 0.087707
    header_seq[188] = 24'hFC702B; // Re: 0.021112, Im: -0.027886
    header_seq[189] = 24'hF560C6; // Re: 0.096832, Im: -0.082798
    header_seq[190] = 24'h0E4051; // Re: 0.039750, Im: 0.111158
    header_seq[191] = 24'h0F6FF6; // Re: -0.005121, Im: 0.120325
    header_seq[192] = 24'h000140; // Re: 0.156250, Im: 0.000000
    header_seq[193] = 24'hF0AFF6; // Re: -0.005121, Im: -0.120325
    header_seq[194] = 24'hF1C051; // Re: 0.039750, Im: -0.111158
    header_seq[195] = 24'h0AA0C6; // Re: 0.096832, Im: 0.082798
    header_seq[196] = 24'h03902B; // Re: 0.021112, Im: 0.027886
    header_seq[197] = 24'hF4C07B; // Re: 0.059824, Im: -0.087707
    header_seq[198] = 24'hF8FF14; // Re: -0.115131, Im: -0.055180
    header_seq[199] = 24'hF27FB2; // Re: -0.038316, Im: -0.106171
    header_seq[200] = 24'hFCB0C8; // Re: 0.097541, Im: -0.025888
    header_seq[201] = 24'h00806D; // Re: 0.053338, Im: 0.004076
    header_seq[202] = 24'hF14002; // Re: 0.000989, Im: -0.115005
    header_seq[203] = 24'hF9FEE8; // Re: -0.136805, Im: -0.047380
    header_seq[204] = 24'hF88032; // Re: 0.024476, Im: -0.058532
    header_seq[205] = 24'hFE1078; // Re: 0.058669, Im: -0.014939
    header_seq[206] = 24'h149FD2; // Re: -0.022483, Im: 0.160657
    header_seq[207] = 24'hFF80F4; // Re: 0.119239, Im: -0.004096
    header_seq[208] = 24'hF80080; // Re: 0.062500, Im: -0.062500
    header_seq[209] = 24'h0C904C; // Re: 0.036918, Im: 0.098344
    header_seq[210] = 24'h050F8B; // Re: -0.057206, Im: 0.039299
    header_seq[211] = 24'h086EF3; // Re: -0.131263, Im: 0.065227
    header_seq[212] = 24'h0BD0A8; // Re: 0.082218, Im: 0.092357
    header_seq[213] = 24'h01D08E; // Re: 0.069557, Im: 0.014122
    header_seq[214] = 24'h0A6F84; // Re: -0.060310, Im: 0.081286
    header_seq[215] = 24'hFD3F8C; // Re: -0.056455, Im: -0.021804
    header_seq[216] = 24'hECBFB8; // Re: -0.035041, Im: -0.150888
    header_seq[217] = 24'hFDEF06; // Re: -0.121887, Im: -0.016566
    header_seq[218] = 24'hFD6EFB; // Re: -0.127324, Im: -0.020501
    header_seq[219] = 24'hF6809A; // Re: 0.075074, Im: -0.074040
    header_seq[220] = 24'h06EFFA; // Re: -0.002806, Im: 0.053774
    header_seq[221] = 24'h0ECF44; // Re: -0.091888, Im: 0.115129
    header_seq[222] = 24'h0D90BC; // Re: 0.091717, Im: 0.105872
    header_seq[223] = 24'h0C8019; // Re: 0.012285, Im: 0.097600
    header_seq[224] = 24'h000EC0; // Re: -0.156250, Im: 0.000000
    header_seq[225] = 24'hF38019; // Re: 0.012285, Im: -0.097600
    header_seq[226] = 24'hF270BC; // Re: 0.091717, Im: -0.105872
    header_seq[227] = 24'hF14F44; // Re: -0.091888, Im: -0.115129
    header_seq[228] = 24'hF92FFA; // Re: -0.002806, Im: -0.053774
    header_seq[229] = 24'h09809A; // Re: 0.075074, Im: 0.074040
    header_seq[230] = 24'h02AEFB; // Re: -0.127324, Im: 0.020501
    header_seq[231] = 24'h022F06; // Re: -0.121887, Im: 0.016566
    header_seq[232] = 24'h135FB8; // Re: -0.035041, Im: 0.150888
    header_seq[233] = 24'h02DF8C; // Re: -0.056455, Im: 0.021804
    header_seq[234] = 24'hF5AF84; // Re: -0.060310, Im: -0.081286
    header_seq[235] = 24'hFE308E; // Re: 0.069557, Im: -0.014122
    header_seq[236] = 24'hF430A8; // Re: 0.082218, Im: -0.092357
    header_seq[237] = 24'hF7AEF3; // Re: -0.131263, Im: -0.065227
    header_seq[238] = 24'hFB0F8B; // Re: -0.057206, Im: -0.039299
    header_seq[239] = 24'hF3704C; // Re: 0.036918, Im: -0.098344
    header_seq[240] = 24'h080080; // Re: 0.062500, Im: 0.062500
    header_seq[241] = 24'h0080F4; // Re: 0.119239, Im: 0.004096
    header_seq[242] = 24'hEB7FD2; // Re: -0.022483, Im: -0.160657
    header_seq[243] = 24'h01F078; // Re: 0.058669, Im: 0.014939
    header_seq[244] = 24'h078032; // Re: 0.024476, Im: 0.058532
    header_seq[245] = 24'h061EE8; // Re: -0.136805, Im: 0.047380
    header_seq[246] = 24'h0EC002; // Re: 0.000989, Im: 0.115005
    header_seq[247] = 24'hFF806D; // Re: 0.053338, Im: -0.004076
    header_seq[248] = 24'h0350C8; // Re: 0.097541, Im: 0.025888
    header_seq[249] = 24'h0D9FB2; // Re: -0.038316, Im: 0.106171
    header_seq[250] = 24'h071F14; // Re: -0.115131, Im: 0.055180
    header_seq[251] = 24'h0B407B; // Re: 0.059824, Im: 0.087707
    header_seq[252] = 24'hFC702B; // Re: 0.021112, Im: -0.027886
    header_seq[253] = 24'hF560C6; // Re: 0.096832, Im: -0.082798
    header_seq[254] = 24'h0E4051; // Re: 0.039750, Im: 0.111158
    header_seq[255] = 24'h0F6FF6; // Re: -0.005121, Im: 0.120325
    header_seq[256] = 24'h000140; // Re: 0.156250, Im: 0.000000
    header_seq[257] = 24'hF0AFF6; // Re: -0.005121, Im: -0.120325
    header_seq[258] = 24'hF1C051; // Re: 0.039750, Im: -0.111158
    header_seq[259] = 24'h0AA0C6; // Re: 0.096832, Im: 0.082798
    header_seq[260] = 24'h03902B; // Re: 0.021112, Im: 0.027886
    header_seq[261] = 24'hF4C07B; // Re: 0.059824, Im: -0.087707
    header_seq[262] = 24'hF8FF14; // Re: -0.115131, Im: -0.055180
    header_seq[263] = 24'hF27FB2; // Re: -0.038316, Im: -0.106171
    header_seq[264] = 24'hFCB0C8; // Re: 0.097541, Im: -0.025888
    header_seq[265] = 24'h00806D; // Re: 0.053338, Im: 0.004076
    header_seq[266] = 24'hF14002; // Re: 0.000989, Im: -0.115005
    header_seq[267] = 24'hF9FEE8; // Re: -0.136805, Im: -0.047380
    header_seq[268] = 24'hF88032; // Re: 0.024476, Im: -0.058532
    header_seq[269] = 24'hFE1078; // Re: 0.058669, Im: -0.014939
    header_seq[270] = 24'h149FD2; // Re: -0.022483, Im: 0.160657
    header_seq[271] = 24'hFF80F4; // Re: 0.119239, Im: -0.004096
    header_seq[272] = 24'hF80080; // Re: 0.062500, Im: -0.062500
    header_seq[273] = 24'h0C904C; // Re: 0.036918, Im: 0.098344
    header_seq[274] = 24'h050F8B; // Re: -0.057206, Im: 0.039299
    header_seq[275] = 24'h086EF3; // Re: -0.131263, Im: 0.065227
    header_seq[276] = 24'h0BD0A8; // Re: 0.082218, Im: 0.092357
    header_seq[277] = 24'h01D08E; // Re: 0.069557, Im: 0.014122
    header_seq[278] = 24'h0A6F84; // Re: -0.060310, Im: 0.081286
    header_seq[279] = 24'hFD3F8C; // Re: -0.056455, Im: -0.021804
    header_seq[280] = 24'hECBFB8; // Re: -0.035041, Im: -0.150888
    header_seq[281] = 24'hFDEF06; // Re: -0.121887, Im: -0.016566
    header_seq[282] = 24'hFD6EFB; // Re: -0.127324, Im: -0.020501
    header_seq[283] = 24'hF6809A; // Re: 0.075074, Im: -0.074040
    header_seq[284] = 24'h06EFFA; // Re: -0.002806, Im: 0.053774
    header_seq[285] = 24'h0ECF44; // Re: -0.091888, Im: 0.115129
    header_seq[286] = 24'h0D90BC; // Re: 0.091717, Im: 0.105872
    header_seq[287] = 24'h0C8019; // Re: 0.012285, Im: 0.097600
    header_seq[288] = 24'h000EC0; // Re: -0.156250, Im: 0.000000
    header_seq[289] = 24'hF38019; // Re: 0.012285, Im: -0.097600
    header_seq[290] = 24'hF270BC; // Re: 0.091717, Im: -0.105872
    header_seq[291] = 24'hF14F44; // Re: -0.091888, Im: -0.115129
    header_seq[292] = 24'hF92FFA; // Re: -0.002806, Im: -0.053774
    header_seq[293] = 24'h09809A; // Re: 0.075074, Im: 0.074040
    header_seq[294] = 24'h02AEFB; // Re: -0.127324, Im: 0.020501
    header_seq[295] = 24'h022F06; // Re: -0.121887, Im: 0.016566
    header_seq[296] = 24'h135FB8; // Re: -0.035041, Im: 0.150888
    header_seq[297] = 24'h02DF8C; // Re: -0.056455, Im: 0.021804
    header_seq[298] = 24'hF5AF84; // Re: -0.060310, Im: -0.081286
    header_seq[299] = 24'hFE308E; // Re: 0.069557, Im: -0.014122
    header_seq[300] = 24'hF430A8; // Re: 0.082218, Im: -0.092357
    header_seq[301] = 24'hF7AEF3; // Re: -0.131263, Im: -0.065227
    header_seq[302] = 24'hFB0F8B; // Re: -0.057206, Im: -0.039299
    header_seq[303] = 24'hF3704C; // Re: 0.036918, Im: -0.098344
    header_seq[304] = 24'h080080; // Re: 0.062500, Im: 0.062500
    header_seq[305] = 24'h0080F4; // Re: 0.119239, Im: 0.004096
    header_seq[306] = 24'hEB7FD2; // Re: -0.022483, Im: -0.160657
    header_seq[307] = 24'h01F078; // Re: 0.058669, Im: 0.014939
    header_seq[308] = 24'h078032; // Re: 0.024476, Im: 0.058532
    header_seq[309] = 24'h061EE8; // Re: -0.136805, Im: 0.047380
    header_seq[310] = 24'h0EC002; // Re: 0.000989, Im: 0.115005
    header_seq[311] = 24'hFF806D; // Re: 0.053338, Im: -0.004076
    header_seq[312] = 24'h0350C8; // Re: 0.097541, Im: 0.025888
    header_seq[313] = 24'h0D9FB2; // Re: -0.038316, Im: 0.106171
    header_seq[314] = 24'h071F14; // Re: -0.115131, Im: 0.055180
    header_seq[315] = 24'h0B407B; // Re: 0.059824, Im: 0.087707
    header_seq[316] = 24'hFC702B; // Re: 0.021112, Im: -0.027886
    header_seq[317] = 24'hF560C6; // Re: 0.096832, Im: -0.082798
    header_seq[318] = 24'h0E4051; // Re: 0.039750, Im: 0.111158
    header_seq[319] = 24'h0F6FF6; // Re: -0.005121, Im: 0.120325
end  
       
endmodule
