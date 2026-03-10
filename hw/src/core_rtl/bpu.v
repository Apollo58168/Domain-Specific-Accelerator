`timescale 1ns / 1ps
// =============================================================================
//  Program : bpu.v
//  Author  : Jin-you Wu
//  Date    : Jan/19/2019
// -----------------------------------------------------------------------------
//  Description:
//  This is the Branch Prediction Unit (BPU) of the Aquila core (A RISC-V core).
// -----------------------------------------------------------------------------
//  Revision information:
//
//  Aug/15/2020, by Chun-Jen Tsai:
//    Using a single BPU to handle both JAL and Branch instructions. In the
//    original code, an additional Unconditional Branch Prediction Unit (UC-BPU)
//    was used to handle the JAL instructions.
//
// Aug/16/2023, by Chun-Jen Tsai:
//    Replace the fully associative BHT by a TAG-based direct-mapping BHT table.
//    The 2-bit Bimodal FSM is still used. The performance drops a little (0.03
//    DMIPS), but the resource usage drops significantly. Note that we do not
//    have to use TAGged memory for direct-mapping BHT. We simply use it to
//    demonstrate how TAG memory can be implemented.
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

// To enable TAGE predictor, uncomment the following line:
// `define USE_TAGE
// To use Bimodal predictor (default), keep the above line commented out

module bpu #( parameter ENTRY_NUM = 64, parameter XLEN = 32 )
(
    // System signals
    input               clk_i,
    input               rst_i,
    input               stall_i,

    // from Program_Counter
    input  [XLEN-1 : 0] pc_i, // Addr of the next instruction to be fetched.

    // from Decode
    input               is_jal_i,
    input               is_cond_branch_i,
    input  [XLEN-1 : 0] dec_pc_i, // Addr of the instr. just processed by decoder.

    // from Execute
    input               exe_is_branch_i,
    input               branch_taken_i,
    input               branch_misprediction_i,
    input  [XLEN-1 : 0] branch_target_addr_i,

    // to Program_Counter
    output              branch_hit_o,
    output              branch_decision_o,
    output [XLEN-1 : 0] branch_target_addr_o,
    
    // TAGE profiling (only active when USE_TAGE is defined)
    output [2:0]        tage_provider_o  // Which table provided the prediction (0=T0, 1=T1, 2=T2, 3=T3, 4=T4)
);

localparam NBITS = $clog2(ENTRY_NUM);

// Common signals for both predictors
wire [NBITS-1 : 0]      read_addr;
wire [NBITS-1 : 0]      write_addr;
wire [XLEN-1 : 0]       branch_inst_tag;
wire                    we;
reg                     BHT_hit_ff, BHT_hit;

`ifdef USE_TAGE
// Add valid bits for BHT entries (TAGE only, to avoid false hits)
reg [ENTRY_NUM-1:0]     bht_valid;

`endif

