`timescale 1ns / 1ps
// =============================================================================
//  Program : execute.v
//  Author  : Jin-you Wu
//  Date    : Dec/19/2018
// -----------------------------------------------------------------------------
//  Description:
//  This is the Execution Unit of the Aquila core (A RISC-V core).
// -----------------------------------------------------------------------------
//  Revision information:
//
//  Nov/29/2019, by Chun-Jen Tsai:
//    Merges the pipeline register module 'execute_memory' into the 'execute'
//    module.
//
//  Aug/19/2025, by Sin-Ying Li:
//    Add RV32F/D execution via FPIP with FP operand selects, support FP64
//    load/store
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

module execute #( parameter XLEN = 32, parameter DLEN = 64 )
(
    //  Processor clock and reset signals.
    input                   clk_i,
    input                   rst_i,

    // Pipeline stall signal.
    input                   stall_i,

    // Pipeline flush signal.
    input                   flush_i,

    // From Decode.
    input  [XLEN-1 : 0]     imm_i,
    input  [ 1 : 0]         inputA_sel_i,
    input  [ 1 : 0]         inputB_sel_i,
    input  [ 2 : 0]         operation_sel_i,
    input                   alu_muldiv_sel_i,
    input                   shift_sel_i,
    input                   is_branch_i,
    input                   is_jal_i,
    input                   is_jalr_i,
    input                   branch_hit_i,
    input                   branch_decision_i,

    input  [ 2 : 0]         rd_input_sel_i,
    input  [ 4 : 0]         rd_addr_i,
    input                   rd_we_i,
    input                   signex_sel_i,

    input                   we_i,
    input                   re_i,
    input  [ 1 : 0]         dsize_sel_i,
    input                   is_fencei_i,
    input                   is_amo_i,
    input  [4 : 0]          amo_type_i,

    // From CSR.
    input  [ 4 : 0]         csr_imm_i,
    input                   csr_we_i,
    input  [11 : 0]         csr_we_addr_i,

    // From the Forwarding Unit.
    input  [XLEN-1 : 0]     rs1_data_i,
    input  [XLEN-1 : 0]     rs2_data_i,
    input  [XLEN-1 : 0]     csr_data_i,

    // To the Program Counter Unit.
    output [XLEN-1 : 0]     branch_restore_pc_o,    // to PC only
    output [XLEN-1 : 0]     branch_target_addr_o,   // to PC and BPU

    // To the Pipeline Control and the Branch Prediction units.
    output                  is_branch_o,
    output                  branch_taken_o,
    output                  branch_misprediction_o,

    // Pipeline stall signal generator, activated when executing
    //    multicycle mul, div and rem instructions.
    output                  stall_from_exe_o,

    // Signals to D-memory.
    output reg              we_o,
    output reg              re_o,
    output reg              is_fencei_o,
    output reg              is_amo_o,
    output reg [ 4 : 0]     amo_type_o,

    // Signals to Memory Alignment unit.
    output reg [XLEN-1 : 0] rs2_data_o,
    output reg [XLEN-1 : 0] addr_o,
    output reg [ 1 : 0]     dsize_sel_o,
    
    // Signals to Memory Writeback Pipeline.
    output reg [ 2 : 0]     rd_input_sel_o,
    output reg              rd_we_o,
    output reg [ 4 : 0]     rd_addr_o,
    output reg [XLEN-1 : 0] p_data_o,

    output reg              csr_we_o,
    output reg [11 : 0]     csr_we_addr_o,
    output reg [XLEN-1 : 0] csr_we_data_o,

    // to Memory_Write_Back_Pipeline
    output reg              signex_sel_o,

    // PC of the current instruction.
    input  [XLEN-1 : 0]     pc_i,
    output reg [XLEN-1 : 0] pc_o,

    // System Jump operation
    input                   sys_jump_i,
    input  [ 1 : 0]         sys_jump_csr_addr_i,
    output reg              sys_jump_o,
    output reg [ 1 : 0]     sys_jump_csr_addr_o,

    // Has instruction fetch being successiful?
    input                   fetch_valid_i,
    output reg              fetch_valid_o,

    // Exception info passed from Decode to Memory.
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
    input                   stall_fp64_load_use_i,

    // 2) Signals from the Forwarding Unit.
    input  [DLEN-1 : 0]     rs1_f_data_i,
    input  [DLEN-1 : 0]     rs2_f_data_i,
    input  [DLEN-1 : 0]     rs3_f_data_i,

    // 3) Signals from Decode.
    input  [ 1 : 0]         f_inputA_sel_i,
    input  [ 1 : 0]         f_inputB_sel_i,
    input  [ 1 : 0]         f_inputC_sel_i,
    input                   fp_op_i,
    input  [ 6 : 0]         fp_func_sel_i,
    input  [ 4 : 0]         fp_unit_sel_i,
    input                   rd_fpr_we_i,
    input                   fp32_load_i,
    input                   fp64_load_i,
    input                   fp32_store_i,
    input                   fp64_ls_i,

    // 4) Signals to D-Memory.
    output reg              fp32_load_o,
    output reg              fp64_load_o,

    // 5) Signals to Memory, Writeback, and Forwarding.
    output reg              rd_fpr_we_o,
    output reg              fld_upperhalf_o,
    output reg              fld_lowerhalf_o,
    output reg [DLEN-1 : 0] p_f_data_o
`endif // ENABLE_FPU
);

// ===============================================================================
//  ALU input/output selection
//
reg  [XLEN-1 : 0] inputA, inputB;
wire [XLEN-1 : 0] alu_result;
wire              alu_stall;
wire [XLEN-1 : 0] muldiv_result;
wire              compare_result, stall_from_muldiv, muldiv_ready;

wire [XLEN-1 : 0] exe_result;
wire [XLEN-1 : 0] mem_addr;

always @(*)
begin
    case (inputA_sel_i)
        3'd0: inputA = 0;
        3'd1: inputA = pc_i;
        3'd2: inputA = rs1_data_i;
        default: inputA = 0;
    endcase
end

always @(*)
begin
    case (inputB_sel_i)
        3'd0: inputB = imm_i;
        3'd1: inputB = rs2_data_i;
        3'd2: inputB = ~rs2_data_i + 1'b1;
        default: inputB = 0;
    endcase
end

// branch target address generate by alu adder
wire [2: 0] alu_operation = (is_branch_i | is_jal_i | is_jalr_i)? 3'b000 : operation_sel_i;
wire [2: 0] muldiv_operation = operation_sel_i;
wire muldiv_req = alu_muldiv_sel_i & !muldiv_ready;
wire [2: 0] branch_operation = operation_sel_i;

// ===============================================================================
//  ALU Regular operation
//
alu ALU(
    .a_i(inputA),
    .b_i(inputB),
    .operation_sel_i(alu_operation),
    .shift_sel_i(shift_sel_i),
    .alu_result_o(alu_result)
);

// ===============================================================================
//   MulDiv
//
muldiv MulDiv(
    .clk_i(clk_i),
    .rst_i(rst_i),
    .stall_i(stall_i || stall_fp64_load_use_i),
    .a_i(inputA),
    .b_i(inputB),
    .req_i(muldiv_req),
    .operation_sel_i(muldiv_operation),
    .muldiv_result_o(muldiv_result),
    .ready_o(muldiv_ready)
);

// ==============================================================================
//  BCU
//
bcu BCU(
    .a_i(rs1_data_i),
    .b_i(rs2_data_i),
    .operation_sel_i(branch_operation),
    .compare_result_o(compare_result)
);

// ===============================================================================
//  AGU & Output signals
//
assign mem_addr = rs1_data_i + imm_i;     // The target addr of memory load/store
assign branch_target_addr_o = alu_result; // The target addr of BRANCH, JAL, JALR
assign branch_restore_pc_o = pc_i + 'd4;  // The next PC of instruction, and the
                                          // restore PC if mispredicted branch taken.

assign is_branch_o = is_branch_i | is_jal_i;
assign branch_taken_o = (is_branch_i & compare_result) | is_jal_i | is_jalr_i;
assign branch_misprediction_o = branch_hit_i & (branch_decision_i ^ branch_taken_o);

