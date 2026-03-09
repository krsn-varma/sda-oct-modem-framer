`timescale 1ns / 1ps

module tb_oct_frame();

    reg clk, rst_n, start_frame, payload_bit_in;
    wire busy, frame_done, frame_valid, frame_data;

    // --- Instantiate with Parameterized Header ---
    oct_frame_builder #(
        .PREAMBLE_LEN(8),
        .RAW_HEADER_LEN(2),
        .PAYLOAD_LEN(16),
        .CRC32_LEN(8),
        .FEC_PARITY_LEN(8),
        .HEADER_VALUE(2'b10)  
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .start_frame(start_frame),
        .payload_bit_in(payload_bit_in),
        .busy(busy),
        .frame_done(frame_done),
        .frame_valid(frame_valid),
        .frame_data(frame_data)
    );

    // Clock Generation
    initial begin
        clk = 0; 
        forever #5 clk = ~clk; 
    end

    // State Decoding for Monitor
    reg [8*8:1] state_string;
    always @(*) begin
        case (uut.state_q)
            3'd0: state_string = "IDLE    ";
            3'd1: state_string = "PREAMBLE";
            3'd2: state_string = "HEADER  ";
            3'd3: state_string = "PAYLOAD ";
            3'd4: state_string = "PAY_CRC ";
            3'd5: state_string = "PAY_FEC ";
            default: state_string = "UNKNOWN ";
        endcase
    end

    // Stimulus
    initial begin
        // Initialize
        rst_n = 0;
        start_frame = 0;
        payload_bit_in = 0;

        $display("===================================================================");
        $display(" Time(ns) |   State    | Bit Count | Valid | Data Out | Frame Done");
        $display("===================================================================");

        $monitor(" %8t | %s |    %4d   |   %b   |    %b     |      %b", 
                 $time, state_string, uut.bit_cnt_q, frame_valid, frame_data, frame_done);

        #20;
        rst_n = 1;
        #10;
        
        // Start Frame
        start_frame = 1;
        #10;
        start_frame = 0; 

        // Run until completion
        while (!frame_done) begin
            @(posedge clk);
            // Feed random data during Payload state
            if (uut.state_q == 3'd3) 
                payload_bit_in = $random % 2; 
            else 
                payload_bit_in = 0;
        end

        #50;
        $display("===================================================================");
        $display("Simulation Complete! Frame successfully generated.");
        $finish;
    end

endmodule