`ifdef USE_TAGE
// =============================================================================
// TAGE Predictor Configuration with Statistical Corrector
// =============================================================================
localparam NUM_TABLES = 5;           // 1 base + 4 tagged tables
localparam HIST_LEN_1 = 4;           // T1: short history
localparam HIST_LEN_2 = 10;          // T2: medium-short history
localparam HIST_LEN_3 = 32;          // T3: medium-long history
localparam HIST_LEN_4 = 128;         // T4: very long history (new)
localparam MAX_HIST_LEN = HIST_LEN_4;
localparam TAG_WIDTH = 8;            // Tag width for tagged tables T1-T3
localparam T4_TAG_WIDTH = 9;         // 9-bit tag for T4 (more bits for longer history)
localparam COUNTER_WIDTH = 3;        // 3-bit saturating counter for T1-T4
localparam T0_COUNTER_WIDTH = 2;     // 2-bit counter for T0 (like Bimodal)

// Statistical Corrector: Per-PC confidence counter for TAGE vs Bimodal selection
// 2-bit counter: 00/01 = prefer Bimodal (T0), 10/11 = prefer TAGE (T1/T2/T3)
reg [1:0] tage_confidence [ENTRY_NUM-1:0];

// Direction Bias Tracker: Learn if this PC is forward or backward branch
// 2-bit saturating counter: 00/01 = likely forward, 10/11 = likely backward
reg [1:0] direction_bias [ENTRY_NUM-1:0];

// Global history register
reg [MAX_HIST_LEN-1:0] global_history;

// TAGE Tables
// T0: Base predictor (2-bit Bimodal counter, no history)
reg [T0_COUNTER_WIDTH-1:0] T0_counter [ENTRY_NUM-1:0];

// T1-T3: Tagged tables with geometric history lengths (3-bit counters)
reg [TAG_WIDTH-1:0]     T1_tag [ENTRY_NUM-1:0];
reg [COUNTER_WIDTH-1:0] T1_counter [ENTRY_NUM-1:0];
reg                     T1_useful [ENTRY_NUM-1:0];

reg [TAG_WIDTH-1:0]     T2_tag [ENTRY_NUM-1:0];
reg [COUNTER_WIDTH-1:0] T2_counter [ENTRY_NUM-1:0];
reg                     T2_useful [ENTRY_NUM-1:0];

reg [TAG_WIDTH-1:0]     T3_tag [ENTRY_NUM-1:0];
reg [COUNTER_WIDTH-1:0] T3_counter [ENTRY_NUM-1:0];
reg                     T3_useful [ENTRY_NUM-1:0];

reg [T4_TAG_WIDTH-1:0]  T4_tag [ENTRY_NUM-1:0];
reg [COUNTER_WIDTH-1:0] T4_counter [ENTRY_NUM-1:0];
reg                     T4_useful [ENTRY_NUM-1:0];

// Hash functions for index computation (separate for each history length)
function [NBITS-1:0] compute_index_T1;
    input [XLEN-1:0] pc;
    input [MAX_HIST_LEN-1:0] history;
    begin
        compute_index_T1 = (pc[NBITS+1:2] ^ history[HIST_LEN_1-1:0]) & ((1 << NBITS) - 1);
    end
endfunction

function [NBITS-1:0] compute_index_T2;
    input [XLEN-1:0] pc;
    input [MAX_HIST_LEN-1:0] history;
    begin
        compute_index_T2 = (pc[NBITS+1:2] ^ history[HIST_LEN_2-1:0]) & ((1 << NBITS) - 1);
    end
endfunction

function [NBITS-1:0] compute_index_T3;
    input [XLEN-1:0] pc;
    input [MAX_HIST_LEN-1:0] history;
    begin
        compute_index_T3 = (pc[NBITS+1:2] ^ history[HIST_LEN_3-1:0]) & ((1 << NBITS) - 1);
    end
endfunction

function [NBITS-1:0] compute_index_T4;
    input [XLEN-1:0] pc;
    input [MAX_HIST_LEN-1:0] history;
    begin
        compute_index_T4 = (pc[NBITS+1:2] ^ history[HIST_LEN_4-1:0] ^ history[HIST_LEN_4-1:HIST_LEN_4-NBITS]) & ((1 << NBITS) - 1);
    end
endfunction

// Hash functions for tag computation (separate for each history length)
function [TAG_WIDTH-1:0] compute_tag_T1;
    input [XLEN-1:0] pc;
    input [MAX_HIST_LEN-1:0] history;
    reg [TAG_WIDTH-1:0] hash1, hash2;
    begin
        hash1 = pc[TAG_WIDTH+1:2];
        hash2 = history[HIST_LEN_1-1:0];
        compute_tag_T1 = hash1 ^ hash2[TAG_WIDTH-1:0];
    end
endfunction

function [TAG_WIDTH-1:0] compute_tag_T2;
    input [XLEN-1:0] pc;
    input [MAX_HIST_LEN-1:0] history;
    reg [TAG_WIDTH-1:0] hash1, hash2;
    begin
        hash1 = pc[TAG_WIDTH+1:2];
        hash2 = history[HIST_LEN_2-1:0] ^ history[TAG_WIDTH-1:0];
        compute_tag_T2 = hash1 ^ hash2;
    end
endfunction

function [TAG_WIDTH-1:0] compute_tag_T3;
    input [XLEN-1:0] pc;
    input [MAX_HIST_LEN-1:0] history;
    reg [TAG_WIDTH-1:0] hash1, hash2;
    begin
        hash1 = pc[TAG_WIDTH+1:2];
        hash2 = history[HIST_LEN_3-1:HIST_LEN_3-TAG_WIDTH] ^ history[TAG_WIDTH-1:0];
        compute_tag_T3 = hash1 ^ hash2;
    end
endfunction

function [T4_TAG_WIDTH-1:0] compute_tag_T4;
    input [XLEN-1:0] pc;
    input [MAX_HIST_LEN-1:0] history;
    reg [T4_TAG_WIDTH-1:0] hash1, hash2, hash3;
    begin
        hash1 = pc[T4_TAG_WIDTH+1:2];
        hash2 = history[HIST_LEN_4-1:HIST_LEN_4-T4_TAG_WIDTH];
        hash3 = history[T4_TAG_WIDTH-1:0];
        compute_tag_T4 = hash1 ^ hash2 ^ hash3;
    end
endfunction

// Prediction logic
wire [NBITS-1:0] idx_fetch_T0, idx_fetch_T1, idx_fetch_T2, idx_fetch_T3, idx_fetch_T4;
wire [TAG_WIDTH-1:0] tag_fetch_T1, tag_fetch_T2, tag_fetch_T3;
wire [T4_TAG_WIDTH-1:0] tag_fetch_T4;

assign idx_fetch_T0 = pc_i[NBITS+1:2];
assign idx_fetch_T1 = compute_index_T1(pc_i, global_history);
assign idx_fetch_T2 = compute_index_T2(pc_i, global_history);
assign idx_fetch_T3 = compute_index_T3(pc_i, global_history);
assign idx_fetch_T4 = compute_index_T4(pc_i, global_history);

assign tag_fetch_T1 = compute_tag_T1(pc_i, global_history);
assign tag_fetch_T2 = compute_tag_T2(pc_i, global_history);
assign tag_fetch_T3 = compute_tag_T3(pc_i, global_history);
assign tag_fetch_T4 = compute_tag_T4(pc_i, global_history);

// Tag match signals
wire match_T1 = (T1_tag[idx_fetch_T1] == tag_fetch_T1);
wire match_T2 = (T2_tag[idx_fetch_T2] == tag_fetch_T2);
wire match_T3 = (T3_tag[idx_fetch_T3] == tag_fetch_T3);
wire match_T4 = (T4_tag[idx_fetch_T4] == tag_fetch_T4);

// TAGE provider selection (longest matching history in tagged tables)
wire [2:0] tage_provider_raw;  // 3 bits now to support T4
assign tage_provider_raw = match_T4 ? 3'd4 :
                           match_T3 ? 3'd3 :
                           match_T2 ? 3'd2 :
                           match_T1 ? 3'd1 : 3'd0;

// TAGE provider selection (use longest matching history)
wire [2:0] tage_provider = tage_provider_raw;

// Direction-biased provider selection: Force forward branches to use T0 (Bimodal)
// Only strongly forward-biased (2'b00) branches are forced to T0
// All others (2'b01, 2'b10, 2'b11) can use TAGE if confidence allows
wire is_strongly_forward = (direction_bias[idx_fetch_T0] == 2'b00);

// Statistical Corrector: Use TAGE if confidence is high AND not strongly forward-biased
wire use_tage = (~is_strongly_forward) & tage_confidence[idx_fetch_T0][1];

wire [2:0] provider_sel;  // 3 bits now to support T4
// Strongly forward branches: Always use T0 (Bimodal is best: 1854 misp vs 3338+ with TAGE)
// Others (neutral/backward): Use TAGE tables if confidence is high
assign provider_sel = is_strongly_forward ? 3'd0 :          // Strong forward: Force T0
                      (use_tage ? tage_provider : 3'd0);    // Others: Normal logic

// Prediction output (MSB of selected counter)
// T0 uses 2-bit counter, T1-T4 use 3-bit counters
reg tage_prediction;
always @(*) begin
    case (provider_sel)
        3'd0: tage_prediction = T0_counter[idx_fetch_T0][T0_COUNTER_WIDTH-1];  // MSB of 2-bit
        3'd1: tage_prediction = T1_counter[idx_fetch_T1][COUNTER_WIDTH-1];     // MSB of 3-bit
        3'd2: tage_prediction = T2_counter[idx_fetch_T2][COUNTER_WIDTH-1];     // MSB of 3-bit
        3'd3: tage_prediction = T3_counter[idx_fetch_T3][COUNTER_WIDTH-1];     // MSB of 3-bit
        3'd4: tage_prediction = T4_counter[idx_fetch_T4][COUNTER_WIDTH-1];     // MSB of 3-bit
        default: tage_prediction = T0_counter[idx_fetch_T0][T0_COUNTER_WIDTH-1];
    endcase
end

// Update logic at Execute stage
wire [NBITS-1:0] idx_exe_T0, idx_exe_T1, idx_exe_T2, idx_exe_T3, idx_exe_T4;
wire [TAG_WIDTH-1:0] tag_exe_T1, tag_exe_T2, tag_exe_T3;
wire [T4_TAG_WIDTH-1:0] tag_exe_T4;

reg [2:0] provider_sel_r;  // 3 bits now to support T4
reg [MAX_HIST_LEN-1:0] global_history_r;

assign idx_exe_T0 = dec_pc_i[NBITS+1:2];
assign idx_exe_T1 = compute_index_T1(dec_pc_i, global_history_r);
assign idx_exe_T2 = compute_index_T2(dec_pc_i, global_history_r);
assign idx_exe_T3 = compute_index_T3(dec_pc_i, global_history_r);
assign idx_exe_T4 = compute_index_T4(dec_pc_i, global_history_r);

assign tag_exe_T1 = compute_tag_T1(dec_pc_i, global_history_r);
assign tag_exe_T2 = compute_tag_T2(dec_pc_i, global_history_r);
assign tag_exe_T3 = compute_tag_T3(dec_pc_i, global_history_r);
assign tag_exe_T4 = compute_tag_T4(dec_pc_i, global_history_r);

// Pipeline delay for provider selection
always @(posedge clk_i) begin
    if (rst_i) begin
        provider_sel_r <= 3'd0;
        global_history_r <= {MAX_HIST_LEN{1'b0}};
    end
    else if (!stall_i) begin
        provider_sel_r <= provider_sel;
        global_history_r <= global_history;
    end
end

// Counter update function (3-bit saturating counter for T1-T3)
function [COUNTER_WIDTH-1:0] update_counter_3bit;
    input [COUNTER_WIDTH-1:0] counter;
    input taken;
    begin
        if (taken) begin
            update_counter_3bit = (counter == {COUNTER_WIDTH{1'b1}}) ? counter : counter + 1'b1;
        end else begin
            update_counter_3bit = (counter == {COUNTER_WIDTH{1'b0}}) ? counter : counter - 1'b1;
        end
    end
endfunction

// Counter update function (2-bit saturating counter for T0, like Bimodal)
function [T0_COUNTER_WIDTH-1:0] update_counter_2bit;
    input [T0_COUNTER_WIDTH-1:0] counter;
    input taken;
    begin
        case (counter)
            2'b00: update_counter_2bit = taken ? 2'b01 : 2'b00;  // strongly not-taken
            2'b01: update_counter_2bit = taken ? 2'b11 : 2'b00;  // weakly not-taken
            2'b10: update_counter_2bit = taken ? 2'b11 : 2'b00;  // weakly taken
            2'b11: update_counter_2bit = taken ? 2'b11 : 2'b10;  // strongly taken
        endcase
    end
endfunction

integer idx;

// Update tables on branch resolution
always @(posedge clk_i) begin
    if (rst_i) begin
        // Initialize all tables
        for (idx = 0; idx < ENTRY_NUM; idx = idx + 1) begin
            T0_counter[idx] <= 2'b01;  // T0: 2-bit weakly not-taken (like Bimodal)
            // Initialize tags to 0 for maximum initial matches (fast learning)
            T1_tag[idx] <= {TAG_WIDTH{1'b0}};
            T1_counter[idx] <= 3'b100;  // Start at NEUTRAL (4/7) instead of weakly not-taken
            T1_useful[idx] <= 1'b0;
            T2_tag[idx] <= {TAG_WIDTH{1'b0}};
            T2_counter[idx] <= 3'b100;  // Neutral allows faster adaptation
            T2_useful[idx] <= 1'b0;
            T3_tag[idx] <= {TAG_WIDTH{1'b0}};
            T3_counter[idx] <= 3'b100;
            T3_useful[idx] <= 1'b0;
            T4_tag[idx] <= {T4_TAG_WIDTH{1'b0}};
            T4_counter[idx] <= 3'b100;
            T4_useful[idx] <= 1'b0;
            tage_confidence[idx] <= 2'b11;  // Start with MAXIMUM confidence (always try TAGE first)
            direction_bias[idx] <= 2'b01;   // Start neutral, slightly forward biased (need to learn)
        end
        global_history <= {MAX_HIST_LEN{1'b0}};
    end
    else if (!stall_i) begin
        // Update global history on every conditional branch
        if (exe_is_branch_i) begin
            global_history <= {global_history[MAX_HIST_LEN-2:0], branch_taken_i};
        end
        
        // Update counters and useful bits only for conditional branches
        if (exe_is_branch_i) begin
            case (provider_sel_r)
                3'd0: begin // Base predictor provided prediction
                    T0_counter[idx_exe_T0] <= update_counter_2bit(T0_counter[idx_exe_T0], branch_taken_i);
                    
                    // Allocate new entry in tagged table if misprediction
                    if (branch_misprediction_i) begin
                        // Try to allocate in T1 first, then T2, T3, T4
                        if (!T1_useful[idx_exe_T1]) begin
                            T1_tag[idx_exe_T1] <= tag_exe_T1;
                            T1_counter[idx_exe_T1] <= {branch_taken_i, {(COUNTER_WIDTH-1){~branch_taken_i}}};
                            T1_useful[idx_exe_T1] <= 1'b0;
                        end
                        else if (!T2_useful[idx_exe_T2]) begin
                            T2_tag[idx_exe_T2] <= tag_exe_T2;
                            T2_counter[idx_exe_T2] <= {branch_taken_i, {(COUNTER_WIDTH-1){~branch_taken_i}}};
                            T2_useful[idx_exe_T2] <= 1'b0;
                        end
                        else if (!T3_useful[idx_exe_T3]) begin
                            T3_tag[idx_exe_T3] <= tag_exe_T3;
                            T3_counter[idx_exe_T3] <= {branch_taken_i, {(COUNTER_WIDTH-1){~branch_taken_i}}};
                            T3_useful[idx_exe_T3] <= 1'b0;
                        end
                        else if (!T4_useful[idx_exe_T4]) begin
                            T4_tag[idx_exe_T4] <= tag_exe_T4;
                            T4_counter[idx_exe_T4] <= {branch_taken_i, {(COUNTER_WIDTH-1){~branch_taken_i}}};
                            T4_useful[idx_exe_T4] <= 1'b0;
                        end
                    end
                end
                
                3'd1: begin // T1 provided prediction
                    T1_counter[idx_exe_T1] <= update_counter_3bit(T1_counter[idx_exe_T1], branch_taken_i);
                    if (branch_misprediction_i) begin
                        T1_useful[idx_exe_T1] <= 1'b0;
                        // Try allocate in higher tables
                        if (!T2_useful[idx_exe_T2]) begin
                            T2_tag[idx_exe_T2] <= tag_exe_T2;
                            T2_counter[idx_exe_T2] <= {branch_taken_i, {(COUNTER_WIDTH-1){~branch_taken_i}}};
                            T2_useful[idx_exe_T2] <= 1'b0;
                        end
                        else if (!T3_useful[idx_exe_T3]) begin
                            T3_tag[idx_exe_T3] <= tag_exe_T3;
                            T3_counter[idx_exe_T3] <= {branch_taken_i, {(COUNTER_WIDTH-1){~branch_taken_i}}};
                            T3_useful[idx_exe_T3] <= 1'b0;
                        end
                        else if (!T4_useful[idx_exe_T4]) begin
                            T4_tag[idx_exe_T4] <= tag_exe_T4;
                            T4_counter[idx_exe_T4] <= {branch_taken_i, {(COUNTER_WIDTH-1){~branch_taken_i}}};
                            T4_useful[idx_exe_T4] <= 1'b0;
                        end
                    end else begin
                        T1_useful[idx_exe_T1] <= 1'b1;
                    end
                end
                
                3'd2: begin // T2 provided prediction
                    T2_counter[idx_exe_T2] <= update_counter_3bit(T2_counter[idx_exe_T2], branch_taken_i);
                    if (branch_misprediction_i) begin
                        T2_useful[idx_exe_T2] <= 1'b0;
                        // Try allocate in T3, T4
                        if (!T3_useful[idx_exe_T3]) begin
                            T3_tag[idx_exe_T3] <= tag_exe_T3;
                            T3_counter[idx_exe_T3] <= {branch_taken_i, {(COUNTER_WIDTH-1){~branch_taken_i}}};
                            T3_useful[idx_exe_T3] <= 1'b0;
                        end
                        else if (!T4_useful[idx_exe_T4]) begin
                            T4_tag[idx_exe_T4] <= tag_exe_T4;
                            T4_counter[idx_exe_T4] <= {branch_taken_i, {(COUNTER_WIDTH-1){~branch_taken_i}}};
                            T4_useful[idx_exe_T4] <= 1'b0;
                        end
                    end else begin
                        T2_useful[idx_exe_T2] <= 1'b1;
                    end
                end
                
                3'd3: begin // T3 provided prediction
                    T3_counter[idx_exe_T3] <= update_counter_3bit(T3_counter[idx_exe_T3], branch_taken_i);
                    if (branch_misprediction_i) begin
                        T3_useful[idx_exe_T3] <= 1'b0;
                        // Try allocate in T4
                        if (!T4_useful[idx_exe_T4]) begin
                            T4_tag[idx_exe_T4] <= tag_exe_T4;
                            T4_counter[idx_exe_T4] <= {branch_taken_i, {(COUNTER_WIDTH-1){~branch_taken_i}}};
                            T4_useful[idx_exe_T4] <= 1'b0;
                        end
                    end else begin
                        T3_useful[idx_exe_T3] <= 1'b1;
                    end
                end
                
                3'd4: begin // T4 provided prediction
                    T4_counter[idx_exe_T4] <= update_counter_3bit(T4_counter[idx_exe_T4], branch_taken_i);
                    if (branch_misprediction_i) begin
                        T4_useful[idx_exe_T4] <= 1'b0;
                    end else begin
                        T4_useful[idx_exe_T4] <= 1'b1;
                    end
                end
            endcase
            
            // Update direction bias (2-bit saturating counter)
            // Track if this PC tends to branch forward or backward
            if (branch_taken_i) begin
                if (branch_target_addr_i < dec_pc_i) begin
                    // Backward branch -> increment (move toward 2'b11)
                    if (direction_bias[idx_exe_T0] != 2'b11)
                        direction_bias[idx_exe_T0] <= direction_bias[idx_exe_T0] + 1'b1;
                end else begin
                    // Forward branch -> decrement (move toward 2'b00)
                    if (direction_bias[idx_exe_T0] != 2'b00)
                        direction_bias[idx_exe_T0] <= direction_bias[idx_exe_T0] - 1'b1;
                end
            end
            
            // Update confidence counter: favor TAGE for learning
            // Strategy: Keep confidence high to maximize TAGE usage
            if (provider_sel_r != 3'd0) begin
                // TAGE was used (T1/T2/T3/T4)
                if (branch_misprediction_i) begin
                    // TAGE failed -> decrease confidence, but not below 2'b10
                    // This keeps TAGE enabled even after failures (needs time to learn)
                    if (tage_confidence[idx_exe_T0] > 2'b10)
                        tage_confidence[idx_exe_T0] <= tage_confidence[idx_exe_T0] - 1'b1;
                end else begin
                    // TAGE succeeded -> maximize confidence
                    tage_confidence[idx_exe_T0] <= 2'b11;
                end
            end else begin
                // Bimodal (T0) was used (either no match or low confidence)
                if (branch_misprediction_i) begin
                    // Bimodal failed -> strongly increase confidence to try TAGE
                    tage_confidence[idx_exe_T0] <= 2'b11;
                end
                // Note: If Bimodal succeeded, keep confidence unchanged
                // Don't penalize TAGE just because Bimodal worked once
            end
        end
    end
end

`else
// =============================================================================
// Original Bimodal Predictor
// =============================================================================

