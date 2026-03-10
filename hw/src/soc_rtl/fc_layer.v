// ============================================================================
// FC Layer Module - Fully Connected Layer with Buffered Mode
// Separate weight buffers for FC1 and FC2 to support weight preloading
// MMIO Addresses (Buffered Mode):
//   0xC470_0000: FC1 Full mode trigger, params: in[15:0], out[31:16]
//   0xC470_0004: FC1 Write weight data
//   0xC470_0008: Write input data (shared by FC1/FC2)
//   0xC470_000C: Read output data
//   0xC470_0010: Read status (0 = done/idle, 1 = busy)
//   0xC470_0014: FC1 Write bias data
//   0xC470_0018: FC1 Input-only mode (reuse preloaded weights)
//   0xC470_0020: FC2 Full mode trigger
//   0xC470_0024: FC2 Write weight data
//   0xC470_0028: FC2 Write bias data
//   0xC470_002C: FC2 Input-only mode
// ============================================================================
module fc_layer
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
// Buffered FC FSM States (8 states)
// ============================================================================
reg [2:0] S, S_NEXT;
localparam S_IDLE       = 3'd0;
localparam S_INIT       = 3'd1;
localparam S_LOAD_WEIGHT = 3'd2;
localparam S_LOAD_BIAS  = 3'd3;  // New dedicated bias loading state
localparam S_LOAD_IMG_I = 3'd4;
localparam S_MUL        = 3'd5;
localparam S_ADD        = 3'd6;
localparam S_STORE      = 3'd7;

// ============================================================================
// BRAM Buffers for Buffered Mode - Separate FC1 and FC2
// ============================================================================
// FC1 Weight buffer: 192 * 30 = 5760 (use 8192)
(* ram_style = "block" *) reg [31:0] fc1_weight_data [0:8191];
reg fc1_weight_preloaded;
reg [31:0] fc1_bias_data [0:31];

// FC2 Weight buffer: 30 * 10 = 300 (use 512)
(* ram_style = "block" *) reg [31:0] fc2_weight_data [0:511];
reg fc2_weight_preloaded;
reg [31:0] fc2_bias_data [0:15];

// Current layer selection (0 = FC1, 1 = FC2)
reg current_layer;

// Weight loading counters
reg [15:0] weight_cnt_idx;
reg [15:0] total_weight;
reg weight_written;

// Weight read port signals
reg [15:0] weight_raddr;
reg [31:0] weight_rdata;  // Selected weight data from FC1 or FC2 buffer

// Input image buffer: max 192 (use 256)
(* ram_style = "block" *) reg [31:0] img_data_i [0:255];
reg [15:0] img_cnt_idx_i;
reg [15:0] img_size_i;
reg img_written_i;

// Input read port signals
reg [15:0] img_i_raddr;
reg [31:0] img_i_rdata;

// Output buffer: max 10 (use 32)
(* ram_style = "block" *) reg [31:0] img_data_o [0:31];
reg [15:0] img_size_o;
reg [15:0] img_cnt_idx_o;
reg [15:0] oimg_init_cnt_idx;

// Output write port signals
reg img_o_wen;
reg [15:0] img_o_waddr;
reg [31:0] img_o_wdata;

// Output read port signals
reg [15:0] img_o_raddr;
reg [31:0] img_o_rdata;

// Bias loading counters
reg [15:0] bias_cnt_idx;
reg bias_written;

// Input-only mode flag
reg input_only_mode;

// ============================================================================
// FC Parameters (16-bit to support in_dim up to 65535)
// ============================================================================
reg [15:0] in_size;      // Input dimension (e.g., 588)
reg [15:0] out_size;     // Output dimension (e.g., 30 or 10)

// ============================================================================
// Loop Counters for FC computation
// ============================================================================
reg [15:0] out_idx;           // Current output neuron index
reg [15:0] in_idx;            // Current input index for dot product
reg [31:0] accum_value;       // Accumulated sum for current output

// ============================================================================
// FMA IP for FC: A*B + C
// ============================================================================
reg [31:0] fc_fma_feed_dataA;
reg [31:0] fc_fma_feed_dataB;
reg [31:0] fc_fma_feed_dataC;
reg fc_fma_data_valid;
wire fc_fma_result_valid;
wire [31:0] fc_fma_result_data;
reg [31:0] fc_fma_result_reg;

