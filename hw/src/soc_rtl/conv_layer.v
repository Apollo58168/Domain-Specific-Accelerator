// ============================================================================
// Conv Layer Module - Convolutional Layer with buffered Conv3D operation
// Separate weight buffers for Conv1 and Conv2 to support weight preloading
// MMIO Addresses:
//   Conv1 Weight: 0xC410_0000 (full mode total), 0xC410_0004 (data), 0xC410_0008 (input-only)
//   Conv2 Weight: 0xC410_0010 (full mode total), 0xC410_0014 (data), 0xC410_0018 (input-only)
//   Input:   0xC420_0000 (size),  0xC420_0004 (data)
//   Output:  0xC430_0000 (trigger init), 0xC430_0004 (read data), 0xC430_0008 (read with ReLU)
//   Params:  0xC460_0000 (trigger/status), 0xC460_0004-0x10 (in_w, out_w, in_d, out_d)
// ============================================================================
module conv_layer
#( parameter XLEN = 32 )
(
    input                   clk_i,
    input                   rst_i,

    // MMIO interface
    input                   en_i,
    input                   we_i,
    input [XLEN-1 : 0]      addr_i,
    input [XLEN-1 : 0]      data_i,
    output reg [XLEN-1 : 0] data_o,
    output                  ready_o
);

// ============================================================================
// Conv3D Buffered Mode - BRAM Buffers with Separate Conv1/Conv2 Weight Buffers
// ============================================================================
// Conv1 Weight buffer: 1*5*5*3 = 75 (use 128)
(* ram_style = "block" *) reg [31:0] conv1_weight_data [0:127];
reg conv1_weight_preloaded;

// Conv2 Weight buffer: 3*5*5*12 = 900 (use 1024)
(* ram_style = "block" *) reg [31:0] conv2_weight_data [0:1023];
reg conv2_weight_preloaded;

// Current layer selection (0 = Conv1, 1 = Conv2)
reg current_conv_layer;

// Input-only mode flag (skip weight loading)
reg input_only_mode;

// Weight loading counters
reg [15:0] weight_cnt_idx;
reg [15:0] total_weight;
reg weight_written;

// Input image buffer: max 28x28x1 = 784 (use 1024)
(* ram_style = "block" *) reg [31:0] img_data_i [0:1023];
reg [15:0] img_cnt_idx_i;
reg [15:0] img_size_i;
reg img_written_i;

// Output image buffer: max 24x24x3 = 1728 (use 2048)
(* ram_style = "block" *) reg [31:0] img_data_o [0:2047];
reg [15:0] img_size_o;
reg [15:0] img_cnt_idx_o;
reg [15:0] out_img_idx;
reg [15:0] oimg_init_cnt_idx;

// Conv3D FSM (same as data_feeder.v)
reg [2:0] S, S_NEXT;
localparam S_IDLE       = 3'd0;
localparam S_INIT       = 3'd1;
localparam S_LOAD_WEIGHT = 3'd2;
localparam S_LOAD_IMG_I = 3'd3;
localparam S_CNT        = 3'd4;
localparam S_STORE      = 3'd5;

// Conv3D parameters (same as data_feeder.v)
reg [15:0] in_depth_idx;
reg [15:0] in_depth;
reg [15:0] in_width;
reg [15:0] out_depth_idx;
reg [15:0] out_depth;
reg [15:0] out_width;

// Loop counting variables (same as data_feeder.v)
wire [15:0] const1 = in_width - 5;  // weight width = 5
wire [15:0] const2 = in_width - out_width;
reg [15:0] iter_x, iter_y, wx, widx;
reg [15:0] cur_depth_idx, inner_loop_cnt;
reg [15:0] img_idx;

// Address calculation (same as data_feeder.v)
wire [15:0] dot_weight_idx = (cur_depth_idx * 25) + inner_loop_cnt;
wire [15:0] dot_img_idx = img_idx + widx;

// Flags (same as data_feeder.v)
wire finish_cur_round = conv_dot_data_valid && (inner_loop_cnt % 25 == 0);
wire next_weight = (inner_loop_cnt % 25 == 24) && (iter_x == out_width - 1 && iter_y == out_width - 1) && conv_dot_result_valid;
wire change_depth_o = (iter_x == 0 && iter_y == out_width) && (out_depth_idx != out_depth) && oimg_add_result_valid;

// Inner dot product FMA for conv3d (same as data_feeder.v)
reg conv_dot_data_valid;
wire conv_dot_result_valid;
reg [31:0] conv_dot_feed_dataA, conv_dot_feed_dataB, conv_dot_feed_dataC;
wire [31:0] conv_dot_result_data;

