`timescale 1ns / 1ps
// =============================================================================
//  Program : fp_forwarding_unit.v
//  Author  : Sin-Ying Li
//  Date    : Aug/19/2025
// -----------------------------------------------------------------------------
//  Description:
//  This is the Floating Point Data Forwarding Unit of the Aquila core (A RISC-V core).
//  Based on forwarding_unit.v (Aquila core) by Jin-you Wu, Dec/18/2018.
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

module fp_forwarding_unit #( parameter XLEN = 32 )
(
    // Register data from Decode
    input  [4: 0]         dec2fwd_rs1_addr_i,
    input  [4: 0]         dec2fwd_rs2_addr_i,
    input  [4: 0]         dec2fwd_rs3_addr_i,
    input  [2*XLEN-1 : 0] dec2fwd_rs1_f_data_i,
    input  [2*XLEN-1 : 0] dec2fwd_rs2_f_data_i,
    input  [2*XLEN-1 : 0] dec2fwd_rs3_f_data_i,
    input                 dec2fwd_rs1_fpr_i,
    input                 dec2fwd_rs2_fpr_i,
    input                 dec2fwd_rs3_fpr_i,

    // Register data from Execute
    input  [4: 0]         exe2mem_rd_addr_i,
    input  [2*XLEN-1 : 0] exe2mem_p_f_data_i,
    input                 exe2mem_rd_fpr_we_i,
    input  [XLEN-1 : 0]   exe2mem_p_data_i,

    input                 exe2fwd_fp64_load_use_i,

    // Register data from Writeback
    input  [4: 0]         wbk2rfu_rd_addr_i,
    input  [2*XLEN-1 : 0] wbk2rfu_rd_f_data_i,
    input                 wbk2rfu_rd_fpr_we_i,
    input  [XLEN-1 : 0]   wbk2rfu_rd_data_i,

    input                 fwd_flw_use_i,

    // to Execution Stage
    output [2*XLEN-1 : 0] fwd2exe_rs1_f_data_o,
    output [2*XLEN-1 : 0] fwd2exe_rs2_f_data_o,
    output [2*XLEN-1 : 0] fwd2exe_rs3_f_data_o
);

wire is_rs1_rd_EXE_MEM_same, is_rs2_rd_EXE_MEM_same, is_rs3_rd_EXE_MEM_same;
wire is_rs1_rd_MEM_WB_same, is_rs2_rd_MEM_WB_same, is_rs3_rd_MEM_WB_same;

wire rs1_f_EXE_MEM_fwd, rs2_f_EXE_MEM_fwd, rs3_f_EXE_MEM_fwd;
wire rs1_f_MEM_WB_fwd, rs2_f_MEM_WB_fwd, rs3_f_MEM_WB_fwd;
wire rs1_fp64_LoadUse_fwd, rs2_fp64_LoadUse_fwd, rs3_fp64_LoadUse_fwd;

wire [2*XLEN-1 : 0] correct_rs1_f_data, correct_rs2_f_data, correct_rs3_f_data;
wire [2*XLEN-1 : 0] correct_fwd_f_src1, correct_fwd_f_src2;
wire [XLEN-1 : 0] correct_fwd_src1;
wire [XLEN-1 : 0] correct_fwd_src2;

assign is_rs1_rd_EXE_MEM_same   = (dec2fwd_rs1_addr_i == exe2mem_rd_addr_i);
assign is_rs2_rd_EXE_MEM_same   = (dec2fwd_rs2_addr_i == exe2mem_rd_addr_i);
assign is_rs3_rd_EXE_MEM_same   = (dec2fwd_rs3_addr_i == exe2mem_rd_addr_i);
assign is_rs1_rd_MEM_WB_same    = (dec2fwd_rs1_addr_i == wbk2rfu_rd_addr_i);
assign is_rs2_rd_MEM_WB_same    = (dec2fwd_rs2_addr_i == wbk2rfu_rd_addr_i);
assign is_rs3_rd_MEM_WB_same    = (dec2fwd_rs3_addr_i == wbk2rfu_rd_addr_i);

assign rs1_f_EXE_MEM_fwd = exe2mem_rd_fpr_we_i & is_rs1_rd_EXE_MEM_same & dec2fwd_rs1_fpr_i;
assign rs2_f_EXE_MEM_fwd = exe2mem_rd_fpr_we_i & is_rs2_rd_EXE_MEM_same & dec2fwd_rs2_fpr_i;
assign rs3_f_EXE_MEM_fwd = exe2mem_rd_fpr_we_i & is_rs3_rd_EXE_MEM_same & dec2fwd_rs3_fpr_i;
assign rs1_f_MEM_WB_fwd  = wbk2rfu_rd_fpr_we_i & is_rs1_rd_MEM_WB_same & dec2fwd_rs1_fpr_i;
assign rs2_f_MEM_WB_fwd  = wbk2rfu_rd_fpr_we_i & is_rs2_rd_MEM_WB_same & dec2fwd_rs2_fpr_i;
assign rs3_f_MEM_WB_fwd  = wbk2rfu_rd_fpr_we_i & is_rs3_rd_MEM_WB_same & dec2fwd_rs3_fpr_i;
assign rs1_fp64_LoadUse_fwd  = dec2fwd_rs1_fpr_i & exe2fwd_fp64_load_use_i;
assign rs2_fp64_LoadUse_fwd  = dec2fwd_rs2_fpr_i & exe2fwd_fp64_load_use_i;
assign rs3_fp64_LoadUse_fwd  = dec2fwd_rs3_fpr_i & exe2fwd_fp64_load_use_i;

assign correct_fwd_f_src1 = exe2mem_p_f_data_i; 
assign correct_fwd_f_src2 = wbk2rfu_rd_f_data_i;
assign correct_fwd_src1 = exe2mem_p_data_i; 
assign correct_fwd_src2 = wbk2rfu_rd_data_i;

// On FP64 load-use, stall until WB completes and use the FPR read (no forwarding).
assign correct_rs1_f_data =
       rs1_fp64_LoadUse_fwd ? dec2fwd_rs1_f_data_i
       : rs1_f_EXE_MEM_fwd ? correct_fwd_f_src1
       : (rs1_f_MEM_WB_fwd & fwd_flw_use_i) ? {32'hffffffff, correct_fwd_src2}
       : rs1_f_MEM_WB_fwd ? correct_fwd_f_src2
       : dec2fwd_rs1_f_data_i;

assign correct_rs2_f_data =
       rs2_fp64_LoadUse_fwd ? dec2fwd_rs2_f_data_i
       : rs2_f_EXE_MEM_fwd ? correct_fwd_f_src1
       : (rs2_f_MEM_WB_fwd & fwd_flw_use_i) ? {32'hffffffff, correct_fwd_src2}
       : rs2_f_MEM_WB_fwd ? correct_fwd_f_src2
       : dec2fwd_rs2_f_data_i;

assign correct_rs3_f_data =
       rs3_fp64_LoadUse_fwd ? dec2fwd_rs3_f_data_i
       : rs3_f_EXE_MEM_fwd ? correct_fwd_f_src1
       : (rs3_f_MEM_WB_fwd & fwd_flw_use_i) ? {32'hffffffff, correct_fwd_src2}
       : rs3_f_MEM_WB_fwd ? correct_fwd_f_src2
       : dec2fwd_rs3_f_data_i;

// ================================================================================
//  Outputs signals
//
assign fwd2exe_rs1_f_data_o = correct_rs1_f_data;
assign fwd2exe_rs2_f_data_o = correct_rs2_f_data;
assign fwd2exe_rs3_f_data_o = correct_rs3_f_data;

endmodule   // forwarding
