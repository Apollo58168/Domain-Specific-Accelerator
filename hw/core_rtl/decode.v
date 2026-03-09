`timescale 1ns / 1ps
// =============================================================================
//  Program : decode.v
//  Author  : Jin-you Wu
//  Date    : Dec/19/2018
// -----------------------------------------------------------------------------
//  Description:
//  This is the Decoding Unit of the Aquila core (A RISC-V core).
// -----------------------------------------------------------------------------
//  Revision information:
//
//  Nov/29/2019, by Chun-Jen Tsai:
//    Merges the pipeline register moduel 'decode_execute' into the 'decode'
//    module.
//
//  Feb/10/2022, by Che-Yu Wu:
//    Add load-hazard detection for amo instructions.
//
//  Aug/19/2025, by Sin-Ying Li:
//    Integrate RV32F/D decode across the stage. 
//    Add FP control signals and hazard outputs for FP64 load-use and
//    LS structural cases.
// -----------------------------------------------------------------------------
//  License information:
//
//  This software is released under the BSD-3-Clause Licence,
//  see https://opensource.org/licenses/BSD-3-Clause for details.
//  In the following license statements, "software" refers to the
//  "source code" of the complete hardware/software system.
//
//  Copyright 2019,
//                    Embedded Intelligent Systems Lab (EISL)
//                    Deparment of Computer Science
//                    National Chiao Tung Uniersity
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

module decode #(parameter XLEN = 32, DLEN = 64)
(
    //  Processor clock and reset signals.
    input                   clk_i,
    input                   rst_i,

    // Pipeline stall signal.
    input                   stall_i,

    // Pipeline flush signal.
    input                   flush_i,

    // From Fetch.
    input  [XLEN-1 : 0]     pc_i,
    input  [XLEN-1 : 0]     instruction_i,
    input                   branch_hit_i,
    input                   branch_decision_i,

    // From CSR
    input  [XLEN-1 : 0]     csr_data_i,
    input  [ 1 : 0]         privilege_lvl_i,

    // Instruction operands from the Register File. To be forwarded.
    input  [XLEN-1 : 0]     rs1_data_i,
    input  [XLEN-1 : 0]     rs2_data_i,

    // to Pipeline Control
    output                  is_load_hazard_o,

    // Operand register IDs to the RFU
    output [ 4 : 0]         rs1_addr_o,
    output [ 4 : 0]         rs2_addr_o,

    // illegal
    output                  unsupported_instr_o,

    // to Execute
    output reg [XLEN-1 : 0] imm_o,
    output reg              csr_we_o,
    output reg [ 1 : 0]     inputA_sel_o,
    output reg [ 1 : 0]     inputB_sel_o,
    output reg [ 2 : 0]     operation_sel_o,
    output reg              alu_muldiv_sel_o,
    output reg              shift_sel_o,
    output reg              branch_hit_o,
    output reg              branch_decision_o,
    output reg              is_jalr_o,
    output reg              is_fencei_o,

    // to Execute and BPU
    output reg [XLEN-1 : 0] pc_o, // also to CSR
    output reg              is_branch_o,
    output reg              is_jal_o,

    // to CSR
    output     [11 : 0]     csr_addr_o,
    output reg [ 4 : 0]     csr_imm_o,

    // to Execute
    output reg [ 2 : 0]     rd_input_sel_o,
    output reg [ 4 : 0]     rd_addr_o,
    output reg              rd_we_o,
    output reg              signex_sel_o, // sign-extension select

    output reg              we_o,
    output reg              re_o,
    output reg [ 1 : 0]     dsize_sel_o,  // data size select
    output reg              is_amo_o,
    output reg [ 4 : 0]     amo_type_o,

    // to Forwarding_Unit
    output reg [4 : 0]      rs1_addr2fwd_o,
    output reg [4 : 0]      rs2_addr2fwd_o,
    output reg [XLEN-1 : 0] rs1_data2fwd_o,
    output reg [XLEN-1 : 0] rs2_data2fwd_o,
    output reg [11 : 0]     csr_addr2fwd_o,
    output reg [XLEN-1 : 0] csr_data2fwd_o,

    // System Jump operation
    output reg              sys_jump_o,
    output reg [ 1 : 0]     sys_jump_csr_addr_o,

     // Has instruction fetch being successiful?
    input                   fetch_valid_i,
    output reg              fetch_valid_o,

    // Exception info passed from Fetch to Execute.
    input                   xcpt_valid_i,
    input  [ 3 : 0]         xcpt_cause_i,
    input  [XLEN-1 : 0]     xcpt_tval_i,
    output reg              xcpt_valid_o,
    output reg [ 3 : 0]     xcpt_cause_o,
    output reg [XLEN-1 : 0] xcpt_tval_o

`ifdef ENABLE_FPU
    ,
    // FPU related signals ------------------------------------------
    // 1) Stall signal
    input                   stall_fp64_load_use_i, // hold Decode waiting for FP64 load data

    // 2) Operands from/to Register files
    input  [DLEN-1 : 0]     rs1_f_data_i,
    input  [DLEN-1 : 0]     rs2_f_data_i,
    input  [DLEN-1 : 0]     rs3_f_data_i,
    output [ 4 : 0]         rs3_addr_o,

    // 3) to Execute
    output reg [ 1 : 0]     f_inputA_sel_o,
    output reg [ 1 : 0]     f_inputB_sel_o,
    output reg [ 1 : 0]     f_inputC_sel_o,
    output reg              rd_fpr_we_o,
    output reg              fp_op_o,
    output reg  [ 6 : 0]    fp_func_sel_o,
    output reg  [ 4 : 0]    fp_unit_sel_o,
    output reg              fp64_ls_o, 
    output reg              fp32_load_o,
    output reg              fp32_store_o,
    output reg              fp64_load_o,

    // 4) to Pipeline control
    output                  is_fp64_load_use_o, 
    output                  is_fp64_ls_struct_o, 

    // 5) to Forwarding unit
    output reg [4 : 0]      rs3_addr2fwd_o,
    output reg [DLEN-1 : 0] rs1_f_data2fwd_o,
    output reg [DLEN-1 : 0] rs2_f_data2fwd_o,
    output reg [DLEN-1 : 0] rs3_f_data2fwd_o,
    output reg              dec2fwd_rs1_fpr_o,
    output reg              dec2fwd_rs2_fpr_o,
    output reg              dec2fwd_rs3_fpr_o
`endif // ENABLE_FPU
);

// Interal signals of the Decode Stage.
reg  [ 2 : 0]     rd_input_sel;
wire [ 4 : 0]     rd_addr;
wire              rd_we;
wire              signex_sel;     // for lb, lbu, lh and lhu.

wire              we;
wire              re;
wire [XLEN-1 : 0] imm;
reg  [ 1 : 0]     inputA_sel;
reg  [ 1 : 0]     inputB_sel;
wire [ 2 : 0]     operation_sel;
wire [ 1 : 0]     dsize_sel;
wire              alu_muldiv_sel; // for rv32m operation.
wire              shift_sel;      // for shift right operation.
wire [ 4 : 0]     csr_imm;

`ifdef ENABLE_FPU
// FPU related signals
wire              rd_fpr_we;      // commit to FP reg file
wire              fp32_load;
wire              fp32_store;
wire              fp64_load;
reg  [ 1 : 0]     f_inputA_sel;
reg  [ 1 : 0]     f_inputB_sel;
reg  [ 1 : 0]     f_inputC_sel;

