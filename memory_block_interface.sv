
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

/* The purpose of this module is for the compiler to optimize the register
 * array inside it into a memory block. This uses significantly less resources
 * when the design is compiling, when the design is being simulated, and when
 * the design is synthesized onto a real FPGA. The tradeoff is the data in
 * this register array must be accessed from or modified to in only one
 * location per clock cycle. This interface makes sure this is the case.
 */

module memory_block_interface #(parameter SIZE = 800000) (
    input [31:0] write_input,
    input [31:0] address,
    input write_enable, clock,
    output reg [31:0] read_output
);
    reg [31:0] memory_block[0:SIZE - 1];

    always @(posedge(clock)) begin
        if (write_enable) begin
            memory_block[address] <= write_input;
        end else begin
            read_output <= memory_block[address];
        end
    end
endmodule