// ADD IP for bias addition
reg [31:0] fc_add_feed_dataA;
reg [31:0] fc_add_feed_dataB;
reg fc_add_data_valid;
wire fc_add_result_valid;
wire [31:0] fc_add_result_data;

// ============================================================================
// FSM State Register
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
// Trigger detection wires
wire fc1_full_trigger = en_i && we_i && addr_i == 32'hC470_0000;
wire fc1_input_only_trigger = en_i && we_i && addr_i == 32'hC470_0018 && fc1_weight_preloaded;
wire fc2_full_trigger = en_i && we_i && addr_i == 32'hC470_0020;
wire fc2_input_only_trigger = en_i && we_i && addr_i == 32'hC470_002C && fc2_weight_preloaded;

always @(*) begin
    S_NEXT = S;
    case (S)
        S_IDLE: begin
            if (fc1_full_trigger || fc1_input_only_trigger ||
                fc2_full_trigger || fc2_input_only_trigger) begin
                S_NEXT = S_INIT;
            end
        end
        S_INIT: begin
            if (oimg_init_cnt_idx >= img_size_o) begin
                // Skip weight/bias loading if input_only_mode
                S_NEXT = input_only_mode ? S_LOAD_IMG_I : S_LOAD_WEIGHT;
            end
        end
        S_LOAD_WEIGHT: begin
            if (weight_cnt_idx >= total_weight) begin
                S_NEXT = S_LOAD_BIAS;
            end
        end
        S_LOAD_BIAS: begin
            if (bias_cnt_idx >= img_size_o) begin
                S_NEXT = S_LOAD_IMG_I;
            end
        end
        S_LOAD_IMG_I: begin
            if (img_cnt_idx_i >= img_size_i) begin
                S_NEXT = S_MUL;
            end
        end
        S_MUL: begin
            // Wait for FMA result of last multiplication
            // in_idx is incremented after FMA result, so check in_idx >= img_size_i
            if (in_idx >= img_size_i && read_stage == 3) begin
                S_NEXT = S_ADD;
            end
        end
        S_ADD: begin
            // Wait for bias addition result
            if (fc_add_result_valid) begin
                S_NEXT = S_STORE;
            end
        end
        S_STORE: begin
            if (out_idx >= img_size_o) begin
                S_NEXT = S_IDLE;
            end
            else begin
                S_NEXT = S_MUL;
            end
        end
    endcase
end

// ============================================================================
// Parameter Loading and Initialization
// ============================================================================
always @(posedge clk_i) begin
    if (rst_i) begin
        in_size <= 0;
        out_size <= 0;
        img_size_i <= 0;
        img_size_o <= 0;
        total_weight <= 0;
        oimg_init_cnt_idx <= 0;
        fc1_weight_preloaded <= 0;
        fc2_weight_preloaded <= 0;
        input_only_mode <= 0;
        current_layer <= 0;  // 0 = FC1, 1 = FC2
    end
    else if (fc1_full_trigger) begin
        // FC1 full mode: load new weights for FC1
        in_size <= data_i[15:0];
        out_size <= data_i[31:16];
        img_size_i <= data_i[15:0];
        img_size_o <= data_i[31:16];
        total_weight <= data_i[15:0] * data_i[31:16];
        oimg_init_cnt_idx <= 0;
        input_only_mode <= 0;
        current_layer <= 0;  // FC1
        fc1_weight_preloaded <= 0;  // Clear preloaded flag
    end
    else if (fc1_input_only_trigger) begin
        // FC1 input-only mode: reuse existing FC1 weights
        in_size <= data_i[15:0];
        out_size <= data_i[31:16];
        img_size_i <= data_i[15:0];
        img_size_o <= data_i[31:16];
        total_weight <= data_i[15:0] * data_i[31:16];
        oimg_init_cnt_idx <= 0;
        input_only_mode <= 1;
        current_layer <= 0;  // FC1
    end
    else if (fc2_full_trigger) begin
        // FC2 full mode: load new weights for FC2
        in_size <= data_i[15:0];
        out_size <= data_i[31:16];
        img_size_i <= data_i[15:0];
        img_size_o <= data_i[31:16];
        total_weight <= data_i[15:0] * data_i[31:16];
        oimg_init_cnt_idx <= 0;
        input_only_mode <= 0;
        current_layer <= 1;  // FC2
        fc2_weight_preloaded <= 0;  // Clear preloaded flag
    end
    else if (fc2_input_only_trigger) begin
        // FC2 input-only mode: reuse existing FC2 weights
        in_size <= data_i[15:0];
        out_size <= data_i[31:16];
        img_size_i <= data_i[15:0];
        img_size_o <= data_i[31:16];
        total_weight <= data_i[15:0] * data_i[31:16];
        oimg_init_cnt_idx <= 0;
        input_only_mode <= 1;
        current_layer <= 1;  // FC2
    end
    else if (S == S_INIT) begin
        oimg_init_cnt_idx <= oimg_init_cnt_idx + 1;
    end
    else if (S == S_STORE && S_NEXT == S_IDLE && !input_only_mode) begin
        // Mark weights as preloaded after full mode completes
        if (current_layer == 0)
            fc1_weight_preloaded <= 1;
        else
            fc2_weight_preloaded <= 1;
    end