// rs*_fpr: 1=FPR, 0=GPR
wire              rs1_fpr;
wire              rs2_fpr;
wire              rs3_fpr;

wire [ 6 : 0]     fp_func_sel;    // select which FPIP should use
wire [ 4 : 0]     fp_unit_sel;    //  which fp operation it is
wire              fp_op;          // whether the instruction is FP-related
`endif

/* *******************************************************************************
 * Info Signals Description                                                      *
 * ----------------------------------------------------------------------------- *
 *      There are 2 inputs for the exe:                                          *
 *          # inputA has 3 possible sources, determined by inputA_sel:           *
 *              (0) 0 (LUI)                                                      *
 *              (1) pc (AUIPC, JAL, BRANCH)                                      *
 *              (2) rs1                                                          *
 *          # inputB has 2 possible sources, determined by inputB_sel:           *
 *              (0) imm                                                          *
 *              (1) rs2                                                          *
 * ----------------------------------------------------------------------------- *
 *      There are 3 inputs for the floating point exe:                           *
 *          # inputA has 3 possible sources, determined by f_inputA_sel:         *
 *              (0) rs1                                                          *
 *              (1) -rs1 (single precision)                                      *
 *              (2) -rs1 (double precision)                                      *
 *          # inputB has 3 possible sources, determined by f_inputB_sel:         *
 *              (0) rs2                                                          *
 *              (1) -rs2 (single precision)                                      *
 *              (2) -rs2 (double precision)                                      *
 *          # inputB has 3 possible sources, determined by f_inputC_sel:         *
 *              (0) rs3                                                          *
 *              (1) -rs3 (single precision)                                      *
 *              (2) -rs3 (double precision)                                      *
 * ----------------------------------------------------------------------------- *
 *      There are 6 possible input sources to the register file, determined by   *
 *      rd_input_sel:                                                            *
 *              (0) one byte from data memory                                    *
 *              (1) a half word from data memory                                 *
 *              (2) one word from data memory                                    *
 *              (3) pc + 4 (pc of next instruction)                              *
 *              (4) execute result                                               *
 *              (5) csr value                                                    *
 * ----------------------------------------------------------------------------- *
 *      Usage of operation_sel are listed below:                                 *
 *          # Conditional branch                                                 *
 *              (0) 3'b000 : equal                                               *
 *              (1) 3'b001 : not equal                                           *
 *              (2) 3'b100 : less than                                           *
 *              (3) 3'b101 : greater than or equal to                            *
 *              (4) 3'b110 : less than unsigned                                  *
 *              (5) 3'b111 : greater than or equal to                            *
 *          # RVI, alu_muldiv_sel = 0                                            *
 *              (0) 3'b000 : add (add/sub)                                       *
 *              (1) 3'b001 : sll (shift left logic)                              *
 *              (2) 3'b010 : slt (set less than)                                 *
 *              (3) 3'b011 : sltu (set less than unsigned)                       *
 *              (4) 3'b100 : xor                                                 *
 *              (5) 3'b101 : sr (shift right logic/arithmetic)                   *
 *              (6) 3'b110 : or                                                  *
 *              (7) 3'b111 : and                                                 *
 *          # RVM, alu_muldiv_sel = 1                                            *
 *              (0) 3'b000 : mul                                                 *
 *              (1) 3'b001 : mulh                                                *
 *              (2) 3'b010 : mulhsu                                              *
 *              (3) 3'b011 : mulhu                                               *
 *              (4) 3'b100 : div                                                 *
 *              (5) 3'b101 : divu                                                *
 *              (6) 3'b110 : rem                                                 *
 *              (7) 3'b111 : remu                                                *
 *          # RVI, CSR instructions  (csr_op)                                    *
 *              (0) 3'b001 : csrrw                                               *
 *              (1) 3'b010 : csrrs                                               *
 *              (2) 3'b011 : csrrc                                               *
 *              (3) 3'b101 : csrrwi                                              *
 *              (4) 3'b110 : csrrsi                                              *
 *              (5) 3'b111 : csrrci                                              *
 * ----------------------------------------------------------------------------- *
 *      Bytes of load data or store data, determined by data_size_sel            *
 *              (0) 2'b00 : byte                                                 *
 *              (1) 2'b01 : half word                                            *
 *              (2) 2'b10 : word                                                 *
 * *******************************************************************************/

wire [XLEN-1 : 0] rv32_instr = instruction_i;
wire [ 6 : 0]     opcode = rv32_instr[6: 0];
wire [ 4 : 0]     rv32_shamt = rv32_instr[24: 20];
wire [ 1 : 0]     rv32_funct2 = rv32_instr[26: 25];
wire [ 2 : 0]     rv32_funct3 = rv32_instr[14: 12];
wire [ 6 : 0]     rv32_funct7 = rv32_instr[XLEN-1 : 25];
wire [ 4 : 0]     amo_type = rv32_instr[XLEN-1 : 27];

wire [XLEN-1 : 0] immI, immS, immB, immU, immJ;
assign immI = { {21{rv32_instr[31]}}, rv32_instr[30: 25],
                 rv32_instr[24: 21], rv32_instr[20] };
assign immS = { {21{rv32_instr[31]}}, rv32_instr[30: 25], rv32_instr[11: 7] };
assign immB = { {20{rv32_instr[31]}}, rv32_instr[7],
                 rv32_instr[30: 25], rv32_instr[11: 8], 1'b0 };
assign immU = { rv32_instr[31: 12], 12'b0 };
assign immJ = { {12{rv32_instr[31]}}, rv32_instr[19: 12],
                rv32_instr[20], rv32_instr[30: 25], rv32_instr[24: 21], 1'b0 };

// ================================================================================
//  We generate the signals and reused them as much as possible to save gate counts
//
// wire opcode_1_0_00 = (opcode[1:0] == 2'b00);  // rvc
// wire opcode_1_0_01 = (opcode[1:0] == 2'b01);  // rvc
// wire opcode_1_0_10 = (opcode[1:0] == 2'b10);  // rvc
wire opcode_1_0_11 = (opcode[1: 0] == 2'b11); // rv32

wire opcode_4_2_000 = (opcode[4: 2] == 3'b000);
wire opcode_4_2_001 = (opcode[4: 2] == 3'b001);
wire opcode_4_2_010 = (opcode[4: 2] == 3'b010);
wire opcode_4_2_011 = (opcode[4: 2] == 3'b011);
wire opcode_4_2_100 = (opcode[4: 2] == 3'b100);
wire opcode_4_2_101 = (opcode[4: 2] == 3'b101);
wire opcode_4_2_110 = (opcode[4: 2] == 3'b110);
wire opcode_4_2_111 = (opcode[4: 2] == 3'b111);

wire opcode_6_5_00 = (opcode[6: 5] == 2'b00);
wire opcode_6_5_01 = (opcode[6: 5] == 2'b01);
wire opcode_6_5_10 = (opcode[6: 5] == 2'b10);
wire opcode_6_5_11 = (opcode[6: 5] == 2'b11);

wire rv32_funct3_000 = (rv32_funct3 == 3'b000);
wire rv32_funct3_001 = (rv32_funct3 == 3'b001);
wire rv32_funct3_010 = (rv32_funct3 == 3'b010);
wire rv32_funct3_011 = (rv32_funct3 == 3'b011);
wire rv32_funct3_100 = (rv32_funct3 == 3'b100);
wire rv32_funct3_101 = (rv32_funct3 == 3'b101);
wire rv32_funct3_110 = (rv32_funct3 == 3'b110);
wire rv32_funct3_111 = (rv32_funct3 == 3'b111);

wire rv32_funct7_0000000 = (rv32_funct7 == 7'b0000000);
wire rv32_funct7_0100000 = (rv32_funct7 == 7'b0100000);
wire rv32_funct7_0000001 = (rv32_funct7 == 7'b0000001);
wire rv32_funct7_0000101 = (rv32_funct7 == 7'b0000101);
wire rv32_funct7_0001001 = (rv32_funct7 == 7'b0001001);
wire rv32_funct7_0001101 = (rv32_funct7 == 7'b0001101);
wire rv32_funct7_0010101 = (rv32_funct7 == 7'b0010101);
wire rv32_funct7_0100001 = (rv32_funct7 == 7'b0100001);
wire rv32_funct7_0010001 = (rv32_funct7 == 7'b0010001);
wire rv32_funct7_0101101 = (rv32_funct7 == 7'b0101101);
wire rv32_funct7_1111111 = (rv32_funct7 == 7'b1111111);
wire rv32_funct7_0000100 = (rv32_funct7 == 7'b0000100);
wire rv32_funct7_0001000 = (rv32_funct7 == 7'b0001000);
wire rv32_funct7_0001100 = (rv32_funct7 == 7'b0001100);
wire rv32_funct7_0101100 = (rv32_funct7 == 7'b0101100);
wire rv32_funct7_0010000 = (rv32_funct7 == 7'b0010000);
wire rv32_funct7_0010100 = (rv32_funct7 == 7'b0010100);
wire rv32_funct7_1100000 = (rv32_funct7 == 7'b1100000);
wire rv32_funct7_1110000 = (rv32_funct7 == 7'b1110000);
wire rv32_funct7_1010000 = (rv32_funct7 == 7'b1010000);
wire rv32_funct7_1101000 = (rv32_funct7 == 7'b1101000);
wire rv32_funct7_1111000 = (rv32_funct7 == 7'b1111000);
wire rv32_funct7_1010001 = (rv32_funct7 == 7'b1010001);
wire rv32_funct7_1110001 = (rv32_funct7 == 7'b1110001);
wire rv32_funct7_1100001 = (rv32_funct7 == 7'b1100001);
wire rv32_funct7_1101001 = (rv32_funct7 == 7'b1101001);

wire rv32_funct2_00 = (rv32_funct2 == 2'b00);
wire rv32_funct2_01 = (rv32_funct2 == 2'b01);

wire rv32_shamt_00000 = (rv32_shamt == 5'b00000);
wire rv32_shamt_00001 = (rv32_shamt == 5'b00001);

// ================================================================================
//  RV32I Opcode Classification
//
wire rv32_op = opcode_6_5_01 & opcode_4_2_100;      // OP opcode
wire rv32_op_imm = opcode_6_5_00 & opcode_4_2_100;  // OP-IMM opcode
wire rv32_jal = opcode_6_5_11 & opcode_4_2_011;     // JAL opcode
wire rv32_jalr = opcode_6_5_11 & opcode_4_2_001;    // JARL opcode
wire rv32_load = opcode_6_5_00 & opcode_4_2_000;    // LOAD opcode
wire rv32_store = opcode_6_5_01 & opcode_4_2_000;   // STORE opcode
wire rv32_branch = opcode_6_5_11 & opcode_4_2_000;  // BRANCH opcode
wire rv32_lui = opcode_6_5_01 & opcode_4_2_101;     // LUI opcode
wire rv32_auipc = opcode_6_5_00 & opcode_4_2_101;   // AUIPC opcode
wire rv32_miscmem = opcode_6_5_00 & opcode_4_2_011; // MISC-MEM opcode
wire rv32_system = opcode_6_5_11 & opcode_4_2_100;  // SYSTEM opcode
wire rv32_amo = opcode_6_5_01 & opcode_4_2_011;     // AMO opcode

wire rv32m = rv32_op & rv32_funct7_0000001;  // Mul, Div and Rem instructions

wire rv32_sub = rv32_op & rv32_funct3_000 & rv32_funct7_0100000;

// ================================================================================
//  RV32FD Opcode Classification
//
wire rv32_fp_op = opcode_6_5_10 & opcode_4_2_100;   // FD extension OP opcode
wire rv32_f_madd = opcode_6_5_10 & opcode_4_2_000;  // FD extension MADD opcode
wire rv32_f_msub = opcode_6_5_10 & opcode_4_2_001;  // FD extension MSUB opcode
wire rv32_f_nmsub = opcode_6_5_10 & opcode_4_2_010; // FD extension NMSUB opcode
wire rv32_f_nmadd = opcode_6_5_10 & opcode_4_2_011; // FD extension NMADD opcode
wire rv32_flw = opcode_6_5_00 & opcode_4_2_001 & rv32_funct3_010;     // FLW opcode
wire rv32_fsw = opcode_6_5_01 & opcode_4_2_001 & rv32_funct3_010;     // FSW opcode
wire rv32_fld = opcode_6_5_00 & opcode_4_2_001 & rv32_funct3_011;     // FLD opcode
wire rv32_fsd = opcode_6_5_01 & opcode_4_2_001 & rv32_funct3_011;     // FSD opcode

// ================================================================================
//  F extension operation
//
wire rv32_f_add_s = rv32_fp_op & rv32_funct7_0000000;
wire rv32_f_sub_s = rv32_fp_op & rv32_funct7_0000100;
wire rv32_f_mul_s = rv32_fp_op & rv32_funct7_0001000;
wire rv32_f_div_s = rv32_fp_op & rv32_funct7_0001100;
wire rv32_f_sqrt_s = rv32_fp_op & rv32_funct7_0101100;
wire rv32_f_min_s = rv32_fp_op & rv32_funct7_0010100 & rv32_funct3_000;
wire rv32_f_max_s = rv32_fp_op & rv32_funct7_0010100 & rv32_funct3_001;
wire rv32_f_madd_s = rv32_f_madd & rv32_funct2_00;
wire rv32_f_msub_s = rv32_f_msub & rv32_funct2_00;
wire rv32_f_nmsub_s = rv32_f_nmsub & rv32_funct2_00;
wire rv32_f_nmadd_s = rv32_f_nmadd & rv32_funct2_00;
wire rv32_f_sgnj_s = rv32_fp_op & rv32_funct7_0010000 & rv32_funct3_000;
wire rv32_f_sgnjn_s = rv32_fp_op & rv32_funct7_0010000 & rv32_funct3_001;
wire rv32_f_sgnjx_s = rv32_fp_op & rv32_funct7_0010000 & rv32_funct3_010;
wire rv32_f_cvt_w_s = rv32_fp_op & rv32_funct7_1100000 & rv32_shamt_00000;
wire rv32_f_cvt_wu_s = rv32_fp_op & rv32_funct7_1100000 & rv32_shamt_00001;
wire rv32_f_cvt_s_w = rv32_fp_op & rv32_funct7_1101000 & rv32_shamt_00000;
wire rv32_f_cvt_s_wu = rv32_fp_op & rv32_funct7_1101000 & rv32_shamt_00001;
wire rv32_f_mv_x_w_s = rv32_fp_op & rv32_funct7_1110000 & rv32_shamt_00000 & rv32_funct3_000; // f->i
wire rv32_f_mv_w_x_s = rv32_fp_op & rv32_funct7_1111000 & rv32_shamt_00000 & rv32_funct3_000;  // i->f
wire rv32_f_eq_s = rv32_fp_op & rv32_funct7_1010000 & rv32_funct3_010;
wire rv32_f_lt_s = rv32_fp_op & rv32_funct7_1010000 & rv32_funct3_001;
wire rv32_f_le_s = rv32_fp_op & rv32_funct7_1010000 & rv32_funct3_000; 
wire rv32_f_class_s = rv32_fp_op & rv32_funct7_1110000 & rv32_shamt_00000 & rv32_funct3_001; 

// ================================================================================
//  D extension operation
//
wire rv32_f_add_d = rv32_fp_op & rv32_funct7_0000001;
wire rv32_f_sub_d = rv32_fp_op & rv32_funct7_0000101;
wire rv32_f_mul_d = rv32_fp_op & rv32_funct7_0001001;
wire rv32_f_div_d = rv32_fp_op & rv32_funct7_0001101;
wire rv32_f_sqrt_d = rv32_fp_op & rv32_funct7_0101101;
wire rv32_f_min_d = rv32_fp_op & rv32_funct7_0010101 & rv32_funct3_000;
wire rv32_f_max_d = rv32_fp_op & rv32_funct7_0010101 & rv32_funct3_001;
wire rv32_f_madd_d = rv32_f_madd & rv32_funct2_01;
wire rv32_f_msub_d = rv32_f_msub & rv32_funct2_01;
wire rv32_f_nmsub_d = rv32_f_nmsub & rv32_funct2_01;
wire rv32_f_nmadd_d = rv32_f_nmadd & rv32_funct2_01;
wire rv32_f_sgnj_d = rv32_fp_op & rv32_funct7_0010001 & rv32_funct3_000;
wire rv32_f_sgnjn_d = rv32_fp_op & rv32_funct7_0010001 & rv32_funct3_001;
wire rv32_f_sgnjx_d = rv32_fp_op & rv32_funct7_0010001 & rv32_funct3_010;
wire rv32_f_cvt_w_d = rv32_fp_op & rv32_funct7_1100001 & rv32_shamt_00000;
wire rv32_f_cvt_wu_d = rv32_fp_op & rv32_funct7_1100001 & rv32_shamt_00001;
wire rv32_f_cvt_d_w = rv32_fp_op & rv32_funct7_1101001 & rv32_shamt_00000;
wire rv32_f_cvt_d_wu = rv32_fp_op & rv32_funct7_1101001 & rv32_shamt_00001;
wire rv32_f_cvt_s_d = rv32_fp_op & rv32_funct7_0100000 & rv32_shamt_00001;
wire rv32_f_cvt_d_s = rv32_fp_op & rv32_funct7_0100001 & rv32_shamt_00000;
wire rv32_f_eq_d = rv32_fp_op & rv32_funct7_1010001 & rv32_funct3_010;
wire rv32_f_lt_d = rv32_fp_op & rv32_funct7_1010001 & rv32_funct3_001;
wire rv32_f_le_d = rv32_fp_op & rv32_funct7_1010001 & rv32_funct3_000; 
wire rv32_f_class_d = rv32_fp_op & rv32_funct7_1110001 & rv32_shamt_00000 & rv32_funct3_001; 

wire rv32_imm_seli = rv32_op_imm | rv32_jalr | rv32_load | rv32_flw | rv32_fld;
wire rv32_imm_sels = rv32_store | rv32_fsw | rv32_fsd;
wire rv32_imm_selb = rv32_branch;
wire rv32_imm_selu = rv32_lui | rv32_auipc;
wire rv32_imm_selj = rv32_jal;

// ================================================================================
//  Conditional Branch Instructions
//
wire rv32_beq = rv32_branch & rv32_funct3_000;
wire rv32_bne = rv32_branch & rv32_funct3_001;
wire rv32_blt = rv32_branch & rv32_funct3_100;
wire rv32_bgt = rv32_branch & rv32_funct3_101;
wire rv32_bltu = rv32_branch & rv32_funct3_110;
wire rv32_bgtu = rv32_branch & rv32_funct3_111;

// ================================================================================
//  MISC-MEM
wire rv32_fence  = rv32_miscmem & rv32_funct3_000;
wire rv32_fencei = rv32_miscmem & rv32_funct3_001;

// ================================================================================
//  System Instructions
//
wire rv32_csrrw = rv32_system & rv32_funct3_001;
wire rv32_csrrs = rv32_system & rv32_funct3_010;
wire rv32_csrrc = rv32_system & rv32_funct3_011;
wire rv32_csrrwi = rv32_system & rv32_funct3_101;
wire rv32_csrrsi = rv32_system & rv32_funct3_110;
wire rv32_csrrci = rv32_system & rv32_funct3_111;
wire rv32_csr = rv32_system & (~rv32_funct3_000);

wire rv32_sys_op = rv32_system & rv32_funct3_000;
wire rv32_ecall = rv32_sys_op & (rv32_instr[31: 20] == 12'b0000_0000_0000);
wire rv32_ebreak = rv32_sys_op & (rv32_instr[31: 20] == 12'b0000_0000_0001);
wire rv32_mret = rv32_sys_op & (rv32_instr[31: 20] == 12'b0011_0000_0010);
wire rv32_sret = rv32_sys_op & (rv32_instr[31: 20] == 12'b0001_0000_0010);

// ================================================================================
// Load/Store Instructions
//
wire rv32_lb = rv32_load & rv32_funct3_000;
wire rv32_lh = rv32_load & rv32_funct3_001;
wire rv32_lw = rv32_load & rv32_funct3_010;
wire rv32_lbu = rv32_load & rv32_funct3_100;
wire rv32_lhu = rv32_load & rv32_funct3_101;

wire rv32_sb = rv32_store & rv32_funct3_000;
wire rv32_sh = rv32_store & rv32_funct3_001;
wire rv32_sw = rv32_store & rv32_funct3_010;

// ================================================================================
// Supervisor Instructions
//
wire rv32_sfence_vma = rv32_funct7_0001001 && rv32_funct3_000 && opcode_6_5_11 && opcode_4_2_100 && opcode_1_0_11;
wire rv32_sfence_type = (rs1_addr_o != 0);

// Exception Signals
//
wire         rv32_legal_instr   = (rv32_op | rv32_op_imm | rv32_jal | rv32_jalr | rv32_load | rv32_store |
                                   rv32_branch | rv32_lui | rv32_auipc | rv32_miscmem | rv32_system | rv32_amo |
                                   rv32_fp_op | rv32_f_madd | rv32_f_msub | rv32_f_nmadd | rv32_f_nmsub |
                                   rv32_flw | rv32_fsw | rv32_fld | rv32_fsd)
                                   & opcode_1_0_11; //indicate whether instruction_i is supported, rv32_instr[1:0] should hardwired to 2'b11
wire         rv32_shift         = rv32_op_imm & (rv32_funct3_001 | rv32_funct3_101) ; // slli, srli, srai instructions                                 
wire         rv32_illegal_shift = rv32_shift & rv32_instr[25]; //shmnt[5](rv32_instr[25]) of shift instructions should be 0
wire         rv32_time          = rv32_csr && (csr_addr_o == 12'hC01);
wire         rv32_timeh         = rv32_csr && (csr_addr_o == 12'hC81);
wire         rv32_stimecmp      = rv32_csr && (csr_addr_o == 12'h14D);
wire         rv32_stimecmph     = rv32_csr && (csr_addr_o == 12'h15D);
wire         rv32_scountovf     = rv32_csr && (csr_addr_o == 12'hDA0);
wire         rv32_mtopi         = rv32_csr && (csr_addr_o == 12'hFB0);
wire         rv32_mstateen0     = rv32_csr && (csr_addr_o == 12'h30C);

// shuold handle in csr_file or it will add a lot of signals here.
wire         rv32_unsupport_csr = rv32_time || rv32_timeh || rv32_stimecmp || rv32_stimecmph
                                  || rv32_scountovf || rv32_mtopi || rv32_mstateen0;
wire         rv32_illegal_XRET  = (rv32_mret && privilege_lvl_i != 2'b11) || (rv32_sret && privilege_lvl_i == 2'b00); // XRET in wrong mode
wire         rv32_illegal_instr_xcpt = !rv32_legal_instr || rv32_illegal_shift 
                                       || rv32_illegal_XRET
                                       || rv32_unsupport_csr; // to indicate whether illegal instruction excetopn occured

wire         xcpt_valid = rv32_ecall | rv32_ebreak | rv32_illegal_instr_xcpt;
wire [ 3: 0] xcpt_cause = (rv32_ecall)? (privilege_lvl_i == 2'b11)? 'd11 : (privilege_lvl_i == 2'b01)? 'd9 : 'd8
                        : (rv32_ebreak)? 'd3
                        : (rv32_illegal_instr_xcpt)? 'd2
                        : 'd0;
wire [31: 0] xcpt_tval  = (rv32_illegal_instr_xcpt)? instruction_i : 0;

// ================================================================================
//  Output Signals
//
assign imm =
       ({32{rv32_imm_seli}} & immI)
       | ({32{rv32_imm_sels}} & immS)
       | ({32{rv32_imm_selb}} & immB)
       | ({32{rv32_imm_selu}} & immU)
       | ({32{rv32_imm_selj}} & immJ)
       ;

// All the RV32IMA need rd except the
//   # BRANCH, STORE,
//   # FENCE, FENCE.I
//   # ECALL, EBREAK

`ifdef ENABLE_FPU
assign rd_we = rv32_op | rv32_csr | rv32_amo | rv32_jal | rv32_jalr |
               rv32_f_cvt_w_s | rv32_f_cvt_wu_s | rv32_f_cvt_w_d |
               rv32_f_cvt_wu_d | rv32_f_mv_x_w_s | rv32_f_eq_s |
               rv32_f_lt_s | rv32_f_le_s | rv32_f_eq_d | rv32_f_lt_d |
               rv32_f_le_d | rv32_f_class_s | rv32_f_class_d |
               rv32_lui | rv32_auipc | rv32_load | rv32_op_imm;

