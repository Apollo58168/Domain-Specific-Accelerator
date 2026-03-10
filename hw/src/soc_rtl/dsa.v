// ============================================================================
// DSA Top Module - Connects FC, Conv, and Pooling layers
// ============================================================================
module dsa
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
    output                  data_ready_o
);

// ============================================================================
// Address Decoding - Select which layer module to enable
// ============================================================================
// FC Layer:      0xC470_xxxx (buffered mode)
// Conv Layer:    0xC410_xxxx (weight), 0xC420_xxxx (input), 0xC430_xxxx (output)
//                0xC460_xxxx (params)
// Pooling Layer: 0xC450_xxxx (buffered mode)
// Profiler:      0xC400_0030 - 0xC400_0040

wire fc_sel = (addr_i[31:16] == 16'hC470);

wire pool_sel = (addr_i[31:16] == 16'hC450);

wire conv_sel = (addr_i[31:16] == 16'hC410) ||
                (addr_i[31:16] == 16'hC420) ||
                (addr_i[31:16] == 16'hC430) ||
                (addr_i[31:16] == 16'hC460);

wire profiler_sel = (addr_i[31:8] == 24'hC400_00) && 
                    (addr_i[7:0] >= 8'h30) && (addr_i[7:0] <= 8'h40);

// ============================================================================
// FC Layer Instance
// ============================================================================
wire [XLEN-1:0] fc_data_o;
wire fc_ready;

fc_layer #(.XLEN(XLEN)) u_fc_layer (
    .clk_i(clk_i),
    .rst_i(rst_i),
    .en_i(en_i && fc_sel),
    .we_i(we_i),
    .addr_i(addr_i),
    .data_i(data_i),
    .data_o(fc_data_o),
    .ready_o(fc_ready)
);

// ============================================================================
// Pooling Layer Instance
// ============================================================================
wire [XLEN-1:0] pool_data_o;
wire pool_ready;

pool_layer #(.XLEN(XLEN)) u_pool_layer (
    .clk_i(clk_i),
    .rst_i(rst_i),
    .en_i(en_i && pool_sel),
    .we_i(we_i),
    .addr_i(addr_i),
    .data_i(data_i),
    .data_o(pool_data_o),
    .ready_o(pool_ready)
);

// ============================================================================
// Conv Layer Instance
// ============================================================================
wire [XLEN-1:0] conv_data_o;
wire conv_ready;

conv_layer #(.XLEN(XLEN)) u_conv_layer (
    .clk_i(clk_i),
    .rst_i(rst_i),
    .en_i(en_i && conv_sel),
    .we_i(we_i),
    .addr_i(addr_i),
    .data_i(data_i),
    .data_o(conv_data_o),
    .ready_o(conv_ready)
);

// ============================================================================
// Output Multiplexer
// ============================================================================
always @(*) begin
    if (fc_sel)
        data_o = fc_data_o;
    else if (pool_sel)
        data_o = pool_data_o;
    else if (conv_sel)
        data_o = conv_data_o;
    else
        data_o = 32'd0;
end

// Ready signal multiplexer
assign data_ready_o = fc_sel ? fc_ready :
                      pool_sel ? pool_ready :
                      conv_sel ? conv_ready : 1'b1;

// ============================================================================
// Profiler (keep in top module for global visibility)
// ============================================================================
(* mark_debug = "true" *) reg [31:0] fc_layer_cycles;
(* mark_debug = "true" *) reg [31:0] conv_layer_cycles;
(* mark_debug = "true" *) reg [31:0] conv_copypad_cycles;
(* mark_debug = "true" *) reg [31:0] conv_compute_cycles;
(* mark_debug = "true" *) reg [31:0] pool_layer_cycles;

(* mark_debug = "true" *) reg fc_layer_active;
(* mark_debug = "true" *) reg conv_layer_active;
(* mark_debug = "true" *) reg conv_copypad_active;
(* mark_debug = "true" *) reg conv_compute_active;
(* mark_debug = "true" *) reg pool_layer_active;

always @(posedge clk_i) begin
    if (rst_i) begin
        fc_layer_active <= 0;
        conv_layer_active <= 0;
        conv_copypad_active <= 0;
        conv_compute_active <= 0;
        pool_layer_active <= 0;
    end
    else if (en_i && profiler_sel) begin
        if (we_i && addr_i == 32'hC400_0030) begin
            fc_layer_active <= data_i[0];
        end
        else if (we_i && addr_i == 32'hC400_0034) begin
            conv_layer_active <= data_i[0];
        end
        else if (we_i && addr_i == 32'hC400_0038) begin
            conv_copypad_active <= data_i[0];
        end
        else if (we_i && addr_i == 32'hC400_003C) begin
            conv_compute_active <= data_i[0];
        end
        else if (we_i && addr_i == 32'hC400_0040) begin
            pool_layer_active <= data_i[0];
        end
    end
end

always @(posedge clk_i) begin
    if (rst_i) begin
        fc_layer_cycles <= 0;
        conv_layer_cycles <= 0;
        conv_copypad_cycles <= 0;
        conv_compute_cycles <= 0;
        pool_layer_cycles <= 0;
    end
    else begin
        if (fc_layer_active)
            fc_layer_cycles <= fc_layer_cycles + 1;
        if (conv_layer_active)
            conv_layer_cycles <= conv_layer_cycles + 1;
        if (conv_copypad_active)
            conv_copypad_cycles <= conv_copypad_cycles + 1;
        if (conv_compute_active)
            conv_compute_cycles <= conv_compute_cycles + 1;
        if (pool_layer_active)
            pool_layer_cycles <= pool_layer_cycles + 1;
    end
end

endmodule
