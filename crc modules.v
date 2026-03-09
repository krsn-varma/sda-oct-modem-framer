module crc16_serial (
    input  wire        clk,
    input  wire        rst_n,
    
    // Control signals
    input  wire        start_calc, // Pulses high to initialize the register to 0
    input  wire        calc_en,    // High when header payload bits are flowing in
    input  wire        shift_out,  // High to shift out the final calculated 16-bit CRC
    
    // Data signals
    input  wire        data_in,    // Serial header bit coming in
    output wire        crc_out     // Serial CRC bit going out
);

    // CCITT X.25 Polynomial: x^16 + x^12 + x^5 + 1 -> 16'h1021
    localparam [15:0] POLY = 16'h1021;
    
    reg [15:0] lfsr_q;
    wire       feedback;

    // Feedback is the XOR of the incoming data bit and the MSB of the LFSR
    assign feedback = data_in ^ lfsr_q[15];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lfsr_q <= 16'd0;
        end else if (start_calc) begin
            // Initialize to zero at the start of each new calculation
            lfsr_q <= 16'd0; 
        end else if (calc_en) begin
            // Shift left and apply polynomial if feedback is 1
            lfsr_q[0]  <= feedback ? POLY[0]  : 1'b0;
            lfsr_q[1]  <= feedback ? lfsr_q[0]  ^ POLY[1]  : lfsr_q[0];
            lfsr_q[2]  <= feedback ? lfsr_q[1]  ^ POLY[2]  : lfsr_q[1];
            lfsr_q[3]  <= feedback ? lfsr_q[2]  ^ POLY[3]  : lfsr_q[2];
            lfsr_q[4]  <= feedback ? lfsr_q[3]  ^ POLY[4]  : lfsr_q[3];
            lfsr_q[5]  <= feedback ? lfsr_q[4]  ^ POLY[5]  : lfsr_q[4];
            lfsr_q[6]  <= feedback ? lfsr_q[5]  ^ POLY[6]  : lfsr_q[5];
            lfsr_q[7]  <= feedback ? lfsr_q[6]  ^ POLY[7]  : lfsr_q[6];
            lfsr_q[8]  <= feedback ? lfsr_q[7]  ^ POLY[8]  : lfsr_q[7];
            lfsr_q[9]  <= feedback ? lfsr_q[8]  ^ POLY[9]  : lfsr_q[8];
            lfsr_q[10] <= feedback ? lfsr_q[9]  ^ POLY[10] : lfsr_q[9];
            lfsr_q[11] <= feedback ? lfsr_q[10] ^ POLY[11] : lfsr_q[10];
            lfsr_q[12] <= feedback ? lfsr_q[11] ^ POLY[12] : lfsr_q[11];
            lfsr_q[13] <= feedback ? lfsr_q[12] ^ POLY[13] : lfsr_q[12];
            lfsr_q[14] <= feedback ? lfsr_q[13] ^ POLY[14] : lfsr_q[13];
            lfsr_q[15] <= feedback ? lfsr_q[14] ^ POLY[15] : lfsr_q[14];
        end else if (shift_out) begin
            // Clock out the calculated CRC bits (MSB first)
            lfsr_q <= {lfsr_q[14:0], 1'b0};
        end
    end

    // Output the MSB when shifting out
    assign crc_out = lfsr_q[15];

endmodule

module crc32_serial (
    input  wire        clk,
    input  wire        rst_n,
    
    // Control signals
    input  wire        start_calc, // Pulses high to initialize the register to 0
    input  wire        calc_en,    // High when payload bits are flowing in
    input  wire        shift_out,  // High when calculating is done and we shift out the CRC
    
    // Data signals
    input  wire        data_in,    // Serial payload bit coming in
    output wire        crc_out     // Serial CRC bit going out
);

    // IEEE 802.3 Polynomial: 0x04C11DB7
    localparam [31:0] POLY = 32'h04C11DB7;
    
    reg [31:0] lfsr_q;
    wire       feedback;

    // The feedback is the XOR of the incoming data bit and the MSB of the LFSR
    assign feedback = data_in ^ lfsr_q[31];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lfsr_q <= 32'd0;
        end else if (start_calc) begin
            // Initialize to zero at the start of each new calculation
            lfsr_q <= 32'd0; 
        end else if (calc_en) begin
            // Shift left and apply polynomial if feedback is 1
            lfsr_q[0]  <= feedback ? POLY[0]  : 1'b0;
            lfsr_q[1]  <= feedback ? lfsr_q[0]  ^ POLY[1]  : lfsr_q[0];
            lfsr_q[2]  <= feedback ? lfsr_q[1]  ^ POLY[2]  : lfsr_q[1];
            lfsr_q[3]  <= feedback ? lfsr_q[2]  ^ POLY[3]  : lfsr_q[2];
            lfsr_q[4]  <= feedback ? lfsr_q[3]  ^ POLY[4]  : lfsr_q[3];
            lfsr_q[5]  <= feedback ? lfsr_q[4]  ^ POLY[5]  : lfsr_q[4];
            lfsr_q[6]  <= feedback ? lfsr_q[5]  ^ POLY[6]  : lfsr_q[5];
            lfsr_q[7]  <= feedback ? lfsr_q[6]  ^ POLY[7]  : lfsr_q[6];
            lfsr_q[8]  <= feedback ? lfsr_q[7]  ^ POLY[8]  : lfsr_q[7];
            lfsr_q[9]  <= feedback ? lfsr_q[8]  ^ POLY[9]  : lfsr_q[8];
            lfsr_q[10] <= feedback ? lfsr_q[9]  ^ POLY[10] : lfsr_q[9];
            lfsr_q[11] <= feedback ? lfsr_q[10] ^ POLY[11] : lfsr_q[10];
            lfsr_q[12] <= feedback ? lfsr_q[11] ^ POLY[12] : lfsr_q[11];
            lfsr_q[13] <= feedback ? lfsr_q[12] ^ POLY[13] : lfsr_q[12];
            lfsr_q[14] <= feedback ? lfsr_q[13] ^ POLY[14] : lfsr_q[13];
            lfsr_q[15] <= feedback ? lfsr_q[14] ^ POLY[15] : lfsr_q[14];
            lfsr_q[16] <= feedback ? lfsr_q[15] ^ POLY[16] : lfsr_q[15];
            lfsr_q[17] <= feedback ? lfsr_q[16] ^ POLY[17] : lfsr_q[16];
            lfsr_q[18] <= feedback ? lfsr_q[17] ^ POLY[18] : lfsr_q[17];
            lfsr_q[19] <= feedback ? lfsr_q[18] ^ POLY[19] : lfsr_q[18];
            lfsr_q[20] <= feedback ? lfsr_q[19] ^ POLY[20] : lfsr_q[19];
            lfsr_q[21] <= feedback ? lfsr_q[20] ^ POLY[21] : lfsr_q[20];
            lfsr_q[22] <= feedback ? lfsr_q[21] ^ POLY[22] : lfsr_q[21];
            lfsr_q[23] <= feedback ? lfsr_q[22] ^ POLY[23] : lfsr_q[22];
            lfsr_q[24] <= feedback ? lfsr_q[23] ^ POLY[24] : lfsr_q[23];
            lfsr_q[25] <= feedback ? lfsr_q[24] ^ POLY[25] : lfsr_q[24];
            lfsr_q[26] <= feedback ? lfsr_q[25] ^ POLY[26] : lfsr_q[25];
            lfsr_q[27] <= feedback ? lfsr_q[26] ^ POLY[27] : lfsr_q[26];
            lfsr_q[28] <= feedback ? lfsr_q[27] ^ POLY[28] : lfsr_q[27];
            lfsr_q[29] <= feedback ? lfsr_q[28] ^ POLY[29] : lfsr_q[28];
            lfsr_q[30] <= feedback ? lfsr_q[29] ^ POLY[30] : lfsr_q[29];
            lfsr_q[31] <= feedback ? lfsr_q[30] ^ POLY[31] : lfsr_q[30];
        end else if (shift_out) begin
            // Clock out the calculated CRC bits
            lfsr_q <= {lfsr_q[30:0], 1'b0};
        end
    end

    // Output the MSB when shifting out
    assign crc_out = lfsr_q[31];

endmodule