assign re = rv32_load | rv32_flw | rv32_amo | rv32_fld; // AMO instr. also need to load d-cache data 
assign we = rv32_store | rv32_fsw | rv32_fsd; 

assign fp32_load = rv32_flw;
assign fp32_store = rv32_fsw;
assign fp64_load = rv32_fld;
assign rd_fpr_we = rv32_flw | rv32_fld | rv32_f_madd | rv32_f_msub | rv32_f_nmsub | rv32_f_nmadd
                | (rv32_fp_op & ~rv32_f_cvt_w_s & ~rv32_f_cvt_wu_s & ~rv32_f_cvt_w_d & ~rv32_f_cvt_wu_d & ~rv32_f_mv_x_w_s & ~rv32_f_eq_s & ~rv32_f_lt_s & ~rv32_f_le_s & ~rv32_f_eq_d & ~rv32_f_lt_d & ~rv32_f_le_d & ~rv32_f_class_s & ~rv32_f_class_d); 
assign fp_op = rv32_fp_op | rv32_f_madd | rv32_f_msub | rv32_f_nmsub | rv32_f_nmadd;

// F extension operation sel : {1: add}, {2: sub}, {3: mul}, {4: div}, {5: sqrt}, {6: min}, {7: max}, {8: madd}, {9: msub}
                            // , {10: nmsub}, {11: nmadd}, {12: sgnj}, {13: sgnjn}, {14: sgnjx}, {15: cvt_w_s}, {16: cvt_wu_s}
                            // , {17: mv_x_w}, {18: mv_w_x}, {19: equal}, {20: less than}, {21: less equal}, {22: class}, {23: cvt_s_w}, {24: cvt_s_wu}
