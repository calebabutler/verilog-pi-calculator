
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

/* This module calculates the digits of pi. This is the interface:
 *   1. Reset the module by making the asynchronous reset (reset_n) low.
 *   2. Make reset_n high. Make the digits input the requested amount of
 *      digits in base-10. Make start high.
 *   3. On the rising edge of the valid_output output, read the pi_digit
 *      output. The module returns the digits of pi in base-10^9 from most
 *      significant to least significant.
 *   4. When the done output goes high, the module is done calculating.
 *
 * The module calculates pi using the Gregory series:
 *   arctan(x) = x - x^3/3 + x^5/5 - x^7/7 + ...
 * and the Manchin Formula:
 *   pi/4 = 4*arctan(1/5) - arctan(1/239)
 * It uses the big_int_arithmetic_logic_unit module to perform arithmetic on
 * very large integers.
 */

module pi_calculator (
    input clock, reset_n, start,
    input [31:0] digits,
    output [31:0] pi_digit,
    output valid_output, done
);
    // State
    reg [5:0] state;
    localparam [5:0] STATE_UNINITIALIZED = 6'd0,
                     STATE_SET_R0_TO_1 = 6'd2,
                     STATE_LEFT_SHIFT_R0 = 6'd4,
                     STATE_MULTIPLY_R0 = 6'd6,
                     STATE_WAIT_FOR_DONE = 6'd8,
                     STATE_ARCTAN_DIVIDE = 6'd10,
                     STATE_ARCTAN_COPY = 6'd12,
                     STATE_ARCTAN_LOOP_DIVIDE = 6'd14,
                     STATE_ARCTAN_LOOP_DIVIDE2 = 6'd16,
                     STATE_ARCTAN_LOOP_CHECK_ZERO = 6'd18,
                     STATE_ARCTAN_LOOP_CONDITIONAL_BREAK = 6'd20,
                     STATE_ARCTAN_LOOP_ADD_OR_SUBTRACT = 6'd22,
                     STATE_MULTIPLY_R2_BY_16 = 6'd24,
                     STATE_MULTIPLY_R5_BY_4 = 6'd26,
                     STATE_SUBTRACT_R2_AND_R5 = 6'd28,
                     STATE_RIGHT_SHIFT_R2 = 6'd30,
                     STATE_DIVIDE_R2 = 6'd32,
                     STATE_OUTPUT_R2 = 6'd34,
                     STATE_FINAL = 6'd36;

    // Opcodes
    localparam [3:0] OPCODE_SET = 4'd0,
                     OPCODE_ADD_IMMEDIATE = 4'd1,
                     OPCODE_ADD = 4'd2,
                     OPCODE_SUBTRACT_IMMEDIATE = 4'd3,
                     OPCODE_SUBTRACT = 4'd4,
                     OPCODE_MULTIPLY_IMMEDIATE = 4'd5,
                     OPCODE_DIVIDE_IMMEDIATE = 4'd6,
                     OPCODE_COPY = 4'd7,
                     OPCODE_LEFT_SHIFT = 4'd8,
                     OPCODE_RIGHT_SHIFT = 4'd9,
                     OPCODE_OUTPUT = 4'd10,
                     OPCODE_IS_ZERO = 4'd11;

    // Big int registers
    reg big_int_start, enable_output, is_term_negative;
    reg [3:0] opcode;
    reg [31:0] dest_address, src1_address, src2_address, immediate,
               digits_register, index, offset, argument, denominator;
    wire [31:0] big_int_result;
    wire big_int_valid_output, big_int_done;

    wire [31:0] word_width, left_shift_amount, multiply_amount;

    // Big int arithmetic logic unit module
    big_int_arithmetic_logic_unit u0 (
        .clock(clock),
        .reset_n(reset_n),
        .start(big_int_start),
        .opcode(opcode),
        .dest_address(dest_address),
        .src1_address(src1_address),
        .src2_address(src2_address),
        .immediate(immediate),
        .result(big_int_result),
        .valid_output(big_int_valid_output),
        .done(big_int_done)
    );

    // Assign statements
    assign pi_digit = enable_output ? big_int_result : 32'd0;
    assign valid_output = big_int_valid_output & enable_output;
    assign done = big_int_done & enable_output;

    assign word_width = (digits + 23) / 9 + 1;
    assign left_shift_amount = (digits_register + 21) / 9;
    assign multiply_amount = (digits_register + 21) % 9;

    // Always block
    always @(posedge(clock) or negedge(reset_n)) begin
        if (~reset_n) begin
            state <= STATE_UNINITIALIZED;
            big_int_start <= 1'b0;
            enable_output <= 1'b0;
            is_term_negative <= 1'b0;
            opcode <= 4'd0;
            dest_address <= 32'd0;
            src1_address <= 32'd0;
            src2_address <= 32'd0;
            immediate <= 32'd0;
            digits_register <= 32'd0;
            index <= 32'd0;
            offset <= 32'd0;
            argument <= 32'd0;
            denominator <= 32'd0;
        // When the state register is odd (meaning lowest bit is high), set
        // the start input to the big int ALU low and go to the next state.
        end else if (state[0] == 1'b1) begin
            big_int_start <= 1'b0;
            state <= state + 1;
        end else begin
            case (state)
            /* This state initializes the big int ALU with the needed word
             * width given the requested amount of digits.
             */
            STATE_UNINITIALIZED: begin
                if (start) begin
                    dest_address <= word_width;
                    digits_register <= digits;
                    big_int_start <= 1'b1;
                    state <= state + 1;
                end
            end

            /* The R0 register holds a giant 10^N integer representing 1.
             * First R0 is set to 1, then it is left shifted by a large
             * amount, then it is multiplied by some multiple of 10.
             */
            STATE_SET_R0_TO_1: begin
                opcode <= OPCODE_SET;
                dest_address <= 32'd0;
                immediate <= 32'd1;
                big_int_start <= 1'b1;
                state <= state + 1;
            end

            /* This state left shifts R0.
             */
            STATE_LEFT_SHIFT_R0: begin
                if (big_int_done) begin
                    opcode <= OPCODE_LEFT_SHIFT;
                    dest_address <= 32'd0;
                    src1_address <= 32'd0;
                    immediate <= left_shift_amount;
                    big_int_start <= 1'b1;
                    state <= state + 1;
                end
            end

            /* This state multiplies R0 by a multiple of 10. It also sets
             * offset and argument for the first arctangent calculation.
             */
            STATE_MULTIPLY_R0: begin
                if (big_int_done) begin
                    if (index == 32'd0) begin
                        immediate <= 32'd1;
                        index <= index + 1;
                    end else if (index <= multiply_amount) begin
                        immediate <= immediate * 32'd10;
                        index <= index + 1;
                    end else begin
                        opcode <= OPCODE_MULTIPLY_IMMEDIATE;
                        dest_address <= 32'd0;
                        src1_address <= 32'd0;
                        big_int_start <= 1'b1;
                        offset <= 32'd1;
                        argument <= 32'd5;
                        state <= state + 1;
                    end
                end
            end

            /* This state waits until the done signal goes high before
             * beginning the arctangent calculations.
             */
            STATE_WAIT_FOR_DONE: begin
                if (big_int_done) begin
                    state <= STATE_ARCTAN_DIVIDE;
                end
            end

            /* This state begins the arctangent calculation. The offset
             * register determines what registers are used for the arctangent
             * calculation. The argument register determines what argument is
             * used for the arctangent calculation. This is the calculation:
             *
             * arctan(1/argument) = 1/argument - (1/argument)^3/3
             *                    + (1/argument)^5/5 - (1/argument)^7/7 + ...
             *
             * This state sets the offset register to R0/argument.
             */
            STATE_ARCTAN_DIVIDE: begin
                opcode <= OPCODE_DIVIDE_IMMEDIATE;
                is_term_negative <= 1'b0;
                denominator <= 32'd1;
                dest_address <= offset;
                src1_address <= 32'd0;
                immediate <= argument;
                big_int_start <= 1'b1;
                state <= state + 1;
            end

            /* This state copies the offset register to the offset + 1
             * register. The offset + 1 register will hold the final output.
             */
            STATE_ARCTAN_COPY: begin
                if (big_int_done) begin
                    opcode <= OPCODE_COPY;
                    dest_address <= offset + 1;
                    src1_address <= offset;
                    big_int_start <= 1'b1;
                    state <= state + 1;
                end
            end

            /* This state sets the offset register to
             * offset / (argument * argument).
             */
            STATE_ARCTAN_LOOP_DIVIDE: begin
                if (big_int_done) begin
                    opcode <= OPCODE_DIVIDE_IMMEDIATE;
                    is_term_negative <= ~is_term_negative;
                    denominator <= denominator + 2;
                    dest_address <= offset;
                    src1_address <= offset;
                    immediate <= argument * argument;
                    big_int_start <= 1'b1;
                    state <= state + 1;
                end
            end

            /* This state sets the offset + 2 register to offset/denominator,
             * where denominator is incremented by 2 each time this loop is
             * run through.
             */
            STATE_ARCTAN_LOOP_DIVIDE2: begin
                if (big_int_done) begin
                    opcode <= OPCODE_DIVIDE_IMMEDIATE;
                    dest_address <= offset + 2;
                    src1_address <= offset;
                    immediate <= denominator;
                    big_int_start <= 1'b1;
                    state <= state + 1;
                end
            end

            /* This state checks if the offset + 2 register is zero.
             */
            STATE_ARCTAN_LOOP_CHECK_ZERO: begin
                if (big_int_done) begin
                    opcode <= OPCODE_IS_ZERO;
                    src1_address <= offset + 2;
                    big_int_start <= 1'b1;
                    state <= state + 1;
                end
            end

            /* If the offset + 2 register is zero, exit out of the arctangent
             * calculation. If you are calculating the arctangent calculation
             * with an argument of 5, restart the arctangent calculation with
             * an argument of 239; otherwise, continue to the next step of
             * calculating pi.
             */
            STATE_ARCTAN_LOOP_CONDITIONAL_BREAK: begin
                if (big_int_done) begin
                    if (big_int_result == 32'd1) begin
                        if (argument == 32'd5) begin
                            offset <= 4;
                            argument <= 239;
                            state <= STATE_ARCTAN_DIVIDE;
                        end else begin
                            state <= STATE_MULTIPLY_R2_BY_16;
                        end
                    end else begin
                        state <= STATE_ARCTAN_LOOP_ADD_OR_SUBTRACT;
                    end
                end
            end

            /* This state adds or subtracts offset + 2 to offset + 1 (the
             * final arctangent result).
             */
            STATE_ARCTAN_LOOP_ADD_OR_SUBTRACT: begin
                dest_address <= offset + 1;
                src1_address <= offset + 1;
                src2_address <= offset + 2;
                big_int_start <= 1'b1;
                state <= STATE_ARCTAN_LOOP_DIVIDE - 1;
                if (is_term_negative) begin
                    opcode <= OPCODE_SUBTRACT;
                end else begin
                    opcode <= OPCODE_ADD;
                end
            end

            /* This state multiplies R2 (the result of arctan(1/5)) by 16.
             */
            STATE_MULTIPLY_R2_BY_16: begin
                opcode <= OPCODE_MULTIPLY_IMMEDIATE;
                dest_address <= 32'd2;
                src1_address <= 32'd2;
                immediate <= 32'd16;
                big_int_start <= 1'b1;
                state <= state + 1;
            end

            /* This state multiplies R5 (the result of arctan(1/239)) by 4.
             */
            STATE_MULTIPLY_R5_BY_4: begin
                if (big_int_done) begin
                    opcode <= OPCODE_MULTIPLY_IMMEDIATE;
                    dest_address <= 32'd5;
                    src1_address <= 32'd5;
                    immediate <= 32'd4;
                    big_int_start <= 1'b1;
                    state <= state + 1;
                end
            end

            /* This state subtracts R2 and R5 and stores it in R2.
             */
            STATE_SUBTRACT_R2_AND_R5: begin
                if (big_int_done) begin
                    opcode <= OPCODE_SUBTRACT;
                    dest_address <= 32'd2;
                    src1_address <= 32'd2;
                    src2_address <= 32'd5;
                    big_int_start <= 1'b1;
                    state <= state + 1;
                end
            end

            /* This state right shifts R2 to remove inaccurate excess digits. 
             */
            STATE_RIGHT_SHIFT_R2: begin
                if (big_int_done) begin
                    opcode <= OPCODE_RIGHT_SHIFT;
                    dest_address <= 32'd2;
                    src1_address <= 32'd2;
                    immediate <= 32'd2;
                    big_int_start <= 1'b1;
                    state <= state + 1;
                end
            end

            /* This state divides R2 by a multiple of 10 for the same reason
             * as the right shift state.
             */
            STATE_DIVIDE_R2: begin
                if (big_int_done) begin
                    opcode <= OPCODE_DIVIDE_IMMEDIATE;
                    dest_address <= 32'd2;
                    src1_address <= 32'd2;
                    immediate <= 32'd10000;
                    big_int_start <= 1'b1;
                    state <= state + 1;
                end
            end

            /* This state outputs R2 to the user.
             */
            STATE_OUTPUT_R2: begin
                if (big_int_done) begin
                    opcode <= OPCODE_OUTPUT;
                    src1_address <= 32'd2;
                    big_int_start <= 1'b1;
                    enable_output <= 1'b1;
                    state <= state + 1;
                end
            end

            /* This state does nothing.
             */
            STATE_FINAL: begin
            end

            default: begin
            end
            endcase
        end
    end
endmodule