end

// ============================================================================
// Weight Loading - Write Port (Simple Dual-Port RAM)
// ============================================================================
// Weight write address for current layer
wire fc1_weight_write = en_i && we_i && addr_i == 32'hC470_0004 && !weight_written;
wire fc2_weight_write = en_i && we_i && addr_i == 32'hC470_0024 && !weight_written;

always @(posedge clk_i) begin
    if (rst_i) begin
        weight_cnt_idx <= 0;
        weight_written <= 0;
    end
    else if (S == S_IDLE) begin
        weight_cnt_idx <= 0;
        weight_written <= 0;
    end
    else if (S == S_LOAD_WEIGHT) begin
        if ((current_layer == 0 && fc1_weight_write) ||
            (current_layer == 1 && fc2_weight_write)) begin
            weight_cnt_idx <= weight_cnt_idx + 1;
            weight_written <= 1;
        end
        else if (!we_i) begin
            weight_written <= 0;
        end
    end
end

// fc1_weight_data - Write Port Only
always @(posedge clk_i) begin
    if (S == S_LOAD_WEIGHT && current_layer == 0 && fc1_weight_write) begin
        fc1_weight_data[weight_cnt_idx] <= data_i;
    end
end

// fc2_weight_data - Write Port Only
always @(posedge clk_i) begin
    if (S == S_LOAD_WEIGHT && current_layer == 1 && fc2_weight_write) begin
        fc2_weight_data[weight_cnt_idx] <= data_i;
    end
end

// weight_rdata - Read from appropriate buffer based on current_layer
always @(posedge clk_i) begin
    if (current_layer == 0)
        weight_rdata <= fc1_weight_data[weight_raddr];
    else
        weight_rdata <= fc2_weight_data[weight_raddr];
end