// D extension operation sel : {25: add}, {26: sub}, {27: mul}, {28: div}, {29: sqrt}, {30: min}, {31: max}, {32: madd}
                            // , {33: msub}, {34: nmsub}, {35: nmadd}, {36:sgnj}, {37: sgnjn}, {38: sgnjx}, {39: cvt_w_d}, {40: cvt_wu_d}
                            // , {41: cvt_d_s}, {42: cvt_s_d}, {43: equal}, {44: less than}, {45: less equal}, {46: class}, {47: cvt_d_w}, {48: cvt_d_wu}

assign fp_func_sel = rv32_f_add_s ? 1 : rv32_f_sub_s ? 2 : rv32_f_mul_s ? 3 : rv32_f_div_s ? 4 : rv32_f_sqrt_s ? 5 : rv32_f_min_s ? 6 : rv32_f_max_s ? 7 
                : rv32_f_madd_s ? 8 : rv32_f_msub_s ? 9 : rv32_f_nmsub_s ? 10 : rv32_f_nmadd_s ? 11 : rv32_f_sgnj_s ? 12 : rv32_f_sgnjn_s ? 13 : rv32_f_sgnjx_s ? 14
                : rv32_f_cvt_w_s ? 15 : rv32_f_cvt_wu_s ? 16 : rv32_f_mv_x_w_s ? 17 : rv32_f_mv_w_x_s ? 18 : rv32_f_eq_s ? 19 : rv32_f_lt_s ? 20 : rv32_f_le_s ? 21 
                : rv32_f_class_s ? 22 : rv32_f_cvt_s_w ? 23 : rv32_f_cvt_s_wu ? 24 : rv32_f_add_d ? 25 : rv32_f_sub_d ? 26 : rv32_f_mul_d ? 27 : rv32_f_div_d ? 28 
                : rv32_f_sqrt_d ? 29 : rv32_f_min_d ? 30 : rv32_f_max_d ? 31 : rv32_f_madd_d ? 32 : rv32_f_msub_d ? 33 : rv32_f_nmsub_d ? 34 : rv32_f_nmadd_d ? 35 
                : rv32_f_sgnj_d ? 36 : rv32_f_sgnjn_d ? 37 : rv32_f_sgnjx_d ? 38 : rv32_f_cvt_w_d ? 39 : rv32_f_cvt_wu_d ? 40 : rv32_f_cvt_d_s ? 41 : rv32_f_cvt_s_d ? 42 
                : rv32_f_eq_d ? 43 : rv32_f_lt_d ? 44 : rv32_f_le_d ? 45 : rv32_f_class_d ? 46 : rv32_f_cvt_d_w ? 47 : rv32_f_cvt_d_wu ? 48 : 0;