// two-bit saturating counter
reg  [1 : 0]            branch_likelihood[ENTRY_NUM-1 : 0];



integer idx;

always @(posedge clk_i)
begin
    if (rst_i)
    begin
        for (idx = 0; idx < ENTRY_NUM; idx = idx + 1)
            branch_likelihood[idx] <= 2'b0;
    end
    else if (stall_i)
    begin
        for (idx = 0; idx < ENTRY_NUM; idx = idx + 1)
            branch_likelihood[idx] <= branch_likelihood[idx];
    end
    else
    begin
        if (we) // Execute the branch instruction for the first time.
        begin
            branch_likelihood[write_addr] <= {branch_taken_i, branch_taken_i};
        end
        else if (exe_is_branch_i)
        begin
            case (branch_likelihood[write_addr])
                2'b00:  // strongly not taken
                    if (branch_taken_i)
                        branch_likelihood[write_addr] <= 2'b01;
                    else
                        branch_likelihood[write_addr] <= 2'b00;
                2'b01:  // weakly not taken
                    if (branch_taken_i)
                        branch_likelihood[write_addr] <= 2'b11;
                    else
                        branch_likelihood[write_addr] <= 2'b00;
                2'b10:  // weakly taken
                    if (branch_taken_i)
                        branch_likelihood[write_addr] <= 2'b11;
                    else
                        branch_likelihood[write_addr] <= 2'b00;
                2'b11:  // strongly taken
                    if (branch_taken_i)
                        branch_likelihood[write_addr] <= 2'b11;
                    else
                        branch_likelihood[write_addr] <= 2'b10;
            endcase
        end
    end
