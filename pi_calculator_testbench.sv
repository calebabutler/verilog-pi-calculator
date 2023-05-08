
/* This testbench tests the pi_calculator module.
 */

`timescale 1ns/1ns

module pi_calculator_testbench;
    // This define determines the amount of base-10 digits requested.
    `define REQUEST_DIGITS 32'd1000

    reg clock, reset_n, start;
    wire [31:0] pi_digit;
    wire valid_output, done;

    // Design under test
    pi_calculator dut (
        .clock(clock),
        .reset_n(reset_n),
        .start(start),
        .digits(`REQUEST_DIGITS),
        .pi_digit(pi_digit),
        .valid_output(valid_output),
        .done(done)
    );

    // Toggle clock at 0.5 MHz
    always begin
        #1 clock = ~clock;
    end

    initial begin
        // Display that testbench has started
        $display("*** My testbench ***");

        // Initialize everything to zero
        clock = 0;
        reset_n = 0;
        start = 0;

        // Set reset_n high
        #1 reset_n = 1;

        // Set start high
        #1 start = 1;

        // Display output
        do begin
            @(posedge(valid_output)) $display("pi_digit = %09d", pi_digit);
        end while (~done);

        // Stop testbench
        $stop;
    end
endmodule