// fp unit sel : {1: s_add/sub}, {2: s_mul}, {3: s_div}, {4: s_sqrt}, {5: s_min/max/lt}, {6: s_madd/msub/nmadd/nmsub}
//             , {7: cvt_w_s, cvt_wu_s}, {8: s_eq}, {9: s_le}, {10: cvt_s_w}, {11: cvt_s_wu}, {12: d_add/sub}
//             , {13: d_mul}, {14: d_div}, {15: d_sqrt}, {16: d_min/max/lt}, {17: d_madd/msub/nmadd/nmsub}
//             , {18: cvt_w_d/cvt_wu_d}, {19: d_eq}, {20: d_le}, {21: cvt_d_w}, {22: cvt_d_wu}, {23: cvt_d_s}, {24: cvt_s_d}

assign fp_unit_sel = (rv32_f_add_s | rv32_f_sub_s) ? 1 : rv32_f_mul_s ? 2 : rv32_f_div_s ? 3 : rv32_f_sqrt_s ? 4 : (rv32_f_min_s | rv32_f_max_s | rv32_f_lt_s) ? 5 
                    : (rv32_f_madd_s | rv32_f_msub_s | rv32_f_nmsub_s | rv32_f_nmadd_s) ? 6 : (rv32_f_cvt_w_s | rv32_f_cvt_wu_s) ? 7 : rv32_f_eq_s ? 98
                    : rv32_f_le_s ? 9 : rv32_f_cvt_s_w ? 10 : rv32_f_cvt_s_wu ? 11 : (rv32_f_add_d | rv32_f_sub_d) ? 12 : rv32_f_mul_d ? 13 : rv32_f_div_d ? 14 
                    : rv32_f_sqrt_d ? 15 : (rv32_f_min_d | rv32_f_max_d | rv32_f_lt_d) ? 16 : (rv32_f_madd_d | rv32_f_msub_d | rv32_f_nmsub_d | rv32_f_nmadd_d) ? 17
                    : (rv32_f_cvt_w_d | rv32_f_cvt_wu_d) ? 18 : rv32_f_eq_d ? 19 : rv32_f_le_d ? 20 : rv32_f_cvt_d_w ? 21 : rv32_f_cvt_d_wu ? 22 
                    : rv32_f_cvt_d_s ? 23 : rv32_f_cvt_s_d ? 24 : 0;

