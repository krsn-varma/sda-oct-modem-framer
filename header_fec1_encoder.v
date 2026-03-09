module header_fec1_encoder (
    input  wire        clk,
    input  wire        rst_n,
    
    // Handshake input (1 bit from Header/CRC stream)
    input  wire        s_axis_tvalid,
    input  wire        s_axis_tdata,
    output reg         s_axis_tready,
    
    // Handshake output (6 bits serialized to datapath)
    output reg         m_axis_tvalid,
    output reg         m_axis_tdata,
    input  wire        m_axis_tready
);

    // Constraint length 7 requires a 7-bit shift register
    reg [6:0] shift_reg;
    
    // Generator Polynomials (Octal -> Binary)
    // 0175 -> 7'b1111101 (c0)
    // 0171 -> 7'b1111001 (c1)
    // 0151 -> 7'b1101001 (c2)
    // 0133 -> 7'b1011011 (c3)
    // 0127 -> 7'b1010111 (c4)
    // 0117 -> 7'b1001111 (c5)
    
    wire c0 = ^(shift_reg & 7'b1111101);
    wire c1 = ^(shift_reg & 7'b1111001);
    wire c2 = ^(shift_reg & 7'b1101001);
    wire c3 = ^(shift_reg & 7'b1011011);
    wire c4 = ^(shift_reg & 7'b1010111);
    wire c5 = ^(shift_reg & 7'b1001111);

    // Internal FSM to handle 1-to-6 serialization
    localparam STATE_WAIT_DATA = 3'd0;
    localparam STATE_OUT_C5    = 3'd1;
    localparam STATE_OUT_C4    = 3'd2;
    localparam STATE_OUT_C3    = 3'd3;
    localparam STATE_OUT_C2    = 3'd4;
    localparam STATE_OUT_C1    = 3'd5;
    localparam STATE_OUT_C0    = 3'd6;
    
    reg [2:0] state_q, state_d;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_q   <= STATE_WAIT_DATA;
            shift_reg <= 7'd0; // Initialize to zero state
        end else begin
            state_q <= state_d;
            // Shift new data in when accepted
            if (s_axis_tvalid && s_axis_tready) begin
                shift_reg <= {s_axis_tdata, shift_reg[6:1]}; 
            end
        end
    end

    always @(*) begin
        // Defaults
        state_d       = state_q;
        s_axis_tready = 1'b0;
        m_axis_tvalid = 1'b0;
        m_axis_tdata  = 1'b0;

        case (state_q)
            STATE_WAIT_DATA: begin
                s_axis_tready = 1'b1;
                if (s_axis_tvalid) begin
                    state_d = STATE_OUT_C5;
                end
            end
            
            // Standard: Transmit c5 first, down to c0 for each info bit
            STATE_OUT_C5: begin
                m_axis_tvalid = 1'b1;
                m_axis_tdata  = c5;
                if (m_axis_tready) state_d = STATE_OUT_C4;
            end
            
            STATE_OUT_C4: begin
                m_axis_tvalid = 1'b1;
                m_axis_tdata  = c4;
                if (m_axis_tready) state_d = STATE_OUT_C3;
            end
            
            STATE_OUT_C3: begin
                m_axis_tvalid = 1'b1;
                m_axis_tdata  = c3;
                if (m_axis_tready) state_d = STATE_OUT_C2;
            end
            
            STATE_OUT_C2: begin
                m_axis_tvalid = 1'b1;
                m_axis_tdata  = c2;
                if (m_axis_tready) state_d = STATE_OUT_C1;
            end
            
            STATE_OUT_C1: begin
                m_axis_tvalid = 1'b1;
                m_axis_tdata  = c1;
                if (m_axis_tready) state_d = STATE_OUT_C0;
            end
            
            STATE_OUT_C0: begin
                m_axis_tvalid = 1'b1;
                m_axis_tdata  = c0;
                // Go back to wait for the next raw header bit
                if (m_axis_tready) state_d = STATE_WAIT_DATA;
            end
            
            default: state_d = STATE_WAIT_DATA;
        endcase
    end

endmodule