// Output accumulation ADD (same as data_feeder.v)
reg oimg_add_data_valid;
wire oimg_add_result_valid;
reg [31:0] oimg_add_feed_dataA, oimg_add_feed_dataB;
wire [31:0] oimg_add_result_data;

// ============================================================================
// Input Logic - Non-buffered Conv FMA inputs
// ============================================================================
// always @(posedge clk_i) begin
//     if (rst_i) begin
//         conv_fma_data_valid <= 0;
//         conv_fma_feed_dataA <= 0;
//         conv_fma_feed_dataB <= 0;
//         conv_fma_feed_dataC <= 0;
//     end
//     else if (en_i) begin
//         // Conv FMA inputs (0x0C = A, 0x10 = B, 0x14 write = C and trigger) - non-buffered mode
//         if (we_i && addr_i == 32'hC400_000C) begin
//             conv_fma_feed_dataA <= data_i;
//         end
//         else if (we_i && addr_i == 32'hC400_0010) begin
//             conv_fma_feed_dataB <= data_i;
//         end
//         else if (we_i && addr_i == 32'hC400_0014) begin
//             // Write to 0x14 provides C value and triggers FMA
//             conv_fma_feed_dataC <= data_i;
//             conv_fma_data_valid <= 1;
//         end
//         else if (!we_i) begin
//             conv_fma_data_valid <= 0;
//         end
//     end
//     else begin
//         if (conv_fma_data_valid) conv_fma_data_valid <= 0;
//     end
// end

// ============================================================================
// Conv3D FSM - State Register (same as data_feeder.v)
// ============================================================================
always @(posedge clk_i) begin
    if (rst_i) begin
        S <= S_IDLE;
    end
    else begin
        S <= S_NEXT;
    end
end

// FSM Next State Logic
// Trigger detection wires for Conv1 and Conv2
wire conv1_full_trigger = en_i && we_i && addr_i == 32'hC410_0000;
wire conv1_input_only_trigger = en_i && we_i && addr_i == 32'hC410_0008 && conv1_weight_preloaded;
wire conv2_full_trigger = en_i && we_i && addr_i == 32'hC410_0010;
wire conv2_input_only_trigger = en_i && we_i && addr_i == 32'hC410_0018 && conv2_weight_preloaded;

// Combined trigger for starting FSM
wire any_trigger = conv1_full_trigger || conv1_input_only_trigger ||
                   conv2_full_trigger || conv2_input_only_trigger;

always @(*) begin
    S_NEXT = S;
    case (S)
        S_IDLE: begin
            if (any_trigger) begin
                S_NEXT = S_INIT;
            end
        end
        S_INIT: begin
            if (oimg_init_cnt_idx == img_size_o) begin
                // Skip weight loading if input_only_mode
                S_NEXT = input_only_mode ? S_LOAD_IMG_I : S_LOAD_WEIGHT;
            end
        end
        S_LOAD_WEIGHT: begin
            S_NEXT = (weight_cnt_idx == total_weight) ? S_LOAD_IMG_I : S;
        end
        S_LOAD_IMG_I: begin
            S_NEXT = (img_cnt_idx_i == img_size_i) ? S_CNT : S;
        end
        S_CNT: begin
            S_NEXT = (finish_cur_round) ? S_STORE : S;
        end
        S_STORE: begin
            if (oimg_add_result_valid) begin
                S_NEXT = (out_depth_idx == out_depth && in_depth_idx == 0) ? S_IDLE : S_CNT;
            end
        end
    endcase
end

// ============================================================================
// Weight Loading - Separate Conv1/Conv2 Buffers with Preload Support
// ============================================================================
// Weight write address detection
wire conv1_weight_write = en_i && we_i && addr_i == 32'hC410_0004 && !weight_written;
wire conv2_weight_write = en_i && we_i && addr_i == 32'hC410_0014 && !weight_written;