assign rs1_fpr = (fp_op & ~rv32_f_cvt_s_w & ~rv32_f_cvt_s_wu & ~rv32_f_cvt_d_w & ~rv32_f_cvt_d_wu) | rv32_f_madd | rv32_f_msub | rv32_f_nmsub | rv32_f_nmadd; 
assign rs2_fpr = fp_op | rv32_fsw | rv32_fsd | rv32_f_madd | rv32_f_msub | rv32_f_nmsub | rv32_f_nmadd;
assign rs3_fpr = rv32_f_madd | rv32_f_msub | rv32_f_nmsub | rv32_f_nmadd;
assign rs3_addr_o = rv32_instr[31: 27];

`else
assign rd_we = rv32_lui | rv32_auipc | rv32_load | rv32_op_imm |
               rv32_op | rv32_csr | rv32_amo | rv32_jal | rv32_jalr;

assign re = rv32_load | rv32_amo; // AMO instr. also need to load d-cache data
assign we = rv32_store;

`endif // ENABLE_FPU

assign rd_addr = rv32_instr[11: 7];
assign rs1_addr_o = rv32_instr[19: 15];
assign rs2_addr_o = rv32_instr[24: 20];

assign dsize_sel = rv32_funct3[1: 0];             // {00: b}, {01: h}, {10: w}
assign signex_sel = rv32_funct3[2];               // {0: signed extension},
                                                  //     {1: unsigned extension}
assign alu_muldiv_sel = rv32m;                    // {0: rv32i op}, {1: rv32m op}
assign operation_sel = (rv32_lui | rv32_auipc) ?  // LUI and AUIPC use alu
       3'b000 : rv32_funct3;                      //      adder result
assign shift_sel = rv32_funct7_0100000;           // {0: logic}, {1: arithmetic}

assign csr_addr_o = rv32_instr[31: 20];
assign csr_imm = rv32_instr[19: 15];

// Detect load structure hazard.
wire is_r_type     = (rv32_op || rv32_system || rv32_fp_op) && opcode_1_0_11;
wire is_i_type     = (rv32_load || rv32_op_imm || rv32_jalr || rv32_flw || rv32_fld) && opcode_1_0_11;
wire is_s_type     = (rv32_store || rv32_fsw || rv32_fsd) && opcode_1_0_11;
wire is_r4_type    = (rv32_f_madd | rv32_f_msub | rv32_f_nmsub | rv32_f_nmadd) && opcode_1_0_11;

wire is_b_type     = rv32_branch && opcode_1_0_11;
wire is_fence      = rv32_fence && opcode_1_0_11;
wire is_csr_type   = (rv32_csrrw || rv32_csrrs || rv32_csrrc) && opcode_1_0_11;
wire is_amo_type   = rv32_amo && opcode_1_0_11;

`ifdef ENABLE_FPU
wire is_rs1_rd_same = (rs1_addr_o == rd_addr_o) && (!rs1_fpr && !rd_fpr_we_o) &&
                      (is_r_type || is_s_type || is_b_type || is_i_type ||
                       is_fence || is_csr_type || is_amo_type);
wire is_rs2_rd_same = (rs2_addr_o == rd_addr_o) && (!rs2_fpr && !rd_fpr_we_o) && (is_r_type || is_s_type || is_b_type);

wire is_rs1_rd_f_same = (rs1_addr_o == rd_addr_o) && rs1_fpr &&
                      (is_r_type || is_s_type || is_i_type || is_r4_type);
wire is_rs2_rd_f_same = (rs2_addr_o == rd_addr_o) && rs2_fpr && (is_r_type || is_s_type || is_r4_type);
wire is_rs3_rd_f_same = (rs3_addr_o == rd_addr_o) && rs3_fpr && is_r4_type;

reg is_fp64_load_use_r;

reg [XLEN-1 : 0] pc_r;
reg fp64_ls_r;
reg stall_r;

wire fp64_ls = ((pc_r != pc_i) && (rv32_fld | rv32_fsd)) || (fp64_ls_r && stall_r);

assign is_load_hazard_o = ((is_rs1_rd_same | is_rs2_rd_same) && re_o) | ((is_rs1_rd_f_same | is_rs2_rd_f_same | is_rs3_rd_f_same) && fp32_load_o);
assign is_fp64_load_use_o = ((is_rs1_rd_f_same | is_rs2_rd_f_same | is_rs3_rd_f_same) && fp64_load_o);  // stall from FP load use hazard
assign is_fp64_ls_struct_o = fp64_ls;   // stall from FP64 load structural (32-bit bus needs two data fetches)

always @(posedge clk_i)
begin
    if(stall_i)
    begin
        pc_r <= pc_r;
        fp64_ls_r <= fp64_ls_r;
        stall_r <= stall_r;
        is_fp64_load_use_r <= is_fp64_load_use_r;
        fp64_load_o <= fp64_load_o;
        fp32_load_o <= fp32_load_o;
        fp32_store_o <= fp32_store_o;
    end
    else
    begin
        pc_r <= pc_i;
        fp64_ls_r <= fp64_ls;
        stall_r <= stall_i;
        is_fp64_load_use_r <= is_fp64_load_use_o;
        fp64_load_o <= fp64_load;
        fp32_load_o <= fp32_load;
        fp32_store_o <= fp32_store;
    end
end

`else

