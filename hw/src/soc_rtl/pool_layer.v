// ============================================================================
// Pooling Layer Module - Buffered Average Pooling with FSM
// MMIO Addresses (Buffered Mode):
//   0xC450_0000: Set in_width[5:0], in_depth[11:6] and trigger start
//   0xC450_0004: Write input image data
//   0xC450_0008: Read output image data
//   0xC450_000C: Read status (0 = done/idle, 1 = busy)
// ============================================================================
module pool_layer
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
// Buffered Pooling FSM States
// ============================================================================
reg [2:0] S, S_NEXT;
localparam S_IDLE       = 3'd0;
localparam S_INIT       = 3'd1;
localparam S_LOAD_IMG_I = 3'd2;
localparam S_ADD        = 3'd3;
localparam S_MUL        = 3'd4;
localparam S_STORE      = 3'd5;

// ============================================================================
// BRAM Buffers for Buffered Mode
// ============================================================================
// Input image buffer: 24*24*3 = 1728 (use 2048)
(* ram_style = "block" *) reg [31:0] img_data_i [0:2047];
reg [15:0] img_cnt_idx_i;
reg [15:0] img_size_i;
reg img_written_i;

// img_data_i read port signals
reg [15:0] img_i_raddr;
reg [31:0] img_i_rdata;

// Output image buffer: 4*4*32 = 512 (use 512)
(* ram_style = "block" *) reg [31:0] img_data_o [0:511];
reg [15:0] img_size_o;
reg [15:0] img_cnt_idx_o;
reg [15:0] oimg_init_cnt_idx;

// img_data_o write port signals
reg img_o_wen;
reg [15:0] img_o_waddr;
reg [31:0] img_o_wdata;

// img_data_o read port signals
reg [15:0] img_o_raddr;
reg [31:0] img_o_rdata;

// ============================================================================
// Pooling Parameters
// ============================================================================
reg [5:0] in_width;     // Input width (e.g., 14, 28)
reg [5:0] in_depth;     // Input depth (channels)
wire [5:0] out_width = in_width >> 1;  // Output width = in_width / 2
wire [15:0] in_plane_size = in_width * in_width;
wire [15:0] out_plane_size = out_width * out_width;

// ============================================================================
// Loop Counters for 2x2 Average Pooling
// ============================================================================
reg [15:0] out_idx;           // Current output index
reg [5:0]  channel_idx;       // Current channel
reg [5:0]  out_y, out_x;      // Output (x, y) position
reg [1:0]  inner_cnt;         // Inner 2x2 counter (0-3)

// Calculate input indices for 2x2 pooling window
wire [5:0] in_y = out_y << 1;  // in_y = out_y * 2
wire [5:0] in_x = out_x << 1;  // in_x = out_x * 2
wire [15:0] base_idx = channel_idx * in_plane_size + in_y * in_width + in_x;

// 2x2 window indices
wire [15:0] idx_00 = base_idx;                    // (in_x, in_y)
wire [15:0] idx_01 = base_idx + 1;                // (in_x+1, in_y)
wire [15:0] idx_10 = base_idx + in_width;         // (in_x, in_y+1)
wire [15:0] idx_11 = base_idx + in_width + 1;     // (in_x+1, in_y+1)