always @(posedge clk_i) begin
    if (rst_i) begin
        weight_cnt_idx <= 0;
        total_weight <= 0;
        weight_written <= 0;
        conv1_weight_preloaded <= 0;
        conv2_weight_preloaded <= 0;
        current_conv_layer <= 0;
        input_only_mode <= 0;
    end
    else if (conv1_full_trigger) begin
        // Conv1 full mode: load new weights
        total_weight <= data_i;
        weight_cnt_idx <= 0;
        weight_written <= 0;
        current_conv_layer <= 0;  // Conv1
        input_only_mode <= 0;
        conv1_weight_preloaded <= 0;  // Clear preload flag
    end
    else if (conv1_input_only_trigger) begin
        // Conv1 input-only mode: reuse weights
        total_weight <= data_i;  // Still need total for computation
        weight_cnt_idx <= 0;
        weight_written <= 0;
        current_conv_layer <= 0;  // Conv1
        input_only_mode <= 1;  // Skip weight loading
    end
    else if (conv2_full_trigger) begin
        // Conv2 full mode: load new weights
        total_weight <= data_i;
        weight_cnt_idx <= 0;
        weight_written <= 0;
        current_conv_layer <= 1;  // Conv2
        input_only_mode <= 0;
        conv2_weight_preloaded <= 0;  // Clear preload flag
    end
    else if (conv2_input_only_trigger) begin
        // Conv2 input-only mode: reuse weights
        total_weight <= data_i;
        weight_cnt_idx <= 0;
        weight_written <= 0;
        current_conv_layer <= 1;  // Conv2
        input_only_mode <= 1;  // Skip weight loading
    end
    else if (S == S_LOAD_WEIGHT) begin
        if ((current_conv_layer == 0 && conv1_weight_write) ||
            (current_conv_layer == 1 && conv2_weight_write)) begin
            weight_cnt_idx <= weight_cnt_idx + 1;
            weight_written <= 1;
        end
        else if (!we_i) begin
            weight_written <= 0;
        end
    end
    else if (S == S_STORE && S_NEXT == S_IDLE && !input_only_mode) begin
        // Mark weights as preloaded after full mode completes
        if (current_conv_layer == 0)
            conv1_weight_preloaded <= 1;
        else
            conv2_weight_preloaded <= 1;
    end
end

// conv1_weight_data - Write Port Only
always @(posedge clk_i) begin
    if (S == S_LOAD_WEIGHT && current_conv_layer == 0 && conv1_weight_write) begin
        conv1_weight_data[weight_cnt_idx] <= data_i;
    end
end

// conv2_weight_data - Write Port Only
always @(posedge clk_i) begin
    if (S == S_LOAD_WEIGHT && current_conv_layer == 1 && conv2_weight_write) begin
        conv2_weight_data[weight_cnt_idx] <= data_i;
    end
end

// weight_rdata - Combinational read from appropriate buffer based on current_conv_layer
wire [31:0] weight_rdata_comb = (current_conv_layer == 0) ? 
                                 conv1_weight_data[dot_weight_idx] : 
                                 conv2_weight_data[dot_weight_idx];