wire is_rs1_rd_same = (rs1_addr_o == rd_addr_o) &&
                      (is_r_type || is_s_type || is_b_type || is_i_type ||
                       is_fence || is_csr_type || is_amo_type);
wire is_rs2_rd_same = (rs2_addr_o == rd_addr_o) && (is_r_type || is_s_type || is_b_type);

assign is_load_hazard_o = (is_rs1_rd_same | is_rs2_rd_same) && re_o;

`endif // ENABLE_FPU

always @(*)
begin
    if (rv32_auipc | rv32_jal | rv32_branch)
        inputA_sel = 1; // pc
    else if (rv32_lui | rv32_store | rv32_fsw | rv32_fsd) 
        inputA_sel = 0; // 0
    else
        inputA_sel = 2; // rs1
end

always @(*)
begin
    if (rv32_sub)
        inputB_sel = 2; // -rs2
    else if (rv32_store | rv32_op | rv32_fp_op | rv32_amo | rv32_fsw | rv32_fsd | is_r4_type)
        inputB_sel = 1; // rs2
    else
        inputB_sel = 0; // immediate
end

`ifdef ENABLE_FPU
always @(*)
begin
    if (rv32_f_nmadd_s | rv32_f_nmsub_s)
        f_inputA_sel = 1; // -rs1 (single precision)
    else if (rv32_f_nmadd_d | rv32_f_nmsub_d)
        f_inputA_sel = 2; // -rs1 (double precision)
    else
        f_inputA_sel = 0; // rs1
end

always @(*) 
begin
    if (rv32_f_sub_s)
        f_inputB_sel = 1; // -rs2 (single precision)
    else if (rv32_f_sub_d)
        f_inputB_sel = 2; // -rs2 (double precision)
    else
        f_inputB_sel = 0; // rs2
end

always @(*) 
begin
    if (rv32_f_msub_s | rv32_f_nmsub_s)
        f_inputC_sel = 1; // -rs3 (single precision)
    else if (rv32_f_msub_d | rv32_f_nmsub_d)
        f_inputC_sel = 2; // -rs3 (double precision)
    else
        f_inputC_sel = 0; // rs3
end
`endif // ENABLE_FPU

always @(*) 
begin
    if (rv32_lb | rv32_lbu)
        rd_input_sel = 0; // load byte
    else if (rv32_lh | rv32_lhu)
        rd_input_sel = 1; // load half word
    else if (rv32_lw | rv32_amo | rv32_flw | rv32_fld)
        rd_input_sel = 2; // load word
    else if (rv32_jal | rv32_jalr)
        rd_input_sel = 3; // pc+4
    else if (rv32_csr)
        rd_input_sel = 5; // csr
    else
        rd_input_sel = 4; // execute result
end

// the instructions that are not supported currently
assign unsupported_instr_o = rv32_fence | rv32_ebreak;

// ===============================================================================
//  Output registers to the Execute stage
//
always @(posedge clk_i)
begin
    if (rst_i || (flush_i && !stall_i)) // stall has higher priority than flush.
    begin
        pc_o <= (flush_i)? pc_i : 0;
        fetch_valid_o <= 0;
        rs1_data2fwd_o <= 0;
        rs2_data2fwd_o <= 0;
        imm_o <= 0;
        inputA_sel_o <= 2;
        inputB_sel_o <= 0;
        operation_sel_o <= 0;
        signex_sel_o <= 0;
        dsize_sel_o <= 0;
        alu_muldiv_sel_o <= 0;
        shift_sel_o <= 0;
        is_branch_o <= 0;
        is_jal_o <= 0;
        is_jalr_o <= 0;
        rd_we_o <= 1;
        rd_input_sel_o <= 4; // send Execute result into the RFU.
        we_o <= 0;
        re_o <= 0;
        dsize_sel_o <= 0;
        rd_addr_o <= 0;
        rs1_addr2fwd_o <= 0;
        rs2_addr2fwd_o <= 0;
        csr_we_o <= 0;
        csr_imm_o <= 0;
        branch_hit_o <= 0;
        branch_decision_o <= 0;
        is_fencei_o <= 0;
        amo_type_o <= 0;
        is_amo_o <= 0;

        sys_jump_o <= 0;
        sys_jump_csr_addr_o <= 0;
        xcpt_valid_o <= 0;
        xcpt_cause_o <= 0;
        xcpt_tval_o <= 0;
        csr_data2fwd_o <= 0;
        csr_addr2fwd_o <= 0;

`ifdef ENABLE_FPU
        // FPU signals
        rs1_f_data2fwd_o <= 0;
        rs2_f_data2fwd_o <= 0;
        rs3_f_data2fwd_o <= 0;
        dec2fwd_rs1_fpr_o <= 0;
        dec2fwd_rs2_fpr_o <= 0;
        dec2fwd_rs3_fpr_o <= 0;
        f_inputA_sel_o <= 0;
        f_inputB_sel_o <= 0;
        f_inputC_sel_o <= 0;
        fp_op_o <= 0;
        fp_func_sel_o <= 0;
        fp_unit_sel_o <= 0;
        fp64_ls_o <= 0;
        rd_fpr_we_o <= 0;
        rs3_addr2fwd_o <= 0;
