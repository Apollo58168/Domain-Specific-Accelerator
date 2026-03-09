`timescale 1ns / 1ps
// =============================================================================
//  Program : fp_reg_file.v
//  Author  : Sin-Ying Li
//  Date    : Aug/19/2025
// -----------------------------------------------------------------------------
//  Description:
//  This is the Floting Point Register File of the Aquila core (A RISC-V core).
//  Based on reg_file.v (Aquila core) by Jin-you Wu, Dec/18/2018.
// -----------------------------------------------------------------------------
//  Revision information:
//
//  NONE.
// -----------------------------------------------------------------------------
//  License information:
//
//  This software is released under the BSD-3-Clause Licence,
//  see https://opensource.org/licenses/BSD-3-Clause for details.
//  In the following license statements, "software" refers to the
//  "source code" of the complete hardware/software system.
//
//  Copyright 2025,
//                    Embedded Intelligent Systems Lab (EISL)
//                    Deparment of Computer Science
//                    National Yang Ming Chiao Tung Uniersity
//                    Hsinchu, Taiwan.
//
//  All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//
//  1. Redistributions of source code must retain the above copyright notice,
//     this list of conditions and the following disclaimer.
//
//  2. Redistributions in binary form must reproduce the above copyright notice,
//     this list of conditions and the following disclaimer in the documentation
//     and/or other materials provided with the distribution.
//
//  3. Neither the name of the copyright holder nor the names of its contributors
//     may be used to endorse or promote products derived from this software
//     without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
//  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
//  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
//  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
//  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//  POSSIBILITY OF SUCH DAMAGE.
// =============================================================================
`include "aquila_config.vh"

module fp_reg_file #(
    parameter NUM_REGS = 32,
    parameter XLEN = 32,
    parameter NRLEN = $clog2(NUM_REGS) )
(
    // System signals
    input                  clk_i,
    input                  rst_i,
    
    // from Decode
    input  [NRLEN-1 : 0]   rs1_addr_i,
    input  [NRLEN-1 : 0]   rs2_addr_i,
    input  [NRLEN-1 : 0]   rs3_addr_i,

    // from Writeback
    input                  rd_we_i,
    input  [NRLEN-1 : 0]   rd_addr_i,
    input  [XLEN-1 : 0]    rd_data_i,
    input                  fld_upperhalf_i,
    input                  fld_lowerhalf_i,
    input  [2*XLEN-1 : 0]  rd_f_data_i,
    input                  rd_fp32_load_i,
    input                  rd_fp64_load_i,
    
    // to Decode
    
    output [2*XLEN-1 : 0]  rs1_f_data_o,
    output [2*XLEN-1 : 0]  rs2_f_data_o,
    output [2*XLEN-1 : 0]  rs3_f_data_o,

    output reg            fld_fin_o
);

wire f_we = rd_we_i & rd_we_i;                          // generic FP write 
wire flw_we    = rd_we_i & rd_we_i & rd_fp32_load_i;    // FLW writes lower 32-bit
wire fld_up_we = rd_we_i & rd_we_i & fld_upperhalf_i;   // FLD writes upper 32-bit 
wire fld_low_we= rd_we_i & rd_we_i & fld_lowerhalf_i;   // FLD writes lower 32-bit

reg [2*XLEN-1 : 0] f[0 : NUM_REGS-1];