// ============================================================================
// Input Image Loading
// ============================================================================
always @(posedge clk_i) begin
    if (rst_i) begin
        img_cnt_idx_i <= 0;
        img_size_i <= 0;
        img_written_i <= 0;
    end
    else if (en_i && we_i && addr_i == 32'hC420_0000) begin
        img_size_i <= data_i;
        img_cnt_idx_i <= 0;
        img_written_i <= 0;
    end
    else if (S == S_LOAD_IMG_I) begin
        if (we_i && addr_i == 32'hC420_0004 && !img_written_i) begin
            img_data_i[img_cnt_idx_i] <= data_i;
            img_cnt_idx_i <= img_cnt_idx_i + 1;
            img_written_i <= 1;
        end
        else if (!we_i) begin
            img_written_i <= 0;
        end
    end
end

// ============================================================================
// Output Image Buffer & Accumulation
// ============================================================================
always @(posedge clk_i) begin
    if (rst_i) begin
        img_size_o <= 0;
        out_img_idx <= 0;
        oimg_add_feed_dataA <= 0;
        oimg_add_feed_dataB <= 0;
        oimg_add_data_valid <= 0;
        oimg_init_cnt_idx <= 0;
    end
    else if (any_trigger) begin
        // Trigger from Conv1/Conv2 full or input-only mode
        // img_size_o comes from 0xC430_0000 write (before this trigger)
        oimg_init_cnt_idx <= 0;
        out_img_idx <= 0;
    end
    else if (en_i && we_i && addr_i == 32'hC430_0000) begin
        // Set output size (this must happen BEFORE the conv trigger)
        img_size_o <= data_i;
    end
    else if (S == S_INIT) begin
        img_data_o[oimg_init_cnt_idx] <= 0;
        oimg_init_cnt_idx <= oimg_init_cnt_idx + 1;
    end
    else if (change_depth_o) begin
        out_img_idx <= out_depth_idx * out_width * out_width;
    end
    else if (S == S_STORE) begin
        if (conv_dot_result_valid) begin
            oimg_add_feed_dataA <= img_data_o[out_img_idx];
            oimg_add_feed_dataB <= conv_dot_result_data;
            oimg_add_data_valid <= 1;
        end
        else if (oimg_add_result_valid) begin
            img_data_o[out_img_idx] <= oimg_add_result_data;
            oimg_add_data_valid <= 0;
            out_img_idx <= out_img_idx + 1;
        end
    end
end

// ============================================================================
// Parameter Loading
// ============================================================================
always @(posedge clk_i) begin
    if (rst_i) begin
        in_width <= 0;
        out_width <= 0;
        in_depth <= 0;
        out_depth <= 0;
        iter_x <= 0;
        iter_y <= 0;
    end
    else if (en_i && we_i && addr_i == 32'hC460_0004) begin
        in_width <= data_i;
    end
    else if (en_i && we_i && addr_i == 32'hC460_0008) begin
        out_width <= data_i;
    end
    else if (en_i && we_i && addr_i == 32'hC460_000C) begin
        in_depth <= data_i;
    end
    else if (en_i && we_i && addr_i == 32'hC460_0010) begin
        out_depth <= data_i;
    end
    else if (S == S_IDLE || change_depth_o) begin
        iter_x <= 0;
        iter_y <= 0;
    end
    else if (finish_cur_round && (iter_x != 0 || iter_y != out_width)) begin
        if (iter_x == out_width - 1) begin
            iter_x <= 0;
            iter_y <= iter_y + 1;
        end
        else begin
            iter_x <= iter_x + 1;
        end
    end
end

// ============================================================================
// Loop Counting & FMA Control
// ============================================================================
always @(posedge clk_i) begin
    if (rst_i) begin
        conv_dot_data_valid <= 0;
        conv_dot_feed_dataA <= 0;
        conv_dot_feed_dataB <= 0;
        conv_dot_feed_dataC <= 0;
        
        in_depth_idx <= 0;
        out_depth_idx <= 0;
        cur_depth_idx <= 0;
        
        inner_loop_cnt <= 0;
        wx <= 0;
        widx <= 0;
        img_idx <= 0;
    end
    else begin
        if (S == S_IDLE) begin
            in_depth_idx <= 0;
            out_depth_idx <= 0;
            cur_depth_idx <= 0;
            inner_loop_cnt <= 0;
        end
        else if ((in_depth_idx == in_depth) && (out_depth_idx < out_depth)) begin
            in_depth_idx <= 0;
            out_depth_idx <= out_depth_idx + 1;
        end
        
        // Trigger first computation
        if (en_i && we_i && addr_i == 32'hC460_0000) begin
            conv_dot_feed_dataA <= weight_rdata_comb;
            conv_dot_feed_dataB <= img_data_i[dot_img_idx];
            conv_dot_feed_dataC <= 0;
            conv_dot_data_valid <= 1;
            
            inner_loop_cnt <= 1;
            widx <= 1;
            wx <= 1;
            img_idx <= 0;
            cur_depth_idx <= 0;
        end
        // Continue computation
        else if ((S_NEXT == S_CNT && conv_dot_result_valid) || (S == S_STORE && S_NEXT == S_CNT) || change_depth_o) begin
            conv_dot_feed_dataA <= weight_rdata_comb;
            conv_dot_feed_dataB <= img_data_i[dot_img_idx];
            conv_dot_feed_dataC <= (S == S_STORE || change_depth_o) ? 32'd0 : conv_dot_result_data;
            conv_dot_data_valid <= 1;
            
            inner_loop_cnt <= inner_loop_cnt + 1;
            wx <= (next_weight) ? 1 : (wx == 4) ? 0 : wx + 1;
            widx <= (next_weight) ? 1 : (wx == 4) ? widx + const1 + 1 : widx + 1;
            
            if (next_weight) begin
                img_idx <= (in_depth_idx == in_depth - 1) ? (0 - const2 - 1) : img_idx + widx - const2;
                in_depth_idx <= in_depth_idx + 1;
                cur_depth_idx <= cur_depth_idx + 1;
            end
        end
        
        if (finish_cur_round) begin
            img_idx <= (iter_x == out_width - 1) ? img_idx + const2 + 1 : img_idx + 1;
            inner_loop_cnt <= 0;
            widx <= 0;
            wx <= 0;
        end
        
        if (conv_dot_data_valid) begin
            conv_dot_data_valid <= 0;
        end
    end
end

// ============================================================================
// Output Logic - Read results
// ============================================================================
reg send_flag;
reg apply_relu;  // Flag to enable ReLU on output

// ReLU function: if negative (bit 31 = 1), output 0; else output original value
wire [31:0] img_data_raw = img_data_o[img_cnt_idx_o];
wire [31:0] img_data_relu = img_data_raw[31] ? 32'h0 : img_data_raw;  // Simple ReLU

always @(posedge clk_i) begin
    if (rst_i) begin
        // conv_fma_result_reg <= 0;
        data_o <= 0;
        img_cnt_idx_o <= 0;
        send_flag <= 0;
        apply_relu <= 0;
    end
    else begin
        // Capture non-buffered conv FMA result
        // if (conv_fma_result_valid) begin
        //     conv_fma_result_reg <= conv_fma_result_data;
        // end

        // // Read Conv FMA result at 0x14 (non-buffered mode)
        // if (en_i && !we_i && addr_i == 32'hC400_0014) begin
        //     data_o <= conv_fma_result_reg;
        // end
        
        // ========== Conv3D Buffered Mode Reads ==========
        // Read output image data at 0xC430_0004 (normal)
        if (en_i && !we_i && addr_i == 32'hC430_0004 && send_flag == 0) begin
            data_o <= apply_relu ? img_data_relu : img_data_raw;
            img_cnt_idx_o <= img_cnt_idx_o + 1;
            send_flag <= (img_cnt_idx_o == img_size_o) ? send_flag : 1;
        end
        
        // Read output image data at 0xC430_0008 with ReLU applied
        else if (en_i && !we_i && addr_i == 32'hC430_0008 && send_flag == 0) begin
            data_o <= img_data_relu;  // Always apply ReLU
            img_cnt_idx_o <= img_cnt_idx_o + 1;
            send_flag <= (img_cnt_idx_o == img_size_o) ? send_flag : 1;
        end
        
        // Read conv3d status at 0xC460_0000 (0 = done/idle, 1 = busy)
        else if (en_i && !we_i && addr_i == 32'hC460_0000) begin
            data_o <= (S == S_IDLE) ? 32'd0 : 32'd1;
            img_cnt_idx_o <= 0;
        end
        
        // Set ReLU mode at 0xC460_0014 (write 1 to enable, 0 to disable)
        else if (en_i && we_i && addr_i == 32'hC460_0014) begin
            apply_relu <= data_i[0];
        end
        
        if (send_flag) begin
            send_flag <= 0;
        end
    end
end

// Ready signal: block during INIT state (clearing output buffer)
assign ready_o = ~(S == S_INIT);

// ============================================================================
// Floating-Point FMA IP for Conv layer (non-buffered): computes A * B + C
// ============================================================================
// floating_point_0 ip_conv_fma (
//     .aclk(clk_i),
    
//     .s_axis_a_tvalid(conv_fma_data_valid),
//     .s_axis_a_tdata(conv_fma_feed_dataA),
    
//     .s_axis_b_tvalid(conv_fma_data_valid),
//     .s_axis_b_tdata(conv_fma_feed_dataB),
    
//     .s_axis_c_tvalid(conv_fma_data_valid),
//     .s_axis_c_tdata(conv_fma_feed_dataC),
    
//     .m_axis_result_tvalid(conv_fma_result_valid),
//     .m_axis_result_tdata(conv_fma_result_data)
// );

// ============================================================================
// Floating-Point FMA IP for Conv3D Buffered Mode: computes A * B + C
// ============================================================================
floating_point_0 ip_conv3d_inner_dot (
    .aclk(clk_i),
    
    .s_axis_a_tvalid(conv_dot_data_valid),
    .s_axis_a_tdata(conv_dot_feed_dataA),
    
    .s_axis_b_tvalid(conv_dot_data_valid),
    .s_axis_b_tdata(conv_dot_feed_dataB),
    
    .s_axis_c_tvalid(conv_dot_data_valid),
    .s_axis_c_tdata(conv_dot_feed_dataC),
    
    .m_axis_result_tvalid(conv_dot_result_valid),
    .m_axis_result_tdata(conv_dot_result_data)
);

// ============================================================================
// Floating-Point ADD IP for Output Accumulation: computes A + B
// ============================================================================
floating_point_add ip_conv_img_o (
    .aclk(clk_i),
    
    .s_axis_a_tvalid(oimg_add_data_valid),
    .s_axis_a_tdata(oimg_add_feed_dataA),
    
    .s_axis_b_tvalid(oimg_add_data_valid),
    .s_axis_b_tdata(oimg_add_feed_dataB),
    
    .m_axis_result_tvalid(oimg_add_result_valid),
    .m_axis_result_tdata(oimg_add_result_data)
);

endmodule