// Current input index based on inner_cnt
wire [15:0] cur_img_idx = (inner_cnt == 2'd0) ? idx_00 :
                          (inner_cnt == 2'd1) ? idx_01 :
                          (inner_cnt == 2'd2) ? idx_10 : idx_11;

// ============================================================================
// ADD IP for accumulation (4 values sum)
// ============================================================================
reg [31:0] pool_add_feed_dataA;
reg [31:0] pool_add_feed_dataB;
reg pool_add_data_valid;
wire pool_add_result_valid;
wire [31:0] pool_add_result_data;
reg [31:0] pool_add_result_reg;

reg [31:0] accum_value;  // Accumulated sum
reg [1:0]  add_stage;    // 0: v0+v1, 1: v2+v3, 2: sum1+sum2
reg [31:0] sum_01;       // v0 + v1
reg [31:0] sum_23;       // v2 + v3
reg [31:0] pool_values [0:3];  // Store 4 values for pooling

// ============================================================================
// MUL IP for scaling (* 0.25)
// ============================================================================
reg [31:0] pool_mul_feed_dataA;
reg [31:0] pool_mul_feed_dataB;
reg pool_mul_data_valid;
wire pool_mul_result_valid;
wire [31:0] pool_mul_result_data;
reg [31:0] pool_mul_result_reg;

// Scale factor 0.25 in IEEE 754 float
localparam [31:0] SCALE_FACTOR = 32'h3E800000;  // 0.25

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
always @(*) begin
    S_NEXT = S;
    case (S)
        S_IDLE: begin
            if (en_i && we_i && addr_i == 32'hC450_0000) begin
                S_NEXT = S_INIT;
            end
        end
        S_INIT: begin
            if (oimg_init_cnt_idx == img_size_o) begin
                S_NEXT = S_LOAD_IMG_I;
            end
        end
        S_LOAD_IMG_I: begin
            if (img_cnt_idx_i == img_size_i) begin
                S_NEXT = S_ADD;
            end
        end
        S_ADD: begin
            // Wait for 3 ADD operations: v0+v1, v2+v3, (v0+v1)+(v2+v3)
            if (add_stage == 2'd3 && pool_add_result_valid) begin
                S_NEXT = S_MUL;
            end
        end
        S_MUL: begin
            if (pool_mul_result_valid) begin
                S_NEXT = S_STORE;
            end
        end
        S_STORE: begin
            if (out_idx >= img_size_o) begin
                S_NEXT = S_IDLE;
            end
            else begin
                S_NEXT = S_ADD;
            end
        end
    endcase
end

// ============================================================================
// Parameter Loading and Initialization
// ============================================================================
always @(posedge clk_i) begin
    if (rst_i) begin
        in_width <= 0;
        in_depth <= 0;
        img_size_i <= 0;
        img_size_o <= 0;
        oimg_init_cnt_idx <= 0;
    end
    else if (en_i && we_i && addr_i == 32'hC450_0000) begin
        // data_i[5:0] = in_width, data_i[11:6] = in_depth
        in_width <= data_i[5:0];
        in_depth <= data_i[11:6];
        img_size_i <= data_i[5:0] * data_i[5:0] * data_i[11:6];
        img_size_o <= (data_i[5:0] >> 1) * (data_i[5:0] >> 1) * data_i[11:6];
        oimg_init_cnt_idx <= 0;
    end
    else if (S == S_INIT) begin
        // Write handled by img_o_wen control
        oimg_init_cnt_idx <= oimg_init_cnt_idx + 1;
    end
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
        if (en_i && we_i && addr_i == 32'hC450_0004 && !img_written_i) begin
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
    if (S == S_LOAD_IMG_I && en_i && we_i && addr_i == 32'hC450_0004 && !img_written_i) begin
        img_data_i[img_cnt_idx_i] <= data_i;
    end
end

// img_data_i - Read Port Only
always @(posedge clk_i) begin
    img_i_rdata <= img_data_i[img_i_raddr];
end

// img_data_i read address control and pool_values loading
// Use a sub-FSM to read 4 values sequentially during ADD state
reg [2:0] read_stage;  // 0: idle, 1-4: reading v0-v3, 5: ready

always @(posedge clk_i) begin
    if (rst_i) begin
        img_i_raddr <= 0;
        read_stage <= 0;
    end
    else if (S == S_IDLE) begin
        img_i_raddr <= idx_00;  // Pre-load first address
        read_stage <= 0;
    end
    else if (S == S_LOAD_IMG_I) begin
        img_i_raddr <= idx_00;  // Keep pointing to first value
        read_stage <= 0;
    end
    else if (S == S_ADD) begin
        case (read_stage)
            3'd0: begin img_i_raddr <= idx_01; read_stage <= 1; end  // Start, read v0
            3'd1: begin img_i_raddr <= idx_10; read_stage <= 2; end  // Read v1
            3'd2: begin img_i_raddr <= idx_11; read_stage <= 3; end  // Read v2
            3'd3: begin read_stage <= 4; end                         // Read v3
            3'd4: begin read_stage <= 5; end                         // All ready
            default: read_stage <= read_stage;
        endcase
    end
    else if (S == S_STORE) begin
        // Prepare for next pooling window
        img_i_raddr <= next_base_idx;
        read_stage <= 0;
    end
end

// Capture read data into pool_values (1 cycle delay from address)
always @(posedge clk_i) begin
    if (rst_i) begin
        pool_values[0] <= 0;
        pool_values[1] <= 0;
        pool_values[2] <= 0;
        pool_values[3] <= 0;
    end
    else if (S == S_ADD) begin
        case (read_stage)
            3'd1: pool_values[0] <= img_i_rdata;  // v0 ready (from idx_00)
            3'd2: pool_values[1] <= img_i_rdata;  // v1 ready (from idx_01)
            3'd3: pool_values[2] <= img_i_rdata;  // v2 ready (from idx_10)
            3'd4: pool_values[3] <= img_i_rdata;  // v3 ready (from idx_11)
            default: ;
        endcase
    end
end

// img_data_o read address control
always @(posedge clk_i) begin
    if (rst_i) begin
        img_o_raddr <= 0;
    end
    else if (en_i && !we_i && addr_i == 32'hC450_000C) begin
        img_o_raddr <= 0;  // Reset on status read
    end
    else if (en_i && !we_i && addr_i == 32'hC450_0008) begin
        img_o_raddr <= (img_cnt_idx_o == img_size_o - 1) ? 0 : img_cnt_idx_o + 1;
    end
end

// ============================================================================
// Pooling Computation: ADD (accumulation) and MUL (scaling)
// ============================================================================
// Next position calculation for preloading
wire [5:0] next_out_x = (out_x == out_width - 1) ? 6'd0 : out_x + 1;
wire [5:0] next_out_y = (out_x == out_width - 1) ? 
                         ((out_y == out_width - 1) ? 6'd0 : out_y + 1) : out_y;
wire [5:0] next_channel = (out_x == out_width - 1 && out_y == out_width - 1) ? 
                          channel_idx + 1 : channel_idx;
wire [5:0] next_in_y = next_out_y << 1;
wire [5:0] next_in_x = next_out_x << 1;
wire [15:0] next_base_idx = next_channel * in_plane_size + next_in_y * in_width + next_in_x;

always @(posedge clk_i) begin
    if (rst_i) begin
        channel_idx <= 0;
        out_y <= 0;
        out_x <= 0;
        inner_cnt <= 0;
        add_stage <= 0;
        accum_value <= 0;
        sum_01 <= 0;
        sum_23 <= 0;
        pool_add_data_valid <= 0;
        pool_add_feed_dataA <= 0;
        pool_add_feed_dataB <= 0;
        pool_mul_data_valid <= 0;
        pool_mul_feed_dataA <= 0;
        pool_mul_feed_dataB <= 0;
    end
    else begin
        // Clear valid signals
        if (pool_add_data_valid) pool_add_data_valid <= 0;
        if (pool_mul_data_valid) pool_mul_data_valid <= 0;
        
        if (S == S_IDLE) begin
            channel_idx <= 0;
            out_y <= 0;
            out_x <= 0;
            inner_cnt <= 0;
            add_stage <= 0;
        end
        else if (S == S_LOAD_IMG_I && S_NEXT == S_ADD) begin
            // Entering ADD state, pool_values loaded via read port pipeline
            add_stage <= 0;
        end
        else if (S == S_ADD) begin
            // Wait until all 4 values are loaded (read_stage == 5)
            if (read_stage == 3'd5) begin
                case (add_stage)
                    2'd0: begin
                        // v0 + v1
                        pool_add_feed_dataA <= pool_values[0];
                        pool_add_feed_dataB <= pool_values[1];
                        pool_add_data_valid <= 1;
                        add_stage <= 2'd1;
                    end
                    2'd1: begin
                        if (pool_add_result_valid) begin
                            sum_01 <= pool_add_result_data;
                            // v2 + v3
                            pool_add_feed_dataA <= pool_values[2];
                            pool_add_feed_dataB <= pool_values[3];
                            pool_add_data_valid <= 1;
                            add_stage <= 2'd2;
                        end
                    end
                    2'd2: begin
                        if (pool_add_result_valid) begin
                            sum_23 <= pool_add_result_data;
                            // sum_01 + sum_23
                            pool_add_feed_dataA <= sum_01;
                            pool_add_feed_dataB <= pool_add_result_data;
                            pool_add_data_valid <= 1;
                            add_stage <= 2'd3;  // Wait for final result
                        end
                    end
                    2'd3: begin
                        if (pool_add_result_valid) begin
                            accum_value <= pool_add_result_data;
                        end
                    end
                endcase
            end
        end
        else if (S == S_MUL) begin
            if (!pool_mul_data_valid && !pool_mul_result_valid) begin
                pool_mul_feed_dataA <= accum_value;
                pool_mul_feed_dataB <= SCALE_FACTOR;  // 0.25
                pool_mul_data_valid <= 1;
            end
        end
        else if (S == S_STORE && S_NEXT == S_ADD) begin
            // pool_values loaded via read port pipeline
            add_stage <= 0;
            
            // Update position counters
            out_x <= next_out_x;
            out_y <= next_out_y;
            channel_idx <= next_channel;
        end
    end
end

// ============================================================================
// Output Storage - Index Management
// ============================================================================
always @(posedge clk_i) begin
    if (rst_i) begin
        out_idx <= 0;
    end
    else if (S == S_IDLE) begin
        out_idx <= 0;
    end
    else if (S == S_MUL && pool_mul_result_valid) begin
        out_idx <= out_idx + 1;
    end
end

// img_data_o - Write Port Only (Simple Dual-Port RAM)
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
    else if (S == S_MUL && pool_mul_result_valid) begin
        img_o_wen <= 1;
        img_o_waddr <= out_idx;
        img_o_wdata <= pool_mul_result_data;
    end
    else begin
        img_o_wen <= 0;
    end
end

// ============================================================================
// Output Logic - Read results
// ============================================================================
reg send_flag;

always @(posedge clk_i) begin
    if (rst_i) begin
        pool_add_result_reg <= 0;
        pool_mul_result_reg <= 0;
        data_o <= 0;
        img_cnt_idx_o <= 0;
        send_flag <= 0;
    end
    else begin
        // Capture results
        if (pool_add_result_valid && S == S_IDLE) begin
            pool_add_result_reg <= pool_add_result_data;
        end
        if (pool_mul_result_valid && S == S_IDLE) begin
            pool_mul_result_reg <= pool_mul_result_data;
        end

        // // Legacy: Read ADD result at 0x20
        // if (en_i && !we_i && addr_i == 32'hC400_0020) begin
        //     data_o <= pool_add_result_reg;
        // end
        
        // // Legacy: Read MUL result at 0x2C
        // else if (en_i && !we_i && addr_i == 32'hC400_002C) begin
        //     data_o <= pool_mul_result_reg;
        // end
        
        // Buffered: Read output image at 0xC450_0008
        else if (en_i && !we_i && addr_i == 32'hC450_0008 && send_flag == 0) begin
            data_o <= img_o_rdata;  // Use read port data
            img_cnt_idx_o <= (img_cnt_idx_o == img_size_o - 1) ? 0 : img_cnt_idx_o + 1;
            send_flag <= 1;
        end
        
        // Buffered: Read status at 0xC450_000C
        else if (en_i && !we_i && addr_i == 32'hC450_000C) begin
            data_o <= (S == S_IDLE) ? 32'd0 : 32'd1;
            img_cnt_idx_o <= 0;
        end
        
        if (send_flag) send_flag <= 0;
    end
end

// Ready signal: block during INIT state
assign ready_o = ~(S == S_INIT);

// ============================================================================
// Floating-Point ADD IP
// ============================================================================
floating_point_add ip_pool_add (
    .aclk(clk_i),
    
    .s_axis_a_tvalid(pool_add_data_valid),
    .s_axis_a_tdata(pool_add_feed_dataA),
    
    .s_axis_b_tvalid(pool_add_data_valid),
    .s_axis_b_tdata(pool_add_feed_dataB),
    
    .m_axis_result_tvalid(pool_add_result_valid),
    .m_axis_result_tdata(pool_add_result_data)
);

// ============================================================================
// Floating-Point MUL IP
// ============================================================================
floating_point_mul ip_pool_mul (
    .aclk(clk_i),
    
    .s_axis_a_tvalid(pool_mul_data_valid),
    .s_axis_a_tdata(pool_mul_feed_dataA),
    
    .s_axis_b_tvalid(pool_mul_data_valid),
    .s_axis_b_tdata(pool_mul_feed_dataB),
    
    .m_axis_result_tvalid(pool_mul_result_valid),
    .m_axis_result_tdata(pool_mul_result_data)
);

endmodule