// ============================================================================
// Input Image Loading - Write Port (Simple Dual-Port RAM)
// ============================================================================
always @(posedge clk_i) begin
    if (rst_i) begin
        img_cnt_idx_i <= 0;
        img_written_i <= 0;
    end
    else if (S == S_IDLE) begin
        img_cnt_idx_i <= 0;
        img_written_i <= 0;
    end
    else if (S == S_LOAD_IMG_I) begin
        if (en_i && we_i && addr_i == 32'hC470_0008 && !img_written_i) begin
            img_cnt_idx_i <= img_cnt_idx_i + 1;
            img_written_i <= 1;
        end
        else if (!we_i) begin
            img_written_i <= 0;
        end
    end
end

// img_data_i - Write Port Only
always @(posedge clk_i) begin
    if (S == S_LOAD_IMG_I && en_i && we_i && addr_i == 32'hC470_0008 && !img_written_i) begin
        img_data_i[img_cnt_idx_i] <= data_i;
    end
end

// img_data_i - Read Port Only
always @(posedge clk_i) begin
    img_i_rdata <= img_data_i[img_i_raddr];
end

// ============================================================================
// Bias Loading - Dedicated S_LOAD_BIAS state
// ============================================================================
// Bias write address for current layer
wire fc1_bias_write = en_i && we_i && addr_i == 32'hC470_0014 && !bias_written;
wire fc2_bias_write = en_i && we_i && addr_i == 32'hC470_0028 && !bias_written;

always @(posedge clk_i) begin
    if (rst_i) begin
        bias_cnt_idx <= 0;
        bias_written <= 0;
    end
    else if (S == S_IDLE) begin
        bias_cnt_idx <= 0;
        bias_written <= 0;
    end
    else if (S == S_LOAD_BIAS) begin
        if ((current_layer == 0 && fc1_bias_write) ||
            (current_layer == 1 && fc2_bias_write)) begin
            bias_cnt_idx <= bias_cnt_idx + 1;
            bias_written <= 1;
        end
        else if (!we_i) begin
            bias_written <= 0;
        end
    end
end

// fc1_bias_data - Write Port Only
always @(posedge clk_i) begin
    if (S == S_LOAD_BIAS && current_layer == 0 && fc1_bias_write) begin
        fc1_bias_data[bias_cnt_idx] <= data_i;
    end
end

// fc2_bias_data - Write Port Only
always @(posedge clk_i) begin
    if (S == S_LOAD_BIAS && current_layer == 1 && fc2_bias_write) begin
        fc2_bias_data[bias_cnt_idx] <= data_i;
    end
end

// ============================================================================
// FC Computation: MUL-accumulate using FMA, then ADD bias
// ============================================================================
// Read pipeline stage
// 0: idle, 1: addr set, 2: data ready & send FMA, 3: waiting FMA result
reg [2:0] read_stage;

always @(posedge clk_i) begin
    if (rst_i) begin
        weight_raddr <= 0;
        img_i_raddr <= 0;
        read_stage <= 0;
    end
    else if (S == S_IDLE || S == S_LOAD_IMG_I) begin
        weight_raddr <= 0;
        img_i_raddr <= 0;
        read_stage <= 0;
    end
    else if (S == S_MUL) begin
        if (read_stage == 0) begin
            // Set addresses for first read
            weight_raddr <= out_idx * img_size_i + in_idx;
            img_i_raddr <= in_idx;
            read_stage <= 1;
        end
        else if (read_stage == 1) begin
            // Data will be ready next cycle
            read_stage <= 2;
        end
        else if (read_stage == 2) begin
            // FMA will be sent this cycle, move to waiting state
            read_stage <= 3;
        end
        else if (read_stage == 3 && fc_fma_result_valid) begin
            // FMA result received, advance to next input or finish
            if (in_idx < img_size_i - 1) begin
                weight_raddr <= out_idx * img_size_i + in_idx + 1;
                img_i_raddr <= in_idx + 1;
                read_stage <= 1;
            end
            // else: stay at read_stage=3, will transition to S_ADD
        end
    end
    else if (S == S_STORE && S_NEXT == S_MUL) begin
        // Prepare for next output neuron
        weight_raddr <= (out_idx + 1) * img_size_i;
        img_i_raddr <= 0;
        read_stage <= 1;
    end
end

// FMA computation control
always @(posedge clk_i) begin
    if (rst_i) begin
        out_idx <= 0;
        in_idx <= 0;
        accum_value <= 0;
        fc_fma_data_valid <= 0;
        fc_fma_feed_dataA <= 0;
        fc_fma_feed_dataB <= 0;
        fc_fma_feed_dataC <= 0;
        fc_add_data_valid <= 0;
        fc_add_feed_dataA <= 0;
        fc_add_feed_dataB <= 0;
    end
    else begin
        // Clear valid signals (pulse)
        if (fc_fma_data_valid) fc_fma_data_valid <= 0;
        if (fc_add_data_valid) fc_add_data_valid <= 0;
        
        if (S == S_IDLE) begin
            out_idx <= 0;
            in_idx <= 0;
            accum_value <= 0;
        end
        else if (S == S_MUL) begin
            // Send FMA only when read_stage==2 (data ready, before moving to stage 3)
            if (read_stage == 2) begin
                fc_fma_feed_dataA <= weight_rdata;
                fc_fma_feed_dataB <= img_i_rdata;
                fc_fma_feed_dataC <= accum_value;
                fc_fma_data_valid <= 1;
            end
            
            // Capture FMA result and advance index
            if (read_stage == 3 && fc_fma_result_valid) begin
                accum_value <= fc_fma_result_data;
                in_idx <= in_idx + 1;
            end
        end
        else if (S == S_ADD) begin
            // Add bias - only send once, select correct bias buffer
            if (!fc_add_data_valid && !fc_add_result_valid) begin
                fc_add_feed_dataA <= accum_value;
                fc_add_feed_dataB <= (current_layer == 0) ? fc1_bias_data[out_idx] : fc2_bias_data[out_idx];
                fc_add_data_valid <= 1;
            end
        end
        else if (S == S_STORE) begin
            // Prepare for next output neuron
            if (S_NEXT == S_MUL) begin
                out_idx <= out_idx + 1;
                in_idx <= 0;
                accum_value <= 0;
            end
            else if (S_NEXT == S_IDLE) begin
                out_idx <= out_idx + 1;
            end
        end
    end
end

// ============================================================================
// Output Storage - Write Port (Simple Dual-Port RAM)
// ============================================================================
// img_data_o - Write Port Only
always @(posedge clk_i) begin
    if (img_o_wen) begin
        img_data_o[img_o_waddr] <= img_o_wdata;
    end
end

// img_data_o - Read Port Only
always @(posedge clk_i) begin
    img_o_rdata <= img_data_o[img_o_raddr];
end

// img_data_o write control signals
always @(posedge clk_i) begin
    if (rst_i) begin
        img_o_wen <= 0;
        img_o_waddr <= 0;
        img_o_wdata <= 0;
    end
    else if (S == S_INIT) begin
        img_o_wen <= 1;
        img_o_waddr <= oimg_init_cnt_idx;
        img_o_wdata <= 32'd0;
    end
    else if (S == S_ADD && fc_add_result_valid) begin
        img_o_wen <= 1;
        img_o_waddr <= out_idx;
        img_o_wdata <= fc_add_result_data;
    end
    else begin
        img_o_wen <= 0;
    end
end

// img_data_o read address control - prefetch for proper timing
always @(posedge clk_i) begin
    if (rst_i) begin
        img_o_raddr <= 0;
    end
    else if (S == S_STORE && S_NEXT == S_IDLE) begin
        // Pre-fetch first output when computation done
        img_o_raddr <= 0;
    end
    else if (en_i && !we_i && addr_i == 32'hC470_000C) begin
        // Advance to next address for next read
        img_o_raddr <= img_o_raddr + 1;
    end
end

// ============================================================================
// Output Logic - Read results
// ============================================================================
always @(posedge clk_i) begin
    if (rst_i) begin
        fc_fma_result_reg <= 0;
        data_o <= 0;
        img_cnt_idx_o <= 0;
    end
    else begin
        // Capture FMA result for legacy mode
        if (fc_fma_result_valid && S == S_IDLE) begin
            fc_fma_result_reg <= fc_fma_result_data;
        end

        // Legacy: Read FMA result at 0x08
        // if (en_i && !we_i && addr_i == 32'hC400_0008) begin
        //     data_o <= fc_fma_result_reg;
        // end
        
        // Buffered: Read output data at 0xC470_000C
        else if (en_i && !we_i && addr_i == 32'hC470_000C) begin
            data_o <= img_o_rdata;
            img_cnt_idx_o <= img_cnt_idx_o + 1;
        end
        
        // Buffered: Read status at 0xC470_0010
        else if (en_i && !we_i && addr_i == 32'hC470_0010) begin
            data_o <= (S == S_IDLE) ? 32'd0 : 32'd1;
            img_cnt_idx_o <= 0;
        end
    end
end

// Ready signal: block during INIT state
assign ready_o = ~(S == S_INIT);

// ============================================================================
// Floating-Point FMA IP for FC layer: computes A * B + C
// ============================================================================
floating_point_0 ip_fc_fma (
    .aclk(clk_i),
    
    .s_axis_a_tvalid(fc_fma_data_valid),
    .s_axis_a_tdata(fc_fma_feed_dataA),
    
    .s_axis_b_tvalid(fc_fma_data_valid),
    .s_axis_b_tdata(fc_fma_feed_dataB),
    
    .s_axis_c_tvalid(fc_fma_data_valid),
    .s_axis_c_tdata(fc_fma_feed_dataC),
    
    .m_axis_result_tvalid(fc_fma_result_valid),
    .m_axis_result_tdata(fc_fma_result_data)
);

// ============================================================================
// Floating-Point ADD IP for bias addition: computes A + B
// ============================================================================
floating_point_add ip_fc_add (
    .aclk(clk_i),
    
    .s_axis_a_tvalid(fc_add_data_valid),
    .s_axis_a_tdata(fc_add_feed_dataA),
    
    .s_axis_b_tvalid(fc_add_data_valid),
    .s_axis_b_tdata(fc_add_feed_dataB),
    
    .m_axis_result_tvalid(fc_add_result_valid),
    .m_axis_result_tdata(fc_add_result_data)
);

endmodule