end
`endif // USE_TAGE

// ===========================================================================
//  Common signals for both predictors
//
assign read_addr = pc_i[NBITS+1 : 2];
assign write_addr = dec_pc_i[NBITS+1 : 2];

`ifdef USE_TAGE
// TAGE uses BHT only for target address storage, not for hit detection
assign we = ~stall_i & (is_cond_branch_i | is_jal_i);
`else
// "we" is enabled to add a new entry to the BHT table when
// the decoded branch instruction is not in the BHT.
assign we = ~stall_i & (is_cond_branch_i | is_jal_i) & !BHT_hit;
`endif

// ===========================================================================
//  Branch History Table (BHT). Here, we use a direct-mapping cache table to
//  store branch history. Each entry of the table contains two fields:
//  the branch_target_addr and the PC of the branch instruction (as the tag).
//
distri_ram #(.ENTRY_NUM(ENTRY_NUM), .XLEN(XLEN*2))
BPU_BHT(
    .clk_i(clk_i),
    .we_i(we),                  // Write-enabled when the instruction at the Decode
                                //   is a branch and has never been executed before.
    .write_addr_i(write_addr),  // Direct-mapping index for the branch at Decode.
    .read_addr_i(read_addr),    // Direct-mapping Index for the next PC to be fetched.

    .data_i({branch_target_addr_i, dec_pc_i}), // Input is not used when 'we' is 0.
    .data_o({branch_target_addr_o, branch_inst_tag})
);