`endif
    end
    else if (stall_i)
    begin
        pc_o <= pc_o;
        fetch_valid_o <= fetch_valid_o;
        rs1_data2fwd_o <= rs1_data2fwd_o;
        rs2_data2fwd_o <= rs2_data2fwd_o;
        imm_o <= imm_o;
        inputA_sel_o <= inputA_sel_o;
        inputB_sel_o <= inputB_sel_o;
        operation_sel_o <= operation_sel_o;
        signex_sel_o <= signex_sel_o;
        alu_muldiv_sel_o <= alu_muldiv_sel_o;
        shift_sel_o <= shift_sel_o;
        is_branch_o <= is_branch_o;
        is_jal_o <= is_jal_o;
        is_jalr_o <= is_jalr_o;
        rd_we_o <= rd_we_o;
        rd_input_sel_o <= rd_input_sel_o;
        we_o <= we_o;
        re_o <= re_o;
        dsize_sel_o <= dsize_sel_o;
        rd_addr_o <= rd_addr_o;
        rs1_addr2fwd_o <= rs1_addr2fwd_o;
        rs2_addr2fwd_o <= rs2_addr2fwd_o;
        csr_we_o <= csr_we_o;
        csr_imm_o <= csr_imm_o;
        branch_hit_o <= branch_hit_o;
        branch_decision_o <= branch_decision_o;
        is_fencei_o <= is_fencei_o;
        amo_type_o <= amo_type_o;
        is_amo_o <= is_amo_o;

        sys_jump_o <= sys_jump_o;
        sys_jump_csr_addr_o <= sys_jump_csr_addr_o;
        xcpt_valid_o <= xcpt_valid_o;
        xcpt_cause_o <= xcpt_cause_o;
        xcpt_tval_o <= xcpt_tval_o;
        csr_data2fwd_o <= csr_data2fwd_o;
        csr_addr2fwd_o <= csr_addr2fwd_o;

`ifdef ENABLE_FPU
        if (stall_fp64_load_use_i)
        begin
            rs1_f_data2fwd_o <= rs1_f_data_i;
            rs2_f_data2fwd_o <= rs2_f_data_i;
            rs3_f_data2fwd_o <= rs3_f_data_i;
        end
        else
        begin
            rs1_f_data2fwd_o <= rs1_f_data2fwd_o;
            rs2_f_data2fwd_o <= rs2_f_data2fwd_o;
            rs3_f_data2fwd_o <= rs3_f_data2fwd_o;
        end      
        f_inputA_sel_o <= f_inputA_sel_o;
        f_inputB_sel_o <= f_inputB_sel_o;
        f_inputC_sel_o <= f_inputC_sel_o;
        fp_op_o <= fp_op_o;
        fp_func_sel_o <= fp_func_sel_o;
        fp_unit_sel_o <= fp_unit_sel_o;
        fp64_ls_o <= fp64_ls_o;
        rd_fpr_we_o <= rd_fpr_we_o;
        rs3_addr2fwd_o <= rs3_addr2fwd_o;
`endif
    end
    else if (xcpt_valid)
    begin
        pc_o <= pc_i;
        fetch_valid_o <= 1;
        rs1_data2fwd_o <= 0;
        rs2_data2fwd_o <= 0;
        imm_o <= 0;
        inputA_sel_o <= 2;
        inputB_sel_o <= 0;
        operation_sel_o <= 0;
        signex_sel_o <= 0;
        dsize_sel_o <= 0;
        alu_muldiv_sel_o <= 0;
        shift_sel_o <= 0;
        is_branch_o <= 0;
        is_jal_o <= 0;
        is_jalr_o <= 0;
        rd_we_o <= 1;
        rd_input_sel_o <= 4;  // send Execute result into the RFU.
        we_o <= 0;
        re_o <= 0;
        dsize_sel_o <= 0;
        rd_addr_o <= 0;
        rs1_addr2fwd_o <= 0;
        rs2_addr2fwd_o <= 0;
        csr_we_o <= 0;
        csr_imm_o <= 0;
        branch_hit_o <= 0;
        branch_decision_o <= 0;
        is_fencei_o <= 0;
        amo_type_o <= 0;
        is_amo_o <= 0;

        sys_jump_o <= 0;
        sys_jump_csr_addr_o <= 0;
        xcpt_valid_o <= xcpt_valid;
        xcpt_cause_o <= xcpt_cause;
        xcpt_tval_o <= xcpt_tval;
        csr_data2fwd_o <= 0;
        csr_addr2fwd_o <= 0;

`ifdef ENABLE_FPU
        rs1_f_data2fwd_o <= 0;
        rs2_f_data2fwd_o <= 0;
        rs3_f_data2fwd_o <= 0;
        dec2fwd_rs1_fpr_o <= 0;
        dec2fwd_rs2_fpr_o <= 0;
        dec2fwd_rs3_fpr_o <= 0;        
        f_inputA_sel_o <= 0;
        f_inputB_sel_o <= 0;
        f_inputC_sel_o <= 0;
        fp_op_o <= 0;
        fp_func_sel_o <= 0;
        fp_unit_sel_o <= 0;
        fp64_ls_o <= 0;
        rd_fpr_we_o <= 0;
        rs3_addr2fwd_o <= 0;
`endif
    end
    else
    begin
        pc_o <= pc_i;
        fetch_valid_o <= fetch_valid_i;
        rs1_data2fwd_o <= rs1_data_i;
        rs2_data2fwd_o <= rs2_data_i;
        imm_o <= imm;
        inputA_sel_o <= inputA_sel;
        inputB_sel_o <= inputB_sel;
        operation_sel_o <= operation_sel;
        signex_sel_o <= signex_sel;
        alu_muldiv_sel_o <= alu_muldiv_sel;
        shift_sel_o <= shift_sel;
        is_branch_o <= rv32_branch;
        is_jal_o <= rv32_jal;
        is_jalr_o <= rv32_jalr;
        rd_we_o <= rd_we;
        rd_input_sel_o <= rd_input_sel;
        we_o <= we;
        re_o <= re;
        dsize_sel_o <= dsize_sel;
        rd_addr_o <= rd_addr;
        rs1_addr2fwd_o <= rs1_addr_o;
        rs2_addr2fwd_o <= rs2_addr_o;
        csr_we_o <= rv32_csr & !((rv32_csrrs | rv32_csrrc) & rv32_instr[19: 15] == 5'b00000);
        csr_imm_o <= csr_imm;
        branch_hit_o <= branch_hit_i;
        branch_decision_o <= branch_decision_i;
        is_fencei_o <= rv32_fencei;
        amo_type_o <= amo_type;
        is_amo_o <= rv32_amo;

        sys_jump_o <= rv32_mret | rv32_sret;
        sys_jump_csr_addr_o <= ({2{rv32_mret}} & 2'b11) | ({2{rv32_sret}} & 2'b01);
        xcpt_valid_o <= xcpt_valid_i;
        xcpt_cause_o <= xcpt_cause_i;
        xcpt_tval_o <= xcpt_tval_i;
        csr_data2fwd_o <= csr_data_i;
        csr_addr2fwd_o <= csr_addr_o;

`ifdef ENABLE_FPU
        rs1_f_data2fwd_o <= rs1_f_data_i;
        rs2_f_data2fwd_o <= rs2_f_data_i;
        rs3_f_data2fwd_o <= rs3_f_data_i;
        dec2fwd_rs1_fpr_o <= rs1_fpr;
        dec2fwd_rs2_fpr_o <= rs2_fpr;
        dec2fwd_rs3_fpr_o <= rs3_fpr;        
        f_inputA_sel_o <= f_inputA_sel;
        f_inputB_sel_o <= f_inputB_sel;
        f_inputC_sel_o <= f_inputC_sel;
        fp_op_o <= fp_op;
        fp_func_sel_o <= fp_func_sel;
        fp_unit_sel_o <= fp_unit_sel;
        fp64_ls_o <= fp64_ls;
        rd_fpr_we_o <= rd_fpr_we;
        rs3_addr2fwd_o <= rs3_addr_o;
`endif
    end
end

endmodule
