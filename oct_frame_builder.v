`timescale 1ns / 1ps

module oct_frame_builder #(
    parameter PREAMBLE_LEN   = 8,
    parameter RAW_HEADER_LEN = 2,  // Scaled down for text simulation
    parameter PAYLOAD_LEN    = 16,
    parameter CRC32_LEN      = 8,
    parameter FEC_PARITY_LEN = 8,
    parameter [31:0] HEADER_VALUE = 32'h00000003
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start_frame,
    input  wire        payload_bit_in,
    
    output reg         busy,
    output reg         frame_done,
    output reg         frame_valid,
    output wire        frame_data
);

    // FSM States
    localparam IDLE     = 3'd0, PREAMBLE = 3'd1, HEADER   = 3'd2;
    localparam PAYLOAD  = 3'd3, PAY_CRC  = 3'd4, PAY_FEC  = 3'd5;

    // Header Derived Parameters (CRC16 is hardcoded to 16 bits structurally)
    localparam HDR_CRC_LEN        = 16; 
    localparam TOTAL_HDR_IN       = RAW_HEADER_LEN + HDR_CRC_LEN;
    localparam ENCODED_HEADER_LEN = TOTAL_HDR_IN * 6; // Rate 1/6 expansion

    reg [2:0]  state_q, state_d;
    reg [15:0] bit_cnt_q, bit_cnt_d;
    reg [15:0] unencoded_hdr_cnt_q, unencoded_hdr_cnt_d;

    // Datapath & LFSRs
    reg  [63:0] preamble_shift_q;
    reg  [14:0] scrambler_lfsr_q;
    reg         raw_stream_bit;
    
    // Sub-module connections
    wire crc16_out, fec1_ready, fec1_valid, fec1_out;
    wire crc32_out, fec2_ready, fec2_valid, fec2_out;
  
    // --- Dynamic Header Bit Selection ---
    wire current_header_bit = HEADER_VALUE[RAW_HEADER_LEN - 1 - unencoded_hdr_cnt_q];

    // --- Sub-Module: Header CRC-16 ---
    crc16_serial u_crc16 (
        .clk(clk), .rst_n(rst_n),
        .start_calc(state_q == IDLE && start_frame),
        .calc_en(state_q == HEADER && unencoded_hdr_cnt_q < RAW_HEADER_LEN && fec1_ready),
        .shift_out(state_q == HEADER && unencoded_hdr_cnt_q >= RAW_HEADER_LEN && fec1_ready),
        .data_in(current_header_bit), // <--- Use the wire here
        .crc_out(crc16_out)
    );
 
  
    // --- Sub-Module: Header FEC-1 (Convolutional Encoder) ---
    wire fec1_in_data  = (unencoded_hdr_cnt_q < RAW_HEADER_LEN) ? current_header_bit : crc16_out;
    wire fec1_in_valid = (state_q == HEADER) && (unencoded_hdr_cnt_q < TOTAL_HDR_IN);

    header_fec1_encoder u_fec1 (
        .clk(clk), .rst_n(rst_n),
        .s_axis_tvalid(fec1_in_valid),
        .s_axis_tdata(fec1_in_data),
        .s_axis_tready(fec1_ready),
        .m_axis_tvalid(fec1_valid),
        .m_axis_tdata(fec1_out),
        .m_axis_tready(1'b1) // Top level always ready to transmit in HEADER state
    );

    // --- Sub-Module: Payload CRC-32 ---
    crc32_serial u_crc32 (
        .clk(clk), .rst_n(rst_n),
        .start_calc(state_q == IDLE && start_frame),
        .calc_en(state_q == PAYLOAD),
        .shift_out(state_q == PAY_CRC),
        .data_in(payload_bit_in),
        .crc_out(crc32_out)
    );

    // --- Sub-Module: Payload LDPC (FEC-2) Behavioral ---
    payload_ldpc_behavioral #(
        .INFO_BLOCK_SIZE(PAYLOAD_LEN + CRC32_LEN)
    ) u_fec2 (
        .clk(clk), .rst_n(rst_n),
        .pl_rate(4'd4),
        .s_axis_tvalid((state_q == PAYLOAD) || (state_q == PAY_CRC)),
        .s_axis_tdata((state_q == PAYLOAD) ? payload_bit_in : crc32_out),
        .s_axis_tready(fec2_ready),
        .m_axis_tvalid(fec2_valid),
        .m_axis_tdata(fec2_out),
        .m_axis_tready(state_q == PAY_FEC)
    );

    // --- Control Path: Top Level Counters ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_q <= IDLE; bit_cnt_q <= 16'd0; unencoded_hdr_cnt_q <= 16'd0;
        end else begin
            state_q <= state_d; bit_cnt_q <= bit_cnt_d; unencoded_hdr_cnt_q <= unencoded_hdr_cnt_d;
        end
    end

    // --- Control Path: FSM Logic ---
    always @(*) begin
        state_d = state_q; bit_cnt_d = bit_cnt_q; unencoded_hdr_cnt_d = unencoded_hdr_cnt_q;
        busy = 1'b1; frame_valid = 1'b0; frame_done = 1'b0;

        // Feed counter logic for FEC-1
        if (state_q == IDLE) unencoded_hdr_cnt_d = 0;
        else if (state_q == HEADER && fec1_in_valid && fec1_ready) begin
            unencoded_hdr_cnt_d = unencoded_hdr_cnt_q + 1'b1;
        end

        case (state_q)
            IDLE: begin
                busy = 1'b0;
                if (start_frame) begin state_d = PREAMBLE; bit_cnt_d = 0; busy = 1'b1; end
            end
            PREAMBLE: begin
                frame_valid = 1'b1;
                if (bit_cnt_q == PREAMBLE_LEN - 1) begin state_d = HEADER; bit_cnt_d = 0; end 
                else bit_cnt_d = bit_cnt_q + 1'b1;
            end
            HEADER: begin
                // Only count output bits when FEC-1 actually spits out valid encoded data
                if (fec1_valid) begin
                    frame_valid = 1'b1;
                    if (bit_cnt_q == ENCODED_HEADER_LEN - 1) begin state_d = PAYLOAD; bit_cnt_d = 0; end 
                    else bit_cnt_d = bit_cnt_q + 1'b1;
                end
            end
            PAYLOAD: begin
                frame_valid = 1'b1;
                if (bit_cnt_q == PAYLOAD_LEN - 1) begin state_d = PAY_CRC; bit_cnt_d = 0; end 
                else bit_cnt_d = bit_cnt_q + 1'b1;
            end
            PAY_CRC: begin
                frame_valid = 1'b1;
                if (bit_cnt_q == CRC32_LEN - 1) begin state_d = PAY_FEC; bit_cnt_d = 0; end 
                else bit_cnt_d = bit_cnt_q + 1'b1;
            end
            PAY_FEC: begin
                // Only count output bits when FEC-2 is valid
                if (fec2_valid) begin
                    frame_valid = 1'b1;
                    if (bit_cnt_q == FEC_PARITY_LEN - 1) begin state_d = IDLE; frame_done = 1'b1; end 
                    else bit_cnt_d = bit_cnt_q + 1'b1;
                end
            end
            default: state_d = IDLE;
        endcase
    end

    // --- Datapath: Preamble & Scrambler ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) preamble_shift_q <= 64'h53225b1d0d73df03;
        else if (state_q == IDLE && start_frame) preamble_shift_q <= 64'h53225b1d0d73df03;
        else if (state_q == PREAMBLE) preamble_shift_q <= {preamble_shift_q[62:0], 1'b0};
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) scrambler_lfsr_q <= 15'b000011011011100;
        else if (state_q == IDLE && start_frame) scrambler_lfsr_q <= 15'b000011011011100;
        else if (state_q != IDLE && state_q != PREAMBLE && frame_valid) 
            scrambler_lfsr_q <= {scrambler_lfsr_q[13:0], scrambler_lfsr_q[14] ^ scrambler_lfsr_q[13]};
    end

    // --- Datapath Mux ---
    always @(*) begin
        case (state_q)
            PREAMBLE: raw_stream_bit = preamble_shift_q[63];
            HEADER:   raw_stream_bit = fec1_out; // Now pulled straight from Convolutional Encoder!
            PAYLOAD:  raw_stream_bit = payload_bit_in;
            PAY_CRC:  raw_stream_bit = crc32_out;
            PAY_FEC:  raw_stream_bit = fec2_out;
            default:  raw_stream_bit = 1'b0;
        endcase
    end

    assign frame_data = (state_q == PREAMBLE) ? raw_stream_bit : (raw_stream_bit ^ scrambler_lfsr_q[14]);

endmodule