assign rs1_f_data_o = (f_we & (rs1_addr_i == rd_addr_i) & !rd_fp32_load_i & !rd_fp64_load_i) ? rd_f_data_i : (fld_up_we & (rs1_addr_i == rd_addr_i) & rd_fp64_load_i) ? {rd_data_i, f[rs1_addr_i][31:0]} : ((rs1_addr_i == rd_addr_i) & rd_fp32_load_i) ? {32'hffffffff, rd_data_i} : f[rs1_addr_i];
assign rs2_f_data_o = (f_we & (rs2_addr_i == rd_addr_i) & !rd_fp32_load_i & !rd_fp64_load_i) ? rd_f_data_i : (fld_up_we & (rs2_addr_i == rd_addr_i) & rd_fp64_load_i) ? {rd_data_i, f[rs2_addr_i][31:0]} : ((rs2_addr_i == rd_addr_i) & rd_fp32_load_i) ? {32'hffffffff, rd_data_i} : f[rs2_addr_i];
assign rs3_f_data_o = (f_we & (rs3_addr_i == rd_addr_i) & !rd_fp32_load_i & !rd_fp64_load_i) ? rd_f_data_i : (fld_up_we & (rs3_addr_i == rd_addr_i) & rd_fp64_load_i) ? {rd_data_i, f[rs3_addr_i][31:0]} : ((rs3_addr_i == rd_addr_i) & rd_fp32_load_i) ? {32'hffffffff, rd_data_i} : f[rs3_addr_i];

wire [2*XLEN-1 : 0] ft0  = f[ 0];   // fp temporary register, ft0
wire [2*XLEN-1 : 0] ft1  = f[ 1];   // fp temporary register, ft1
wire [2*XLEN-1 : 0] ft2  = f[ 2];   // fp temporary register, ft2
wire [2*XLEN-1 : 0] ft3  = f[ 3];   // fp temporary register, ft3
wire [2*XLEN-1 : 0] ft4  = f[ 4];   // fp temporary register, ft4
wire [2*XLEN-1 : 0] ft5  = f[ 5];   // fp temporary register, ft5
wire [2*XLEN-1 : 0] ft6  = f[ 6];   // fp temporary register, ft6
wire [2*XLEN-1 : 0] ft7  = f[ 7];   // fp temporary register, ft7
wire [2*XLEN-1 : 0] fs0  = f[ 8];   // fp register store, fs0
wire [2*XLEN-1 : 0] fs1  = f[ 9];   // fp register store, fs1
wire [2*XLEN-1 : 0] fa0  = f[10];   // fp function argument, fa0
wire [2*XLEN-1 : 0] fa1  = f[11];   // fp function argument, fa1
wire [2*XLEN-1 : 0] fa2  = f[12];   // fp function argument, fa2
wire [2*XLEN-1 : 0] fa3  = f[13];   // fp function argument, fa3
wire [2*XLEN-1 : 0] fa4  = f[14];   // fp function argument, fa4
wire [2*XLEN-1 : 0] fa5  = f[15];   // fp function argument, fa5
wire [2*XLEN-1 : 0] fa6  = f[16];   // fp function argument, fa6
wire [2*XLEN-1 : 0] fa7  = f[17];   // fp function argument, fa7
wire [2*XLEN-1 : 0] fs2  = f[18];   // fp register store, fs2
wire [2*XLEN-1 : 0] fs3  = f[19];   // fp register store, fs3
wire [2*XLEN-1 : 0] fs4  = f[20];   // fp register store, fs4
wire [2*XLEN-1 : 0] fs5  = f[21];   // fp register store, fs5
wire [2*XLEN-1 : 0] fs6  = f[22];   // fp register store, fs6
wire [2*XLEN-1 : 0] fs7  = f[23];   // fp register store, fs7
wire [2*XLEN-1 : 0] fs8  = f[24];   // fp register store, fs8
wire [2*XLEN-1 : 0] fs9  = f[25];   // fp register store, fs9
wire [2*XLEN-1 : 0] fs10 = f[26];   // fp register store, fs10
wire [2*XLEN-1 : 0] fs11 = f[27];   // fp register store, fs11
wire [2*XLEN-1 : 0] ft8  = f[28];   // fp temporary register, ft8
wire [2*XLEN-1 : 0] ft9  = f[29];   // fp temporary register, ft9
wire [2*XLEN-1 : 0] ft10  = f[30];  // fp temporary register, ft10
wire [2*XLEN-1 : 0] ft11  = f[31];  // fp temporary register, ft11

reg fld_up_we_r;

always @(posedge clk_i)
begin
    if(fld_up_we)
    begin
        f[rd_addr_i][63:32] <= rd_data_i;
    end
    else if(fld_low_we)
    begin
        f[rd_addr_i][31:0] <= rd_data_i;
    end
    else if(flw_we)
    begin
        f[rd_addr_i] <= {32'hffffffff, rd_data_i};
    end
    else if(f_we)
    begin
        f[rd_addr_i] <= rd_f_data_i;
    end
    fld_up_we_r <= fld_up_we;
    fld_fin_o <= fld_up_we_r; // FLD completion signal
end

endmodule