// Delay the BHT hit flag at the Fetch stage for two clock cycles (plus stalls)
// such that it can be reused at the Execute stage for BHT update operation.
always @ (posedge clk_i)
begin
    if (rst_i) begin
        BHT_hit_ff <= 1'b0;
        BHT_hit <= 1'b0;
`ifdef USE_TAGE
        bht_valid <= {ENTRY_NUM{1'b0}};
`endif
    end
    else if (!stall_i) begin
        BHT_hit_ff <= branch_hit_o;
        BHT_hit <= BHT_hit_ff;
`ifdef USE_TAGE        
        // Mark BHT entry as valid when written (TAGE only)
        if (we) begin
            bht_valid[write_addr] <= 1'b1;
        end
`endif
    end
end

// ===========================================================================
//  Outputs signals
//
`ifdef USE_TAGE
// TAGE: Use bht_valid to avoid false hits during cold start
assign branch_hit_o = (branch_inst_tag == pc_i) & bht_valid[read_addr];
assign branch_decision_o = tage_prediction;
assign tage_provider_o = provider_sel_r;  // Output which table was used (at execute stage)
`else
// Bimodal: Original behavior without bht_valid
assign branch_hit_o = (branch_inst_tag == pc_i);
assign branch_decision_o = branch_likelihood[read_addr][1];
assign tage_provider_o = 3'd0;  // Always 0 for Bimodal
`endif

endmodule
