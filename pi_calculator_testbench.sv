
/* MIT License
 *
 * Copyright (c) 2023 Caleb Butler
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */

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