// ===============================================================================
//  CSR
//
wire [XLEN-1 : 0] csr_inputA = csr_data_i;
wire [XLEN-1 : 0] csr_inputB = operation_sel_i[2] ? {27'b0, csr_imm_i} : rs1_data_i;
reg  [XLEN-1 : 0] csr_update_data;

always @(*)
begin
    case (operation_sel_i[1: 0])
        `CSR_RW:
            csr_update_data = csr_inputB;
        `CSR_RS:
            csr_update_data = csr_inputA | csr_inputB;
        `CSR_RC:
            csr_update_data = csr_inputA & ~csr_inputB;
        default:
            csr_update_data = csr_inputA;
    endcase
end

`ifndef ENABLE_FPU
wire [DLEN-1 : 0] f_result = {DLEN-1{1'b0}};
`else
// ===============================================================================
//  FPU input/output selection
//
reg  [DLEN-1 : 0] f_inputA, f_inputB, f_inputC;   // f_inputA/B/C: operands fed into the FPIP units.
wire              fpu_stall;
wire [DLEN-1 : 0] f_result;

always @(*)
begin
    case (f_inputA_sel_i)
        2'd0: f_inputA = rs1_f_data_i;
        2'd1: f_inputA = {~rs1_f_data_i[31], rs1_f_data_i[30:0]};
        2'd2: f_inputA = {~rs1_f_data_i[63], rs1_f_data_i[62:0]};
        default: f_inputA = 0;
    endcase
end

always @(*)
begin
    case (f_inputB_sel_i)
        2'd0: f_inputB = rs2_f_data_i;
        2'd1: f_inputB = {~rs2_f_data_i[31], rs2_f_data_i[30:0]};
        2'd2: f_inputB = {~rs2_f_data_i[63], rs2_f_data_i[62:0]};
        default: f_inputB = 0;
    endcase
end

always @(*)
begin
    case (f_inputC_sel_i)
        2'd0: f_inputC = rs3_f_data_i;
        2'd1: f_inputC = {~rs3_f_data_i[31], rs3_f_data_i[30:0]};
        2'd2: f_inputC = {~rs3_f_data_i[63], rs3_f_data_i[62:0]};
        default: f_inputC = 0;
    endcase
end
`endif

// ===============================================================================
//  Update PC & FPU 64-bit load-store flag.
//
reg  [XLEN-1 : 0]   pc_r;
reg fp64_ls_r;

`ifndef ENABLE_FPU
wire fp64_ls_i = 0;
`endif

always @(posedge clk_i) begin
    if(rst_i || (flush_i && !stall_i && !stall_fp64_load_use_i)) 
    begin
        pc_r <= 0;
        fp64_ls_r <= 0;     
    end
    else if(stall_i || stall_from_exe_o || stall_fp64_load_use_i) 
    begin
        pc_r <= pc_r;
        fp64_ls_r <= fp64_ls_r;
    end
    else 
    begin
        pc_r <= pc_i;
        fp64_ls_r <= fp64_ls_i;   
    end
end

// ===============================================================================
// Execute stage stall signal. If FPU is not enabled, fpu_stall is always 0.
//
assign alu_stall = alu_muldiv_sel_i & !muldiv_ready;
assign stall_from_exe_o = alu_stall | fpu_stall;

// ===============================================================================
//  Output registers to the Memory stage
//
always @(posedge clk_i)
begin
    if (rst_i || (flush_i && !stall_i && !stall_fp64_load_use_i)) // stall has higher priority than flush.
    begin
        rd_input_sel_o <= 0;
        rd_addr_o <= 0;
        rd_we_o <= 0;
        signex_sel_o <= 0;

        we_o <= 0;
        re_o <= 0;
        rs2_data_o <= 0;
        addr_o <= 0;
        dsize_sel_o <= 0;
        is_fencei_o <= 0;
        is_amo_o <= 0;
        amo_type_o <= 0;

        sys_jump_o <= 0;
        sys_jump_csr_addr_o <= 0;
        xcpt_valid_o <= 0;
        xcpt_cause_o <= 0;
        xcpt_tval_o <= 0;
        pc_o <= 0;
        fetch_valid_o <= 0;
        csr_we_o <= 0;
        csr_we_addr_o <= 0;
        csr_we_data_o <= 0;
`ifdef ENABLE_FPU
        rd_fpr_we_o <= 0;
        fld_upperhalf_o <= 0;
        fld_lowerhalf_o <= 0;        
        fp32_load_o <= 0;
        fp64_load_o <= 0;
`endif
    end
    else if (stall_i || stall_from_exe_o)
    begin
        rd_input_sel_o <= rd_input_sel_o;
        rd_addr_o <= rd_addr_o;
        rd_we_o <= rd_we_o;
        signex_sel_o <= signex_sel_o;

        we_o <= we_o;
        re_o <= re_o;
        rs2_data_o <= rs2_data_o;
        addr_o <= addr_o;
        dsize_sel_o <= dsize_sel_o;
        is_fencei_o <= is_fencei_o;
        is_amo_o <= is_amo_o;
        amo_type_o <= amo_type_o;

        sys_jump_o <= sys_jump_o;
        sys_jump_csr_addr_o <= sys_jump_csr_addr_o;
        xcpt_valid_o <= xcpt_valid_o;
        xcpt_cause_o <= xcpt_cause_o;
        xcpt_tval_o <= xcpt_tval_o;
        pc_o <= pc_o;
        fetch_valid_o <= fetch_valid_o;
        csr_we_o <= csr_we_o;
        csr_we_addr_o <= csr_we_addr_o;
        csr_we_data_o <= csr_we_data_o;
`ifdef ENABLE_FPU
        rd_fpr_we_o <= rd_fpr_we_o;
        fld_upperhalf_o <= fld_upperhalf_o;
        fld_lowerhalf_o <= fld_lowerhalf_o;        
        fp32_load_o <= fp32_load_o;
        fp64_load_o <= fp64_load_o;
`endif
    end
`ifdef ENABLE_FPU
    else if (fp64_ls_r && !fp64_ls_i && (pc_i == pc_r))
    begin
        rd_input_sel_o <= rd_input_sel_i;
        rd_addr_o <= rd_addr_i;
        fld_upperhalf_o <= 1;
        fld_lowerhalf_o <= 0;        
        rd_we_o <= rd_we_i;
        rd_fpr_we_o <= rd_fpr_we_i;
        signex_sel_o <= signex_sel_i;

        we_o <= we_i ;
        re_o <= re_i;
        fp32_load_o <= fp32_load_i;
        fp64_load_o <= fp64_load_i;
        rs2_data_o <= rs2_f_data_i[63:32];
        addr_o  <= mem_addr + 32'd4;
        dsize_sel_o <= dsize_sel_i;
        is_fencei_o <= is_fencei_i;
        is_amo_o <= is_amo_i;
        amo_type_o <= amo_type_i;

        sys_jump_o <= sys_jump_i;
        sys_jump_csr_addr_o <= sys_jump_csr_addr_i;
        xcpt_valid_o <= xcpt_valid_i;
        xcpt_cause_o <= xcpt_cause_i;
        xcpt_tval_o <= xcpt_tval_i;
        pc_o <= pc_i;
        fetch_valid_o <= fetch_valid_i;
        csr_we_o <= csr_we_i;
        csr_we_addr_o <= csr_we_addr_i;
        csr_we_data_o <= csr_update_data;
    end  
    else if (stall_fp64_load_use_i)
    begin
        rd_input_sel_o <= rd_input_sel_o;
        rd_addr_o <= rd_addr_o;
        fld_upperhalf_o <= fld_upperhalf_o;
        fld_lowerhalf_o <= fld_lowerhalf_o;        
        rd_we_o <= rd_we_o;
        rd_fpr_we_o <= rd_fpr_we_o;
        signex_sel_o <= signex_sel_o;

        we_o <= we_o;
        re_o <= re_o;
        fp32_load_o <= fp32_load_o;
        fp64_load_o <= fp64_load_o;
        rs2_data_o <= rs2_data_o;
        addr_o <= addr_o;
        dsize_sel_o <= dsize_sel_o;
        is_fencei_o <= is_fencei_o;
        is_amo_o <= is_amo_o;
        amo_type_o <= amo_type_o;

        sys_jump_o <= sys_jump_o;
        sys_jump_csr_addr_o <= sys_jump_csr_addr_o;
        xcpt_valid_o <= xcpt_valid_o;
        xcpt_cause_o <= xcpt_cause_o;
        xcpt_tval_o <= xcpt_tval_o;
        pc_o <= pc_o;
        fetch_valid_o <= fetch_valid_o;
        csr_we_o <= csr_we_o;
        csr_we_addr_o <= csr_we_addr_o;
        csr_we_data_o <= csr_we_data_o;
    end
`endif // ENABLE_FPU

    else
    begin
        rd_input_sel_o <= rd_input_sel_i;
        rd_addr_o <= rd_addr_i;
        rd_we_o <= rd_we_i;
        signex_sel_o <= signex_sel_i;

        we_o <= we_i ;
        re_o <= re_i;
        addr_o  <= mem_addr;
        dsize_sel_o <= dsize_sel_i;
        is_fencei_o <= is_fencei_i;
        is_amo_o <= is_amo_i;
        amo_type_o <= amo_type_i;

        sys_jump_o <= sys_jump_i;
        sys_jump_csr_addr_o <= sys_jump_csr_addr_i;
        xcpt_valid_o <= xcpt_valid_i;
        xcpt_cause_o <= xcpt_cause_i;
        xcpt_tval_o <= xcpt_tval_i;
        pc_o <= pc_i;
        fetch_valid_o <= fetch_valid_i;
        csr_we_o <= csr_we_i;
        csr_we_addr_o <= csr_we_addr_i;
        csr_we_data_o <= csr_update_data;
`ifndef ENABLE_FPU
        rs2_data_o <= rs2_data_i;
`else
        rd_fpr_we_o <= rd_fpr_we_i;
        fld_upperhalf_o <= 0;
        if (fp64_ls_i)
            fld_lowerhalf_o <= 1;   
        else
            fld_lowerhalf_o <= 0;  
        fp32_load_o <= fp32_load_i;
        fp64_load_o <= fp64_load_i;
        if (fp64_ls_i | fp32_store_i) 
            rs2_data_o <= rs2_f_data_i[31:0];   
        else 
            rs2_data_o <= rs2_data_i;
`endif
    end
end

always @(posedge clk_i)
begin
    if (rst_i || (flush_i && !stall_i)) // stall has higher priority than flush.
    begin
        p_data_o <= 0;  // data from processor
    end
    else if (stall_i || stall_from_exe_o)
    begin
        p_data_o <= p_data_o;
    end
    else
    begin
        case (rd_input_sel_i)
            3'b011: p_data_o <= branch_restore_pc_o;
            3'b100: p_data_o <= exe_result;
            3'b101: p_data_o <= csr_data_i;
            default: p_data_o <= 0;
        endcase
    end
end

`ifdef ENABLE_FPU // If FPU is disabled. GCC compiled code must link soft-fp library.
// ===============================================================================
//  FPU calculated result output
//
always @(posedge clk_i)
begin
    if (rst_i || (flush_i && !stall_i)) // stall has higher priority than flush.
    begin
        p_f_data_o <= 0; // double data from processor
    end
    else if (stall_i || stall_from_exe_o)
    begin
        p_f_data_o <= p_f_data_o;
    end
    else
    begin
        p_f_data_o <= f_result;
    end
end

// ===============================================================================
//  FPIP valid signal
//
wire    AddSub_s_input_valid, Mul_s_input_valid, Div_s_input_valid,
        Sqrt_s_input_valid, CmpLT_s_input_valid, MAddSub_s_input_valid,
        CVT_W_s_input_valid, CVT_s_W_input_valid, CVT_s_WU_input_valid,
        EQ_s_input_valid, LE_s_input_valid;

wire    AddSub_d_input_valid, Mul_d_input_valid, Div_d_input_valid,
        Sqrt_d_input_valid, CmpLT_d_input_valid, MAddSub_d_input_valid,
        CVT_W_d_input_valid, CVT_d_W_input_valid, CVT_d_WU_input_valid,
        EQ_d_input_valid, LE_d_input_valid, CVT_d_s_input_valid,
        CVT_s_d_input_valid;

// FPIP_input_valid: exactly one FP subunit is being issued in this cycle.
// FPIP_output_valid: a previously issued FP subunit returns a result.
wire FPIP_input_valid;
wire FPIP_output_valid;
reg FPIP_input_valid_r;

//=============================================================================
// FPIP dispatch FSM (ipS)
//   ip_IDLE : default, accept a new FP request when FPIP_input_valid_r = 1
//   ip_BUSY : wait until any FPIP asserts its valid output (FPIP_output_valid)
//   ip_WAIT : single cycle delay, prevents skipping the next RV32F/D operation
//=============================================================================

localparam ip_IDLE = 0, ip_BUSY = 1, ip_WAIT = 2;
reg [1:0] ipS, ipS_nxt;

always @(posedge clk_i)
begin
    if (rst_i)
        ipS <= ip_IDLE;
    else
        ipS <= ipS_nxt;
end

always @(*)
begin
    case (ipS)
        ip_IDLE:
            if (FPIP_input_valid_r)
                ipS_nxt = ip_BUSY;
            else
                ipS_nxt = ip_IDLE;
        ip_BUSY:
            if (FPIP_output_valid)
                ipS_nxt = ip_WAIT;
            else
                ipS_nxt = ip_BUSY;
        ip_WAIT:
            ipS_nxt = ip_IDLE;
        default:
            ipS_nxt = ip_IDLE;
    endcase
end

// F extension FPIP signal
wire                f_AddSub_s_valid, f_Mul_s_valid, f_Div_s_valid, f_Sqrt_s_valid,
                    f_CmpLT_s_valid, f_MAddSub_s_valid, f_CVT_W_s_valid, f_CVT_s_W_valid,
                    f_CVT_s_WU_valid, f_EQ_s_valid, f_LE_s_valid;
wire [XLEN-1 : 0]   f_AddSub_s_result;
wire [XLEN-1 : 0]   f_Mul_s_result;
wire [XLEN-1 : 0]   f_Div_s_result;
wire [XLEN-1 : 0]   f_Sqrt_s_result;
wire [7 : 0]        f_CmpLT_s_result;
wire [XLEN-1 : 0]   f_CmpLT_s_answer;
wire [XLEN-1 : 0]   f_MAddSub_s_result;
wire [XLEN-1 : 0]   f_SGNJ_s_result;
wire [2 : 0]        f_SGNJ_s_op;
wire [XLEN-1 : 0]   f_CVT_W_s_result;
wire [XLEN-1 : 0]   f_CVT_s_W_result;
wire [XLEN-1 : 0]   f_CVT_WU_s_result;
wire [XLEN-1 : 0]   f_CVT_s_WU_result;
wire [7 : 0]        f_EQ_s_result;
wire [XLEN-1 : 0]   f_EQ_s_answer;
wire [7 : 0]        f_LT_s_result;
wire [XLEN-1 : 0]   f_LT_s_answer;
wire [7 : 0]        f_LE_s_result;
wire [XLEN-1 : 0]   f_LE_s_answer;
wire [XLEN-1 : 0]   f_CLASS_s_answer;

// D extension FPIP signal
wire                f_AddSub_d_valid, f_Mul_d_valid, f_Div_d_valid, f_Sqrt_d_valid,
                    f_CmpLT_d_valid, f_MAddSub_d_valid, f_CVT_W_d_valid, f_CVT_d_s_valid,
                    f_CVT_s_d_valid, f_CVT_d_W_valid, f_CVT_d_WU_valid, f_EQ_d_valid,
                    f_LE_d_valid;
wire [DLEN-1 : 0]   f_AddSub_d_result;
wire [DLEN-1 : 0]   f_Mul_d_result;
wire [DLEN-1 : 0]   f_Div_d_result;
wire [DLEN-1 : 0]   f_Sqrt_d_result;
wire [7 : 0]        f_CmpLT_d_result;
wire [DLEN-1 : 0]   f_CmpLT_d_answer;
wire [DLEN-1 : 0]   f_MAddSub_d_result;
wire [DLEN-1 : 0]   f_SGNJ_d_result;
wire [2 : 0]        f_SGNJ_d_op;
wire [XLEN-1 : 0]   f_CVT_W_d_result;
wire [DLEN-1 : 0]   f_CVT_d_W_result;
wire [XLEN-1 : 0]   f_CVT_WU_d_result;
wire [DLEN-1 : 0]   f_CVT_d_WU_result;
wire [DLEN-1 : 0]   f_CVT_d_s_result;
wire [XLEN-1 : 0]   f_CVT_s_d_result;
wire [7 : 0]        f_EQ_d_result;
wire [XLEN-1 : 0]   f_EQ_d_answer;
wire [7 : 0]        f_LT_d_result;
wire [XLEN-1 : 0]   f_LT_d_answer;
wire [7 : 0]        f_LE_d_result;
wire [XLEN-1 : 0]   f_LE_d_answer;
wire [XLEN-1 : 0]   f_CLASS_d_answer;

assign FPIP_input_valid = AddSub_s_input_valid | Mul_s_input_valid | Div_s_input_valid |
                          Sqrt_s_input_valid | CmpLT_s_input_valid | MAddSub_s_input_valid |
                          CVT_W_s_input_valid | CVT_s_W_input_valid | CVT_s_WU_input_valid |
                          EQ_s_input_valid | LE_s_input_valid | AddSub_d_input_valid |
                          Mul_d_input_valid | Div_d_input_valid | Sqrt_d_input_valid |
                          CmpLT_d_input_valid | MAddSub_d_input_valid | CVT_W_d_input_valid |
                          CVT_d_W_input_valid | CVT_d_WU_input_valid | EQ_d_input_valid |
                          LE_d_input_valid | CVT_d_s_input_valid | CVT_s_d_input_valid;
assign FPIP_output_valid = f_AddSub_s_valid | f_Mul_s_valid | f_Div_s_valid | f_Sqrt_s_valid |
                           f_CmpLT_s_valid | f_MAddSub_s_valid | f_CVT_W_s_valid |
                           f_CVT_s_W_valid | f_CVT_s_WU_valid | f_EQ_s_valid | f_LE_s_valid |
                           f_AddSub_d_valid | f_Mul_d_valid | f_Div_d_valid | f_Sqrt_d_valid |
                           f_CmpLT_d_valid | f_MAddSub_d_valid | f_CVT_W_d_valid |
                           f_CVT_d_s_valid | f_CVT_s_d_valid | f_CVT_d_W_valid |
                           f_CVT_d_WU_valid | f_EQ_d_valid | f_LE_d_valid;

always @(posedge clk_i) FPIP_input_valid_r <= FPIP_input_valid;

assign AddSub_s_input_valid = fp_op_i & fp_unit_sel_i == 1 & ~stall_fp64_load_use_i & (ipS_nxt == ip_IDLE);
assign Mul_s_input_valid = fp_op_i & fp_unit_sel_i == 2 & ~stall_fp64_load_use_i & (ipS_nxt == ip_IDLE);
assign Div_s_input_valid = fp_op_i & fp_unit_sel_i == 3 & ~stall_fp64_load_use_i & (ipS_nxt == ip_IDLE);
assign Sqrt_s_input_valid = fp_op_i & fp_unit_sel_i == 4 & ~stall_fp64_load_use_i & (ipS_nxt == ip_IDLE);
assign CmpLT_s_input_valid = fp_op_i & fp_unit_sel_i == 5 & ~stall_fp64_load_use_i & (ipS_nxt == ip_IDLE);
assign MAddSub_s_input_valid = fp_op_i & fp_unit_sel_i == 6 & ~stall_fp64_load_use_i & (ipS_nxt == ip_IDLE);
assign CVT_W_s_input_valid = fp_op_i & fp_unit_sel_i == 7 & ~stall_fp64_load_use_i & (ipS_nxt == ip_IDLE);
assign EQ_s_input_valid = fp_op_i & fp_unit_sel_i == 8 & ~stall_fp64_load_use_i & (ipS_nxt == ip_IDLE);
assign LE_s_input_valid = fp_op_i & fp_unit_sel_i == 9 & ~stall_fp64_load_use_i & (ipS_nxt == ip_IDLE);
assign CVT_s_W_input_valid = fp_op_i & fp_unit_sel_i == 10 & ~stall_fp64_load_use_i & (ipS_nxt == ip_IDLE);
assign CVT_s_WU_input_valid = fp_op_i & fp_unit_sel_i == 11 & ~stall_fp64_load_use_i & (ipS_nxt == ip_IDLE);

assign AddSub_d_input_valid = fp_op_i & fp_unit_sel_i == 12 & !stall_fp64_load_use_i & (ipS_nxt == ip_IDLE);
assign Mul_d_input_valid = fp_op_i & fp_unit_sel_i == 13 & ~stall_fp64_load_use_i & (ipS_nxt == ip_IDLE);
assign Div_d_input_valid = fp_op_i & fp_unit_sel_i == 14 & ~stall_fp64_load_use_i & (ipS_nxt == ip_IDLE);
assign Sqrt_d_input_valid = fp_op_i & fp_unit_sel_i == 15 & ~stall_fp64_load_use_i & (ipS_nxt == ip_IDLE);
assign CmpLT_d_input_valid = fp_op_i & fp_unit_sel_i == 16 & ~stall_fp64_load_use_i & (ipS_nxt == ip_IDLE);
assign MAddSub_d_input_valid = fp_op_i & fp_unit_sel_i == 17 & ~stall_fp64_load_use_i & (ipS_nxt == ip_IDLE);
assign CVT_W_d_input_valid = fp_op_i & fp_unit_sel_i == 18 & ~stall_fp64_load_use_i & (ipS_nxt == ip_IDLE);
assign EQ_d_input_valid = fp_op_i & fp_unit_sel_i == 19 & ~stall_fp64_load_use_i & (ipS_nxt == ip_IDLE);
assign LE_d_input_valid = fp_op_i & fp_unit_sel_i == 20 & ~stall_fp64_load_use_i & (ipS_nxt == ip_IDLE);
assign CVT_d_W_input_valid = fp_op_i & fp_unit_sel_i == 21 & ~stall_fp64_load_use_i & (ipS_nxt == ip_IDLE);
assign CVT_d_WU_input_valid = fp_op_i & fp_unit_sel_i == 22 & ~stall_fp64_load_use_i & (ipS_nxt == ip_IDLE);
assign CVT_d_s_input_valid = fp_op_i & fp_unit_sel_i == 23 & ~stall_fp64_load_use_i & (ipS_nxt == ip_IDLE);
assign CVT_s_d_input_valid = fp_op_i & fp_unit_sel_i == 24 & ~stall_fp64_load_use_i & (ipS_nxt == ip_IDLE);

assign f_CmpLT_s_answer = (fp_func_sel_i == 6) ? (f_CmpLT_s_result ? rs1_f_data_i[31:0] : rs2_f_data_i[31:0])
                    : (f_CmpLT_s_result ? rs2_f_data_i[31:0] : rs1_f_data_i[31:0]);
assign f_SGNJ_s_op = (fp_func_sel_i == 12) ? 1 : (fp_func_sel_i == 13) ? 2 : (fp_func_sel_i == 14) ? 3 : 0;
assign f_EQ_s_answer = {24'd0, f_EQ_s_result};
assign f_LE_s_answer = {24'd0, f_LE_s_result};
assign f_LT_s_answer = {24'd0, f_CmpLT_s_result};
assign f_CLASS_s_answer = (rs1_f_data_i[31:0] == {1'b1, 8'd255, 23'd0}) ? 32'd0
                        : (rs1_f_data_i[31:0] == {1'b1, 8'd0, 23'd0}) ? 32'd3
                        : (rs1_f_data_i[31:0] == {1'b0, 8'd0, 23'd0}) ? 32'd4
                        : (rs1_f_data_i[31:0] == {1'b0, 8'd255, 23'd0}) ? 32'd7
                        : (rs1_f_data_i[31 : 23] == {1'b0, 8'd0}) ? 32'd5
                        : (rs1_f_data_i[31 : 23] == {1'b1, 8'd0}) ? 32'd2
                        : (rs1_f_data_i[30 : 22] == {8'd255, 1'b0}) ? 32'd8
                        : (rs1_f_data_i[30 : 22] == {8'd255, 1'b1}) ? 32'd9
                        : (rs1_f_data_i[31] == 1'b1) ? 32'd1 : 32'd6;

assign f_CmpLT_d_answer = (fp_func_sel_i == 30) ? (f_CmpLT_d_result ? rs1_f_data_i : rs2_f_data_i)
                    : (f_CmpLT_d_result ? rs2_f_data_i : rs1_f_data_i);
assign f_SGNJ_d_op = (fp_func_sel_i == 36) ? 1 : (fp_func_sel_i == 37) ? 2 : (fp_func_sel_i == 38) ? 3 : 0;
assign f_EQ_d_answer = {24'd0, f_EQ_d_result};
assign f_LE_d_answer = {24'd0, f_LE_d_result};
assign f_LT_d_answer = {24'd0, f_CmpLT_d_result};
assign f_CLASS_d_answer = (rs1_f_data_i == {1'b1, 11'd2023, 52'd0}) ? 32'd0
                        : (rs1_f_data_i == {1'b1, 11'd0, 52'd0}) ? 32'd3
                        : (rs1_f_data_i == {1'b0, 11'd0, 52'd0}) ? 32'd4
                        : (rs1_f_data_i == {1'b0, 11'd2023, 52'd0}) ? 32'd7
                        : (rs1_f_data_i[63 : 52] == {1'b0, 11'd0}) ? 32'd5
                        : (rs1_f_data_i[63 : 52] == {1'b1, 11'd0}) ? 32'd2
                        : (rs1_f_data_i[62 : 51] == {11'd2023, 1'b0}) ? 32'd8
                        : (rs1_f_data_i[62 : 51] == {11'd2023, 1'b1}) ? 32'd9
                        : (rs1_f_data_i[63] == 1'b1) ? 32'd1 : 32'd6;
assign f_CVT_WU_s_result = (f_CVT_W_s_result[31] == 0) ? f_CVT_W_s_result : 32'd0;
assign f_CVT_WU_d_result = (f_CVT_W_d_result[31] == 0) ? f_CVT_W_d_result : 32'd0;

//=============================================================================
// FPIP 
//

FP_Add_Sub_S FP_Add_Sub_S(
    .aclk(clk_i),

    .s_axis_a_tvalid(AddSub_s_input_valid),
    .s_axis_a_tdata(f_inputA[31:0]),

    .s_axis_b_tvalid(AddSub_s_input_valid),
    .s_axis_b_tdata(f_inputB[31:0]),

    .m_axis_result_tdata(f_AddSub_s_result),
    .m_axis_result_tvalid(f_AddSub_s_valid)
);

FP_Mul_S FP_Mul_S(
    .aclk(clk_i),

    .s_axis_a_tvalid(Mul_s_input_valid),
    .s_axis_a_tdata(f_inputA[31:0]),

    .s_axis_b_tvalid(Mul_s_input_valid),
    .s_axis_b_tdata(f_inputB[31:0]),
    
    .m_axis_result_tdata(f_Mul_s_result),
    .m_axis_result_tvalid(f_Mul_s_valid)
);

FP_Div_S FP_Div_S(
    .aclk(clk_i),

    .s_axis_a_tvalid(Div_s_input_valid),
    .s_axis_a_tdata(f_inputA[31:0]),

    .s_axis_b_tvalid(Div_s_input_valid),
    .s_axis_b_tdata(f_inputB[31:0]),
    
    .m_axis_result_tdata(f_Div_s_result),
    .m_axis_result_tvalid(f_Div_s_valid)
);

FP_Sqrt_S FP_Sqrt_S(
    .aclk(clk_i),

    .s_axis_a_tvalid(Sqrt_s_input_valid),
    .s_axis_a_tdata(f_inputA[31:0]),

    .m_axis_result_tdata(f_Sqrt_s_result),
    .m_axis_result_tvalid(f_Sqrt_s_valid)
);

FP_CmpLT_S FP_CmpLT_S(
    .aclk(clk_i),

    .s_axis_a_tvalid(CmpLT_s_input_valid),
    .s_axis_a_tdata(f_inputA[31:0]),

    .s_axis_b_tvalid(CmpLT_s_input_valid),
    .s_axis_b_tdata(f_inputB[31:0]),
    
    .m_axis_result_tdata(f_CmpLT_s_result),
    .m_axis_result_tvalid(f_CmpLT_s_valid)
);

FP_MAddSub_S FP_MAddSub_S(
    .aclk(clk_i),

    .s_axis_a_tvalid(MAddSub_s_input_valid),
    .s_axis_a_tdata(f_inputA[31:0]),

    .s_axis_b_tvalid(MAddSub_s_input_valid),
    .s_axis_b_tdata(f_inputB[31:0]),
    
    .s_axis_c_tvalid(MAddSub_s_input_valid),
    .s_axis_c_tdata(f_inputC[31:0]),
    
    .m_axis_result_tdata(f_MAddSub_s_result),
    .m_axis_result_tvalid(f_MAddSub_s_valid)
);

FP_CVT_W_S FP_CVT_W_S(
    .aclk(clk_i),

    .s_axis_a_tvalid(CVT_W_s_input_valid),
    .s_axis_a_tdata(f_inputA[31:0]),

    .m_axis_result_tdata(f_CVT_W_s_result),
    .m_axis_result_tvalid(f_CVT_W_s_valid)
);

FP_EQ_S FP_EQ_S(
    .aclk(clk_i),

    .s_axis_a_tvalid(EQ_s_input_valid),
    .s_axis_a_tdata(f_inputA[31:0]),

    .s_axis_b_tvalid(EQ_s_input_valid),
    .s_axis_b_tdata(f_inputB[31:0]),

    .m_axis_result_tdata(f_EQ_s_result),
    .m_axis_result_tvalid(f_EQ_s_valid)
);

FP_CVT_S_W FP_CVT_S_W(
    .aclk(clk_i),

    .s_axis_a_tvalid(CVT_s_W_input_valid),
    .s_axis_a_tdata(inputA),

    .m_axis_result_tdata(f_CVT_s_W_result),
    .m_axis_result_tvalid(f_CVT_s_W_valid)
);

FP_CVT_S_WU FP_CVT_S_WU(
    .aclk(clk_i),

    .s_axis_a_tvalid(CVT_s_WU_input_valid),
    .s_axis_a_tdata(inputA),

    .m_axis_result_tdata(f_CVT_s_WU_result),
    .m_axis_result_tvalid(f_CVT_s_WU_valid)
);

FP_LE_S FP_LE_S(
    .aclk(clk_i),

    .s_axis_a_tvalid(LE_s_input_valid),
    .s_axis_a_tdata(f_inputA[31:0]),

    .s_axis_b_tvalid(LE_s_input_valid),
    .s_axis_b_tdata(f_inputB[31:0]),

    .m_axis_result_tdata(f_LE_s_result),
    .m_axis_result_tvalid(f_LE_s_valid)
);

FP_Add_Sub_D FP_Add_Sub_D(
    .aclk(clk_i),

    .s_axis_a_tvalid(AddSub_d_input_valid),
    .s_axis_a_tdata(f_inputA),

    .s_axis_b_tvalid(AddSub_d_input_valid),
    .s_axis_b_tdata(f_inputB),

    .m_axis_result_tdata(f_AddSub_d_result),
    .m_axis_result_tvalid(f_AddSub_d_valid)
);

FP_Mul_D FP_Mul_D(
    .aclk(clk_i),

    .s_axis_a_tvalid(Mul_d_input_valid),
    .s_axis_a_tdata(f_inputA),

    .s_axis_b_tvalid(Mul_d_input_valid),
    .s_axis_b_tdata(f_inputB),
    
    .m_axis_result_tdata(f_Mul_d_result),
    .m_axis_result_tvalid(f_Mul_d_valid)
);

FP_Div_D FP_Div_D(
    .aclk(clk_i),

    .s_axis_a_tvalid(Div_d_input_valid),
    .s_axis_a_tdata(f_inputA),

    .s_axis_b_tvalid(Div_d_input_valid),
    .s_axis_b_tdata(f_inputB),
    
    .m_axis_result_tdata(f_Div_d_result),
    .m_axis_result_tvalid(f_Div_d_valid)
);

FP_Sqrt_D FP_Sqrt_D(
    .aclk(clk_i),

    .s_axis_a_tvalid(Sqrt_d_input_valid),
    .s_axis_a_tdata(f_inputA),

    .m_axis_result_tdata(f_Sqrt_d_result),
    .m_axis_result_tvalid(f_Sqrt_d_valid)
);

FP_CmpLT_D FP_CmpLT_D(
    .aclk(clk_i),

    .s_axis_a_tvalid(CmpLT_d_input_valid),
    .s_axis_a_tdata(f_inputA),

    .s_axis_b_tvalid(CmpLT_d_input_valid),
    .s_axis_b_tdata(f_inputB),
    
    .m_axis_result_tdata(f_CmpLT_d_result),
    .m_axis_result_tvalid(f_CmpLT_d_valid)
);

FP_MAddSub_D FP_MAddSub_D(
    .aclk(clk_i),

    .s_axis_a_tvalid(MAddSub_d_input_valid),
    .s_axis_a_tdata(f_inputA),

    .s_axis_b_tvalid(MAddSub_d_input_valid),
    .s_axis_b_tdata(f_inputB),
    
    .s_axis_c_tvalid(MAddSub_d_input_valid),
    .s_axis_c_tdata(f_inputC),
    
    .m_axis_result_tdata(f_MAddSub_d_result),
    .m_axis_result_tvalid(f_MAddSub_d_valid)
);

FP_CVT_W_D FP_CVT_W_D(
    .aclk(clk_i),

    .s_axis_a_tvalid(CVT_W_d_input_valid),
    .s_axis_a_tdata(f_inputA),

    .m_axis_result_tdata(f_CVT_W_d_result),
    .m_axis_result_tvalid(f_CVT_W_d_valid)
);

FP_EQ_D FP_EQ_D(
    .aclk(clk_i),

    .s_axis_a_tvalid(EQ_d_input_valid),
    .s_axis_a_tdata(f_inputA),

    .s_axis_b_tvalid(EQ_d_input_valid),
    .s_axis_b_tdata(f_inputB),

    .m_axis_result_tdata(f_EQ_d_result),
    .m_axis_result_tvalid(f_EQ_d_valid)
);

FP_LE_D FP_LE_D(
    .aclk(clk_i),

    .s_axis_a_tvalid(LE_d_input_valid),
    .s_axis_a_tdata(f_inputA),

    .s_axis_b_tvalid(LE_d_input_valid),
    .s_axis_b_tdata(f_inputB),

    .m_axis_result_tdata(f_LE_d_result),
    .m_axis_result_tvalid(f_LE_d_valid)
);

FP_CVT_D_W FP_CVT_D_W(
    .aclk(clk_i),

    .s_axis_a_tvalid(CVT_d_W_input_valid),
    .s_axis_a_tdata(inputA),

    .m_axis_result_tdata(f_CVT_d_W_result),
    .m_axis_result_tvalid(f_CVT_d_W_valid)
);

FP_CVT_D_WU FP_CVT_D_WU(
    .aclk(clk_i),

    .s_axis_a_tvalid(CVT_d_WU_input_valid),
    .s_axis_a_tdata(inputA),

    .m_axis_result_tdata(f_CVT_d_WU_result),
    .m_axis_result_tvalid(f_CVT_d_WU_valid)
);

FP_CVT_D_S FP_CVT_D_S(
    .aclk(clk_i),

    .s_axis_a_tvalid(CVT_d_s_input_valid),
    .s_axis_a_tdata(f_inputA[31:0]),

    .m_axis_result_tdata(f_CVT_d_s_result),
    .m_axis_result_tvalid(f_CVT_d_s_valid)
);

FP_CVT_S_D FP_CVT_S_D(
    .aclk(clk_i),

    .s_axis_a_tvalid(CVT_s_d_input_valid),
    .s_axis_a_tdata(f_inputA),

    .m_axis_result_tdata(f_CVT_s_d_result),
    .m_axis_result_tvalid(f_CVT_s_d_valid)
);

assign f_SGNJ_s_result = (f_SGNJ_s_op == 1) ? {rs2_f_data_i[31], rs1_f_data_i[30 : 0]}
                        : (f_SGNJ_s_op == 2) ? {~rs2_f_data_i[31], rs1_f_data_i[30 : 0]}
                        : (f_SGNJ_s_op == 3) ? {rs1_f_data_i[31] ^ rs2_f_data_i[31], rs1_f_data_i[30 : 0]} : 0;

assign f_SGNJ_d_result = (f_SGNJ_d_op == 1) ? {rs2_f_data_i[63], rs1_f_data_i[62 : 0]}
                        : (f_SGNJ_d_op == 2) ? {~rs2_f_data_i[63], rs1_f_data_i[62 : 0]}
                        : (f_SGNJ_d_op == 3) ? {rs1_f_data_i[63] ^ rs2_f_data_i[63], rs1_f_data_i[62 : 0]} : 0;

// F extension operation sel : {1: add}, {2: sub}, {3: mul}, {4: div}, {5: sqrt}, {6: min}, {7: max}, {8: madd}, {9: msub}
                            // , {10: nmsub}, {11: nmadd}, {12: sgnj}, {13: sgnjn}, {14: sgnjx}, {15: cvt_w_s}, {16: cvt_wu_s}
                            // , {17: mv_x_w}, {18: mv_w_x}, {19: equal}, {20: less than}, {21: less equal}, {22: class}, {23: cvt_s_w}, {24: cvt_s_wu}
// D extension operation sel : {25: add}, {26: sub}, {27: mul}, {28: div}, {29: sqrt}, {30: min}, {31: max}, {32: madd}
                            // , {33: msub}, {34: nmsub}, {35: nmadd}, {36:sgnj}, {37: sgnjn}, {38: sgnjx}, {39: cvt_w_d}, {40: cvt_wu_d}
                            // , {41: cvt_d_s}, {42: cvt_s_d}, {43: equal}, {44: less than}, {45: less equal}, {46: class}, {47: cvt_d_w}, {48: cvt_d_wu}
// FPIP sel : {1: s_add/sub}, {2: s_mul}, {3: s_div}, {4: s_sqrt}, {5: s_min/max/lt}, {6: s_madd/msub/nmadd/nmsub}
//             , {7: cvt_w_s, cvt_wu_s}, {8: s_eq}, {9: s_le}, {10: cvt_s_w}, {11: cvt_s_wu}, {12: d_add/sub}
//             , {13: d_mul}, {14: d_div}, {15: d_sqrt}, {16: d_min/max/lt}, {17: d_madd/msub/nmadd/nmsub}
//             , {18: cvt_w_d/cvt_wu_d}, {19: d_eq}, {20: d_le}, {21: cvt_d_w}, {22: cvt_d_wu}, {23: cvt_d_s}, {24: cvt_s_d}
assign exe_result = fp_op_i ? (
                fp_func_sel_i == 15 ? f_CVT_W_s_result
                : fp_func_sel_i == 16 ? f_CVT_WU_s_result 
                : fp_func_sel_i == 17 ? rs1_f_data_i[31:0]
                : fp_func_sel_i == 19 ? f_EQ_s_answer
                : fp_func_sel_i == 20 ? f_LT_s_answer
                : fp_func_sel_i == 21 ? f_LE_s_answer
                : fp_func_sel_i == 22 ? f_CLASS_s_answer
                : fp_func_sel_i == 39 ? f_CVT_W_d_result
                : fp_func_sel_i == 40 ? f_CVT_WU_d_result 
                : fp_func_sel_i == 43 ? f_EQ_d_answer
                : fp_func_sel_i == 44 ? f_LT_d_answer
                : fp_func_sel_i == 45 ? f_LE_d_answer
                : fp_func_sel_i == 46 ? f_CLASS_d_answer
                : 0)
                : alu_muldiv_sel_i ? muldiv_result : alu_result;

assign f_result = fp_unit_sel_i == 1 ? {32'hffffffff, f_AddSub_s_result} 
                : fp_unit_sel_i == 2 ? {32'hffffffff, f_Mul_s_result}
                : fp_unit_sel_i == 3 ? {32'hffffffff, f_Div_s_result}
                : fp_unit_sel_i == 4 ? {32'hffffffff, f_Sqrt_s_result}
                : fp_func_sel_i == 6 | fp_func_sel_i == 7 ? {32'hffffffff, f_CmpLT_s_answer}
                : fp_unit_sel_i == 6 ? {32'hffffffff, f_MAddSub_s_result}
                : fp_unit_sel_i == 10 ? {32'hffffffff, f_CVT_s_W_result} 
                : fp_unit_sel_i == 11 ? {32'hffffffff, f_CVT_s_WU_result} 
                : fp_func_sel_i == 18 ? {32'hffffffff, rs1_data_i}
                : (fp_func_sel_i == 12 | fp_func_sel_i == 13 | fp_func_sel_i == 14) ? {32'hffffffff, f_SGNJ_s_result} 
                : fp_unit_sel_i == 24 ? {32'hffffffff, f_CVT_s_d_result}
                : fp_unit_sel_i == 12 ? f_AddSub_d_result 
                : fp_unit_sel_i == 13 ? f_Mul_d_result
                : fp_unit_sel_i == 14 ? f_Div_d_result
                : fp_unit_sel_i == 15 ? f_Sqrt_d_result
                : fp_func_sel_i == 30 | fp_func_sel_i == 31 ? f_CmpLT_d_answer 
                : fp_unit_sel_i == 17 ? f_MAddSub_d_result
                : fp_unit_sel_i == 21 ? f_CVT_d_W_result 
                : fp_unit_sel_i == 22 ? f_CVT_d_WU_result 
                : (fp_func_sel_i == 36 | fp_func_sel_i == 37 | fp_func_sel_i == 38) ? f_SGNJ_d_result 
                : fp_unit_sel_i == 23 ? f_CVT_d_s_result : 0;

assign fpu_stall = (ipS_nxt == ip_BUSY) | FPIP_input_valid;

`else

// ===============================================================================
//  Floating point instructions are disabled so fpu_stall is always 0.
//
assign exe_result = alu_muldiv_sel_i ? muldiv_result : alu_result;
assign fpu_stall = 0;

`endif // ENABLE_FPU

// // =============================================================================
// //  Profiler for FreeRTOS Context Switching (Added by Copilot)
// // =============================================================================

// // --- 使用者請填入從 objdump 查到的位址 ---
// // 注意：請將 32'h8000_xxxx 替換為實際的 Trap Handler 入口與出口位址
// // 提示：在 objdump 中搜尋 <freertos_risc_v_trap_handler> 找入口
// // 提示：在 handler 函式結尾找 mret 指令的位址作為出口
// localparam [31:0] TRAP_ENTRY_ADDR = 32'h8000_9700; // 請修改此處: Trap Handler 入口
// localparam [31:0] TRAP_EXIT_ADDR  = 32'h8000_98e8; // 請修改此處: mret 指令位址

// // --- 使用者指定的 Start/End Flag ---
// localparam [31:0] PROFILER_START_ADDR = 32'h8000_15bc;
// localparam [31:0] PROFILER_END_ADDR   = 32'h8000_15d0;

// // --- Profiler 暫存器 (使用 ( * mark_debug = "true" *) 防止被優化，方便 ILA 觀察) ---
// (* mark_debug = "true" *) reg [63:0] total_cycles;        // 總 Cycle 數
// (* mark_debug = "true" *) reg [31:0] cs_count;            // Context Switch 次數
// (* mark_debug = "true" *) reg [63:0] cs_cycles_accum;     // Context Switch 累積花費 Cycle 數
// (* mark_debug = "true" *) reg [31:0] cs_cycles_max;       // 單次最大花費
// (* mark_debug = "true" *) reg [31:0] cs_cycles_min;       // 單次最小花費
// (* mark_debug = "true" *) reg [31:0] current_cs_cycles;   // 當前這次 Switch 已經花的 Cycle
// (* mark_debug = "true" *) reg        is_in_cs;            // 是否正在 Context Switch 中
// (* mark_debug = "true" *) reg        profiler_active;     // 是否處於量測區間

// always @(posedge clk_i) begin
//     if (rst_i) begin
//         total_cycles      <= 0;
//         cs_count          <= 0;
//         cs_cycles_accum   <= 0;
//         cs_cycles_max     <= 0;
//         cs_cycles_min     <= 32'hFFFF_FFFF;
//         current_cs_cycles <= 0;
//         is_in_cs          <= 0;
//         profiler_active   <= 0;
//     end
//     else begin
//         // 1. 控制 Profiler 啟動/停止
//         if (!stall_i) begin
//             if (pc_i == PROFILER_START_ADDR)
//                 profiler_active <= 1;
//             else if (pc_i == PROFILER_END_ADDR)
//                 profiler_active <= 0;
//         end

//         // 2. 計算總 Cycle 數 (僅在 active 期間計算)
//         if (profiler_active) begin
//             total_cycles <= total_cycles + 1;
//         end

//         // 3. 偵測進入 Context Switch (Trap Handler)
//         // 必須檢查 !stall_i 確保是指令剛執行到的那一個 cycle
//         if (!stall_i && pc_i == TRAP_ENTRY_ADDR) begin
//             if (profiler_active) begin
//                 is_in_cs <= 1;
//                 current_cs_cycles <= 0;
//             end
//         end

//         // 4. 計算 Context Switch 持續時間
//         if (is_in_cs) begin
//             current_cs_cycles <= current_cs_cycles + 1;

//             // 5. 偵測離開 Context Switch (mret)
//             if (!stall_i && pc_i == TRAP_EXIT_ADDR) begin
//                 is_in_cs <= 0;
//                 cs_count <= cs_count + 1;
//                 cs_cycles_accum <= cs_cycles_accum + current_cs_cycles;

//                 // 更新最大/最小值
//                 if (current_cs_cycles > cs_cycles_max) cs_cycles_max <= current_cs_cycles;
//                 if (current_cs_cycles < cs_cycles_min) cs_cycles_min <= current_cs_cycles;
//             end
//         end
//     end
// end

// =============================================================================
// Profiler for FreeRTOS Context Switching
// =============================================================================

// // --- Trap Handler 相關位址 ---
// localparam [31:0] TRAP_ENTRY_ADDR     = 32'h8000_9700;  // freertos_risc_v_trap_handler
// localparam [31:0] TIMER_CS_CALL_ADDR  = 32'h8000_9800;  // Timer Interrupt 的 jal vTaskSwitchContext
// localparam [31:0] ECALL_CS_CALL_ADDR  = 32'h8000_9838;  // ecall 的 jal vTaskSwitchContext
// localparam [31:0] TRAP_EXIT_ADDR      = 32'h8000_98e8;  // mret

// // localparam [31:0] TRAP_ENTRY_ADDR     = 32'h8000_9600;  // freertos_risc_v_trap_handler
// // localparam [31:0] TIMER_CS_CALL_ADDR  = 32'h8000_9700;  // Timer Interrupt 的 jal vTaskSwitchContext
// // localparam [31:0] ECALL_CS_CALL_ADDR  = 32'h8000_9738;  // ecall 的 jal vTaskSwitchContext
// // localparam [31:0] TRAP_EXIT_ADDR      = 32'h8000_97e8;  // mret

// // --- Start/End Flag ---
// localparam [31:0] PROFILER_START_ADDR = 32'h8000_1648;
// localparam [31:0] PROFILER_END_ADDR   = 32'h8000_1564;
// // localparam [31:0] PROFILER_START_ADDR = 32'h8000_1518;
// // localparam [31:0] PROFILER_END_ADDR   = 32'h8000_1434;


// // --- Profiler 暫存器 ---
// (* mark_debug = "true" *) reg [63:0] total_cycles;
// (* mark_debug = "true" *) reg [31:0] timer_cs_count;       // Timer 觸發的 Context Switch
// (* mark_debug = "true" *) reg [31:0] ecall_cs_count;       // ecall 觸發的 Context Switch
// (* mark_debug = "true" *) reg [63:0] timer_cs_cycles_accum;
// (* mark_debug = "true" *) reg [63:0] ecall_cs_cycles_accum;
// (* mark_debug = "true" *) reg [31:0] timer_cs_cycles_max;
// (* mark_debug = "true" *) reg [31:0] timer_cs_cycles_min;
// (* mark_debug = "true" *) reg [31:0] ecall_cs_cycles_max;
// (* mark_debug = "true" *) reg [31:0] ecall_cs_cycles_min;
// reg [31:0] current_cs_cycles;
// (* mark_debug = "true" *) reg        is_in_cs;
// (* mark_debug = "true" *) reg        is_timer_cs;          // 當前是否是 Timer CS
// (* mark_debug = "true" *) reg        is_ecall_cs;          // 當前是否是 ecall CS
// (* mark_debug = "true" *) reg        profiler_active;

// always @(posedge clk_i) begin
//     if (rst_i) begin
//         profiler_active      <= 0;
//     end
//     else begin
//         if (!stall_i) begin
//             if (pc_i == PROFILER_START_ADDR)
//                 profiler_active <= 1;
//             else if (pc_i == PROFILER_END_ADDR)
//                 profiler_active <= 0;
//         end
//     end
// end

// always @(posedge clk_i) begin
//     if (rst_i) begin
//         total_cycles         <= 0;
//         timer_cs_count       <= 0;
//         ecall_cs_count       <= 0;
//         timer_cs_cycles_accum <= 0;
//         ecall_cs_cycles_accum <= 0;
//         timer_cs_cycles_max  <= 0;
//         timer_cs_cycles_min  <= 32'hFFFF_FFFF;
//         ecall_cs_cycles_max  <= 0;
//         ecall_cs_cycles_min  <= 32'hFFFF_FFFF;
//         current_cs_cycles    <= 0;
//         is_in_cs             <= 0;
//         is_timer_cs          <= 0;
//         is_ecall_cs          <= 0;
//     end
//     else begin
//         // 1. 控制 Profiler 啟動/停止

//         // 2. 計算總 Cycle 數
//         if (profiler_active)
//             total_cycles <= total_cycles + 1;

//         // 3. 偵測進入 Trap Handler
//         if (!stall_i && pc_i == TRAP_ENTRY_ADDR && profiler_active) begin
//             is_in_cs <= 1;
//             current_cs_cycles <= 0;
//             is_timer_cs <= 0;  // 預設不是 timer，等後續判斷
//             is_ecall_cs <= 0;
//         end

//         // 4. 計算 Context Switch 持續時間
//         if (is_in_cs)
//             current_cs_cycles <= current_cs_cycles + 1;

//         // 5. 偵測是 Timer CS 還是 ecall CS
//         if (!stall_i && is_in_cs) begin
//             if (pc_i == TIMER_CS_CALL_ADDR)
//                 is_timer_cs <= 1;
//             // ecall CS 不需要特別標記，因為預設就是 ecall
//             else if (pc_i == ECALL_CS_CALL_ADDR)
//                 is_ecall_cs <= 1;
//         end

//         // 6. 偵測離開 (mret)
//         if (!stall_i && pc_i == TRAP_EXIT_ADDR && is_in_cs) begin
//             is_in_cs <= 0;
            
//             if (is_timer_cs) begin
//                 timer_cs_count <= timer_cs_count + 1;
//                 timer_cs_cycles_accum <= timer_cs_cycles_accum + current_cs_cycles;
//                 if (current_cs_cycles > timer_cs_cycles_max) timer_cs_cycles_max <= current_cs_cycles;
//                 if (current_cs_cycles < timer_cs_cycles_min) timer_cs_cycles_min <= current_cs_cycles;
//             end
//             else if (is_ecall_cs) begin
//                 ecall_cs_count <= ecall_cs_count + 1;
//                 ecall_cs_cycles_accum <= ecall_cs_cycles_accum + current_cs_cycles;
//                 if (current_cs_cycles > ecall_cs_cycles_max) ecall_cs_cycles_max <= current_cs_cycles;
//                 if (current_cs_cycles < ecall_cs_cycles_min) ecall_cs_cycles_min <= current_cs_cycles;
//             end

//             // 更新 max/min

//         end
//     end
// end

// =============================================================================
//  Semaphore Overhead Profiler
// =============================================================================

// --- Semaphore 函式位址 ---
// localparam [31:0] SEM_TAKE_ENTRY = 32'h8000_1348;  // xQueueReceive 入口
// localparam [31:0] SEM_TAKE_EXIT  = 32'h8000_4260;  // xQueueReceive ret
// localparam [31:0] SEM_GIVE_ENTRY = 32'h8000_1190;  // xQueueGenericSend 入口
// localparam [31:0] SEM_GIVE_EXIT  = 32'h8000_3700;  // xQueueReceive ret (End of handoff)

// localparam [31:0] SEM_TAKE_ENTRY = 32'h8000_40fc;  // xQueueReceive 入口
// localparam [31:0] SEM_TAKE_EXIT  = 32'h8000_42ec;  // xQueueReceive ret
// localparam [31:0] SEM_GIVE_ENTRY = 32'h8000_349c;  // xQueueGenericSend 入口
// localparam [31:0] SEM_GIVE_EXIT  = 32'h8000_378c;  // xQueueGenericSend ret (End of handoff)

// // --- Profiler 暫存器 ---
// (* mark_debug = "true" *) reg [31:0] sem_take_count;
// (* mark_debug = "true" *) reg [63:0] sem_take_cycles;
// (* mark_debug = "true" *) reg [31:0] sem_take_max;
// (* mark_debug = "true" *) reg [31:0] sem_take_min;

// (* mark_debug = "true" *) reg [31:0] sem_give_count;
// (* mark_debug = "true" *) reg [63:0] sem_give_cycles;
// (* mark_debug = "true" *) reg [31:0] sem_give_max;
// (* mark_debug = "true" *) reg [31:0] sem_give_min;

// reg [31:0] current_sem_take_cycles;
// reg [31:0] current_sem_give_cycles;
// (* mark_debug = "true" *) reg        in_sem_take;
// (* mark_debug = "true" *) reg        in_sem_give;

// always @(posedge clk_i) begin
//     if (rst_i) begin
//         sem_take_count    <= 0;
//         sem_take_cycles   <= 0;
//         sem_take_max      <= 0;
//         sem_take_min      <= 32'hFFFF_FFFF;
//         sem_give_count    <= 0;
//         sem_give_cycles   <= 0;
//         sem_give_max      <= 0;
//         sem_give_min      <= 32'hFFFF_FFFF;
//         current_sem_take_cycles <= 0;
//         current_sem_give_cycles <= 0;
//         in_sem_take       <= 0;
//         in_sem_give       <= 0;
//     end
//     else if (profiler_active) begin
        
//         // ==================== xSemaphoreTake ====================
//         // 進入 xQueueReceive
//         if (pc_i == SEM_TAKE_ENTRY) begin
//             in_sem_take <= 1;
//             current_sem_take_cycles <= 0;
//         end
        
//         // 在函式內計數
//         if (in_sem_take) begin
//             current_sem_take_cycles <= current_sem_take_cycles + 1;
            
//             // 離開 xQueueReceive (ret)
//             if (pc_i == SEM_TAKE_EXIT) begin
//                 in_sem_take <= 0;
//                 sem_take_count <= sem_take_count + 1;
//                 sem_take_cycles <= sem_take_cycles + current_sem_take_cycles;
                
//                 if (current_sem_take_cycles > sem_take_max) 
//                     sem_take_max <= current_sem_take_cycles;
//                 if (current_sem_take_cycles < sem_take_min) 
//                     sem_take_min <= current_sem_take_cycles;
//             end
//         end
        
//         // ==================== xSemaphoreGive ====================
//         // 進入 xQueueGenericSend
//         if (pc_i == SEM_GIVE_ENTRY) begin
//             in_sem_give <= 1;
//             current_sem_give_cycles <= 0;
//             sem_give_count <= sem_give_count + 1;
//         end
        
//         // 在函式內計數
//         if (in_sem_give) begin
//             current_sem_give_cycles <= current_sem_give_cycles + 1;
            
//             // 離開 xQueueGenericSend (ret)
//             if (pc_i == SEM_GIVE_EXIT) begin
//                 in_sem_give <= 0;
                
//                 sem_give_cycles <= sem_give_cycles + current_sem_give_cycles;
                
//                 if (current_sem_give_cycles > sem_give_max) 
//                     sem_give_max <= current_sem_give_cycles;
//                 if (current_sem_give_cycles < sem_give_min) 
//                     sem_give_min <= current_sem_give_cycles;
//             end
//         end
//     end
// end

// =============================================================================
//  Synchronization Overhead Profiler
// =============================================================================

// // --- Critical Section 位址 ---
// localparam [31:0] ENTER_CRITICAL_ENTRY = 32'h8000_81c8;
// localparam [31:0] ENTER_CRITICAL_EXIT  = 32'h8000_81f0;  // ret 指令
// localparam [31:0] EXIT_CRITICAL_ENTRY  = 32'h8000_81f4;
// localparam [31:0] EXIT_CRITICAL_EXIT   = 32'h8000_8230;  // ret 指令

// // --- Profiler 暫存器 ---
// (* mark_debug = "true" *) reg [31:0] enter_critical_count;
// (* mark_debug = "true" *) reg [63:0] enter_critical_cycles;
// (* mark_debug = "true" *) reg [31:0] exit_critical_count;
// (* mark_debug = "true" *) reg [63:0] exit_critical_cycles;
// reg [31:0] current_sync_cycles;
// (* mark_debug = "true" *) reg        in_enter_critical;
// (* mark_debug = "true" *) reg        in_exit_critical;

// always @(posedge clk_i) begin
//     if (rst_i) begin
//         enter_critical_count  <= 0;
//         enter_critical_cycles <= 0;
//         exit_critical_count   <= 0;
//         exit_critical_cycles  <= 0;
//         current_sync_cycles   <= 0;
//         in_enter_critical     <= 0;
//         in_exit_critical      <= 0;
//     end
//     else if (profiler_active) begin
//         // --- 測量 vTaskEnterCritical ---
//         if (pc_i == ENTER_CRITICAL_ENTRY) begin
//             in_enter_critical <= 1;
//             current_sync_cycles <= 0;
//         end
//         if (in_enter_critical) begin
//             current_sync_cycles <= current_sync_cycles + 1;
//             if (pc_i == ENTER_CRITICAL_EXIT) begin
//                 in_enter_critical <= 0;
//                 enter_critical_count <= enter_critical_count + 1;
//                 enter_critical_cycles <= enter_critical_cycles + current_sync_cycles;
//             end
//         end
        
//         // --- 測量 vTaskExitCritical ---
//         if (pc_i == EXIT_CRITICAL_ENTRY) begin
//             in_exit_critical <= 1;
//             current_sync_cycles <= 0;
//         end
//         if (in_exit_critical) begin
//             current_sync_cycles <= current_sync_cycles + 1;
//             if (pc_i == EXIT_CRITICAL_EXIT) begin
//                 in_exit_critical <= 0;
//                 exit_critical_count <= exit_critical_count + 1;
//                 exit_critical_cycles <= exit_critical_cycles + current_sync_cycles;
//             end
//         end
//     end
// end

endmodule
