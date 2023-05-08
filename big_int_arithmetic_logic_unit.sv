
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

/* This module lets a user perform arithmetic on very large precision
 * integers. It controls its own memory block to store these very large
 * precision integers. This means it has a lot more functionality than a
 * regular ALU (since it handles its own memory), but it is not quite a CPU,
 * since it has no instruction memory or any way to manage control flow.
 *
 * A user interacts with the module first by resetting it; that is, setting
 * the reset_n input low then high. Then, the user gives the module their
 * desired word width. The word width is the amount of 32-bit words one big
 * int integer uses. Each 32-bit word holds one digit of a base-10^9 integer.
 *
 * The user gives the module this word width by making the dest_address input
 * the word width and making start high. After a clock cycle, the module will
 * be initialized and ready for operation requests.
 *
 * A user makes an operation request by setting the opcode input to the
 * desired opcode. Depending on the opcode, the user then sets the
 * dest_address, src1_address, src2_address, and immediate inputs to the
 * wanted values. The user then makes the start input high. The user knows the
 * operation has completed once the done output goes high. After that, the
 * user can request another operation.
 *
 * ---------------------------------------------------------------------------
 * | Operation          | Opcode | Description                               |
 * | set                |      0 | *dest_address=immediate                   |
 * | add immediate      |      1 | *dest_address=*src1_address+immediate     |
 * | add                |      2 | *dest_address=*src1_address+*src2_address |
 * | subtract immediate |      3 | *dest_address=*src1_address-immediate     |
 * | subtract           |      4 | *dest_address=*src1_address-*src2_address |
 * | multiply immediate |      5 | *dest_address=*src1_address*immediate     |
 * | divide immediate   |      6 | *dest_address=*src1_address/immediate     |
 * | copy               |      7 | *dest_address=*src1_address               |
 * | left shift         |      8 | *dest_address=*src1_address*(10^(9*immed))|
 * | right shift        |      9 | *dest_address=*src1_address/(10^(9*immed))|
 * | output             |     10 | result=*src1_address                      |
 * | is zero            |     11 | result=(*src1_address==0)                 |
 * ---------------------------------------------------------------------------
 */

module big_int_arithmetic_logic_unit (
    input clock, reset_n, start,
    input [3:0] opcode,
    input [31:0] dest_address,
    input [31:0] src1_address,
    input [31:0] src2_address,
    input [31:0] immediate,
    output [31:0] result,
    output valid_output, done
);
    // Defines
    `define BASE 1000000000

    // States
    reg [5:0] state;
    localparam [5:0] STATE_UNINITIALIZED = 6'd0,
                     STATE_WAIT_FOR_OP = 6'd1,
                     STATE_SET = 6'd2,
                     STATE_SET2 = 6'd3,
                     STATE_ADD_IMMEDIATE = 6'd4,
                     STATE_ADD_IMMEDIATE2 = 6'd5,
                     STATE_ADD_IMMEDIATE3 = 6'd6,
                     STATE_ADD_IMMEDIATE4 = 6'd7,
                     STATE_ADD = 6'd8,
                     STATE_ADD2 = 6'd9,
                     STATE_ADD3 = 6'd10,
                     STATE_ADD4 = 6'd11,
                     STATE_ADD5 = 6'd12,
                     STATE_ADD6 = 6'd13,
                     STATE_SUBTRACT_IMMEDIATE = 6'd14,
                     STATE_SUBTRACT_IMMEDIATE2 = 6'd15,
                     STATE_SUBTRACT_IMMEDIATE3 = 6'd16,
                     STATE_SUBTRACT_IMMEDIATE4 = 6'd17,
                     STATE_SUBTRACT = 6'd18,
                     STATE_SUBTRACT2 = 6'd19,
                     STATE_SUBTRACT3 = 6'd20,
                     STATE_SUBTRACT4 = 6'd21,
                     STATE_SUBTRACT5 = 6'd22,
                     STATE_SUBTRACT6 = 6'd23,
                     STATE_MULTIPLY_IMMEDIATE = 6'd24,
                     STATE_MULTIPLY_IMMEDIATE2 = 6'd25,
                     STATE_MULTIPLY_IMMEDIATE3 = 6'd26,
                     STATE_MULTIPLY_IMMEDIATE4 = 6'd27,
                     STATE_DIVIDE_IMMEDIATE = 6'd28,
                     STATE_DIVIDE_IMMEDIATE2 = 6'd29,
                     STATE_DIVIDE_IMMEDIATE3 = 6'd30,
                     STATE_DIVIDE_IMMEDIATE4 = 6'd31,
                     STATE_COPY = 6'd32,
                     STATE_COPY2 = 6'd33,
                     STATE_COPY3 = 6'd34,
                     STATE_COPY4 = 6'd35,
                     STATE_LEFT_SHIFT = 6'd36,
                     STATE_LEFT_SHIFT2 = 6'd37,
                     STATE_LEFT_SHIFT3 = 6'd38,
                     STATE_LEFT_SHIFT4 = 6'd39,
                     STATE_RIGHT_SHIFT = 6'd40,
                     STATE_RIGHT_SHIFT2 = 6'd41,
                     STATE_RIGHT_SHIFT3 = 6'd42,
                     STATE_RIGHT_SHIFT4 = 6'd43,
                     STATE_OUTPUT = 6'd44,
                     STATE_OUTPUT2 = 6'd45,
                     STATE_OUTPUT3 = 6'd46,
                     STATE_OUTPUT4 = 6'd47,
                     STATE_OUTPUT5 = 6'd48,
                     STATE_IS_ZERO = 6'd49,
                     STATE_IS_ZERO2 = 6'd50,
                     STATE_IS_ZERO3 = 6'd51;

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

    // Signals needed for ALU
    reg [31:0] word_width;
    reg [31:0] dest_address_capture;
    reg [31:0] src1_address_capture;
    reg [31:0] src2_address_capture;
    reg [31:0] immediate_capture;

    reg [31:0] index;

    wire [32:0] add_immediate_sum;
    wire [32:0] add_immediate_sum_minus_base;

    reg [31:0] add_first_argument;
    reg add_carry;
    wire [32:0] add_sum;
    wire [32:0] add_sum_minus_base;

    wire signed [32:0] subtract_immediate_difference;
    wire signed [32:0] subtract_immediate_difference_plus_base;

    reg [31:0] subtract_first_argument;
    reg subtract_carry;
    wire signed [32:0] subtract_difference;
    wire signed [32:0] subtract_difference_plus_base;

    reg [63:0] multiply_immediate_carry;
    wire [63:0] multiply_immediate_product;
    wire [63:0] multiply_immediate_product_mod_base;
    wire [63:0] multiply_immediate_product_div_base;

    reg [63:0] divide_immediate_carry;
    wire [63:0] divide_immediate_dividend;
    wire [63:0] divide_immediate_quotient;
    wire [63:0] divide_immediate_remainder;

    // Signals for memory block
    reg [31:0] memory_write_input;
    reg [31:0] memory_address;
    reg memory_write_enable;
    wire [31:0] memory_read_output;

    // Signals for outputs
    reg [31:0] internal_result;
    reg internal_valid_output;
    reg internal_done;

    // Create memory block
    memory_block_interface u0 (
        .write_input(memory_write_input),
        .address(memory_address),
        .write_enable(memory_write_enable),
        .clock(clock),
        .read_output(memory_read_output)
    );

    // Useful calculations
    assign add_immediate_sum = {1'b0, memory_read_output}
                             + {1'b0, immediate_capture};

    assign add_immediate_sum_minus_base = add_immediate_sum - `BASE;

    assign add_sum = {1'b0, add_first_argument}
                   + {1'b0, memory_read_output}
                   + {32'd0, add_carry};

    assign add_sum_minus_base = add_sum - `BASE;

    assign subtract_immediate_difference = {1'b0, memory_read_output}
                                         - {1'b0, immediate_capture};

    assign subtract_immediate_difference_plus_base =
        subtract_immediate_difference + `BASE;

    assign subtract_difference = {1'b0, subtract_first_argument}
                               - {1'b0, memory_read_output}
                               - {32'b0, subtract_carry};

    assign subtract_difference_plus_base = subtract_difference + `BASE;

    assign multiply_immediate_product = {32'd0, memory_read_output}
                                      * {32'd0, immediate_capture}
                                      + multiply_immediate_carry;

    assign multiply_immediate_product_mod_base =
        multiply_immediate_product % `BASE;

    assign multiply_immediate_product_div_base =
        multiply_immediate_product / `BASE;

    assign divide_immediate_dividend = divide_immediate_carry
                                     * `BASE
                                     + {32'd0, memory_read_output};

    assign divide_immediate_quotient = divide_immediate_dividend
                                     / {32'd0, immediate_capture};

    assign divide_immediate_remainder = divide_immediate_dividend
                                      % {32'd0, immediate_capture};

    // Assign outputs
    assign result = internal_result;
    assign valid_output = internal_valid_output;
    assign done = internal_done;

    // Always block for state machine
    always @(posedge(clock) or negedge(reset_n)) begin
        if (~reset_n) begin
            state <= STATE_UNINITIALIZED;
            word_width <= 32'd0;
            dest_address_capture <= 32'd0;
            src1_address_capture <= 32'd0;
            src2_address_capture <= 32'd0;
            immediate_capture <= 32'd0;
            index <= 32'd0;
            add_first_argument <= 32'd0;
            add_carry <= 1'b0;
            subtract_first_argument <= 32'd0;
            subtract_carry <= 1'b0;
            multiply_immediate_carry <= 64'd0;
            divide_immediate_carry <= 64'd0;
            memory_write_input <= 32'd0;
            memory_address <= 32'd0;
            memory_write_enable <= 1'd0;
            internal_result <= 32'd0;
            internal_valid_output <= 1'b0;
            internal_done <= 1'b0;
        end else begin
            case (state)
            /* This state waits for the user to initialize the word width.
             */
            STATE_UNINITIALIZED: begin
                if (start) begin
                    word_width <= dest_address;
                    state <= STATE_WAIT_FOR_OP;
                end
            end

            /* This state waits for the user to give an operation request.
             * Once the user makes an operation request, the state changes to
             * the appropriate initial state and the module captures the
             * needed inputs into registers.
             */
            STATE_WAIT_FOR_OP: begin
                if (start) begin
                    internal_valid_output <= 1'b0;
                    internal_done <= 1'b0;
                    case (opcode)
                    OPCODE_SET: begin
                        dest_address_capture <= dest_address;
                        immediate_capture <= immediate;
                        state <= STATE_SET;
                    end
                    OPCODE_ADD_IMMEDIATE: begin
                        dest_address_capture <= dest_address;
                        src1_address_capture <= src1_address;
                        immediate_capture <= immediate;
                        state <= STATE_ADD_IMMEDIATE;
                    end
                    OPCODE_ADD: begin
                        dest_address_capture <= dest_address;
                        src1_address_capture <= src1_address;
                        src2_address_capture <= src2_address;
                        state <= STATE_ADD;
                    end
                    OPCODE_SUBTRACT_IMMEDIATE: begin
                        dest_address_capture <= dest_address;
                        src1_address_capture <= src1_address;
                        immediate_capture <= immediate;
                        state <= STATE_SUBTRACT_IMMEDIATE;
                    end
                    OPCODE_SUBTRACT: begin
                        dest_address_capture <= dest_address;
                        src1_address_capture <= src1_address;
                        src2_address_capture <= src2_address;
                        state <= STATE_SUBTRACT;
                    end
                    OPCODE_MULTIPLY_IMMEDIATE: begin
                        dest_address_capture <= dest_address;
                        src1_address_capture <= src1_address;
                        immediate_capture <= immediate;
                        state <= STATE_MULTIPLY_IMMEDIATE;
                    end
                    OPCODE_DIVIDE_IMMEDIATE: begin
                        dest_address_capture <= dest_address;
                        src1_address_capture <= src1_address;
                        immediate_capture <= immediate;
                        state <= STATE_DIVIDE_IMMEDIATE;
                    end
                    OPCODE_COPY: begin
                        dest_address_capture <= dest_address;
                        src1_address_capture <= src1_address;
                        state <= STATE_COPY;
                    end
                    OPCODE_LEFT_SHIFT: begin
                        dest_address_capture <= dest_address;
                        src1_address_capture <= src1_address;
                        immediate_capture <= immediate;
                        state <= STATE_LEFT_SHIFT;
                    end
                    OPCODE_RIGHT_SHIFT: begin
                        dest_address_capture <= dest_address;
                        src1_address_capture <= src1_address;
                        immediate_capture <= immediate;
                        state <= STATE_RIGHT_SHIFT;
                    end
                    OPCODE_OUTPUT: begin
                        src1_address_capture <= src1_address;
                        state <= STATE_OUTPUT;
                    end
                    OPCODE_IS_ZERO: begin
                        src1_address_capture <= src1_address;
                        state <= STATE_IS_ZERO;
                    end
                    default: begin
                        // Do nothing for invalid opcodes
                    end
                    endcase
                end
            end

            /* This state writes immediate to dest_address * word_width.
             */
            STATE_SET: begin
                memory_address <= dest_address_capture * word_width;
                memory_write_enable <= 1'b1;
                memory_write_input <= immediate_capture;
                state <= STATE_SET2;
            end

            /* This state writes zero as long as the memory address is within
             * the memory allocated to the dest_address integer. It also
             * increments the memory address by one. If the memory address is
             * outside the bounds allocated to the dest_address integer, the
             * set operation is over.
             */
            STATE_SET2: begin
                if (memory_address < dest_address_capture * word_width
                                   + word_width - 1) begin
                    memory_address <= memory_address + 1;
                    memory_write_input <= 32'd0;
                end else begin
                    memory_write_enable <= 1'b0;
                    internal_done <= 1'b1;
                    state <= STATE_WAIT_FOR_OP;
                end
            end

            /* This state requests to read src1_address * word_width and sets
             * index to zero.
             */
            STATE_ADD_IMMEDIATE: begin
                memory_address <= src1_address_capture * word_width;
                index <= 32'd0;
                state <= STATE_ADD_IMMEDIATE2;
            end

            /* This state waits for the read request to process.
             */
            STATE_ADD_IMMEDIATE2: begin
                state <= STATE_ADD_IMMEDIATE3;
            end

            /* This state writes to dest_address * word_width + index one of
             * two things. If read result + immediate >= BASE, it writes
             * result + immediate - BASE and sets immediate to 1. Otherwise,
             * it writes result + immediate and sets immediate to 0.
             */
            STATE_ADD_IMMEDIATE3: begin
                memory_address <= dest_address_capture * word_width + index;
                memory_write_enable <= 1'b1;
                state <= STATE_ADD_IMMEDIATE4;
                if (add_immediate_sum >= `BASE) begin
                    memory_write_input <= add_immediate_sum_minus_base[31:0];
                    immediate_capture <= 32'd1;
                end else begin
                    memory_write_input <= add_immediate_sum[31:0];
                    immediate_capture <= 32'd0;
                end
            end

            /* This state requests to read from
             * src1_address * word_width + index + 1. It also increments
             * index. If the index is within the word width, and
             * immediate > 0, the state goes back to state 2. Otherwise, the
             * add operation is over.
             */
            STATE_ADD_IMMEDIATE4: begin
                memory_write_enable <= 1'b0;
                memory_address <= src1_address_capture * word_width
                                + index + 1;
                index <= index + 1;
                if (index < word_width - 1
                 && immediate_capture != 32'd0) begin
                    state <= STATE_ADD_IMMEDIATE2;
                end else begin
                    internal_done <= 1'b1;
                    state <= STATE_WAIT_FOR_OP;
                end
            end

            /* This state sets index to zero and add_carry to zero.
             */
            STATE_ADD: begin
                index <= 32'd0;
                add_carry <= 1'b0;
                state <= STATE_ADD2;
            end

            /* This state makes a read request to
             * src1_address * word_width + index.
             */
            STATE_ADD2: begin
                memory_address <= src1_address_capture * word_width + index;
                state <= STATE_ADD3;
            end

            /* This state makes a read request to
             * src2_address * word_width + index.
             */
            STATE_ADD3: begin
                memory_address <= src2_address_capture * word_width + index;
                state <= STATE_ADD4;
            end

            /* This state captures the output of the first read request to
             * add_first_argument.
             */
            STATE_ADD4: begin
                add_first_argument <= memory_read_output;
                state <= STATE_ADD5;
            end

            /* This state makes a write request to
             * dest_address * word_width + index. It writes
             * add_first_argument + read output + add_carry. If that addition
             * is greater than or equal to the base, it subtracts the base
             * from the addition and sets carry to 1. Otherwise, carry is set
             * to zero.
             */
            STATE_ADD5: begin
                memory_address <= dest_address_capture * word_width + index;
                memory_write_enable <= 1'b1;
                state <= STATE_ADD6;
                if (add_sum >= `BASE) begin
                    memory_write_input <= add_sum_minus_base[31:0];
                    add_carry <= 1'b1;
                end else begin
                    memory_write_input <= add_sum[31:0];
                    add_carry <= 1'b0;
                end
            end

            /* This state increments the index. If the index is past the word
             * width, the add operation is over.
             */
            STATE_ADD6: begin
                memory_write_enable <= 1'b0;
                index <= index + 1;
                if (index < word_width - 1) begin
                    state <= STATE_ADD2;
                end else begin
                    internal_done <= 1'b1;
                    state <= STATE_WAIT_FOR_OP;
                end
            end

            /* This state requests to read src1_address * word_width and sets
             * index to zero.
             */
            STATE_SUBTRACT_IMMEDIATE: begin
                memory_address <= src1_address_capture * word_width;
                index <= 32'd0;
                state <= STATE_SUBTRACT_IMMEDIATE2;
            end

            /* This state waits for the read request to process.
             */
            STATE_SUBTRACT_IMMEDIATE2: begin
                state <= STATE_SUBTRACT_IMMEDIATE3;
            end

            /* This state writes to dest_address * word_width + index one of
             * two things. If read result - immediate < 0 it writes
             * result - immediate + BASE and sets immediate to 1. Otherwise,
             * it writes result - immediate and sets immediate to 0.
             */
            STATE_SUBTRACT_IMMEDIATE3: begin
                memory_address <= dest_address_capture * word_width + index;
                memory_write_enable <= 1'b1;
                state <= STATE_SUBTRACT_IMMEDIATE4;
                if (subtract_immediate_difference < 0) begin
                    memory_write_input <=
                        subtract_immediate_difference_plus_base[31:0];
                    immediate_capture <= 32'd1;
                end else begin
                    memory_write_input <= subtract_immediate_difference[31:0];
                    immediate_capture <= 32'd0;
                end
            end

            /* This state requests to read from
             * src1_address * word_width + index + 1. It also increments
             * index. If the index is within the word width, and
             * immediate > 0, the state goes back to state 2. Otherwise, the
             * subtract operation is over.
             */
            STATE_SUBTRACT_IMMEDIATE4: begin
                memory_write_enable <= 1'b0;
                memory_address <= src1_address_capture * word_width
                                + index + 1;
                index <= index + 1;
                if (index < word_width - 1
                 && immediate_capture != 32'd0) begin
                    state <= STATE_SUBTRACT_IMMEDIATE2;
                end else begin
                    internal_done <= 1'b1;
                    state <= STATE_WAIT_FOR_OP;
                end
            end

            /* This state sets index to zero and add_carry to zero.
             */
            STATE_SUBTRACT: begin
                index <= 32'd0;
                subtract_carry <= 1'b0;
                state <= STATE_SUBTRACT2;
            end

            /* This state makes a read request to
             * src1_address * word_width + index.
             */
            STATE_SUBTRACT2: begin
                memory_address <= src1_address_capture * word_width + index;
                state <= STATE_SUBTRACT3;
            end

            /* This state makes a read request to
             * src2_address * word_width + index.
             */
            STATE_SUBTRACT3: begin
                memory_address <= src2_address_capture * word_width + index;
                state <= STATE_SUBTRACT4;
            end

            /* This state captures the output of the first read request to
             * subtract_first_argument.
             */
            STATE_SUBTRACT4: begin
                subtract_first_argument <= memory_read_output;
                state <= STATE_SUBTRACT5;
            end

            /* This state makes a write request to
             * dest_address * word_width + index. It writes
             * subtract_first_argument - read output - subtract_carry. If that
             * difference is less than zero, it adds the base to the
             * difference and sets carry to 1. Otherwise, carry is set to
             * zero.
             */
            STATE_SUBTRACT5: begin
                memory_address <= dest_address_capture * word_width + index;
                memory_write_enable <= 1'b1;
                state <= STATE_SUBTRACT6;
                if (subtract_difference < 0) begin
                    memory_write_input <= subtract_difference_plus_base[31:0];
                    subtract_carry <= 1'b1;
                end else begin
                    memory_write_input <= subtract_difference[31:0];
                    subtract_carry <= 1'b0;
                end
            end

            /* This state increments the index. If the index is past the word
             * width, the subtract operation is over.
             */
            STATE_SUBTRACT6: begin
                memory_write_enable <= 1'b0;
                index <= index + 1;
                if (index < word_width - 1) begin
                    state <= STATE_SUBTRACT2;
                end else begin
                    internal_done <= 1'b1;
                    state <= STATE_WAIT_FOR_OP;
                end
            end

            /* This state requests to read src1_address * word_width, sets
             * index to zero, and sets multiply_immediate_carry to zero.
             */
            STATE_MULTIPLY_IMMEDIATE: begin
                memory_address <= src1_address_capture * word_width;
                index <= 32'd0;
                multiply_immediate_carry <= 64'd0;
                state <= STATE_MULTIPLY_IMMEDIATE2;
            end

            /* This state waits for the read request to process.
             */
            STATE_MULTIPLY_IMMEDIATE2: begin
                state <= STATE_MULTIPLY_IMMEDIATE3;
            end

            /* This state calculates the product:
             *   read output * immediate + multiply_immediate_carry.
             * It writes this product modulo the base to
             * dest_address * word_width + index. It sets the
             * multiply_immediate_carry register to this product divided by
             * the base.
             */
            STATE_MULTIPLY_IMMEDIATE3: begin
                memory_address <= dest_address_capture * word_width + index;
                memory_write_enable <= 1'b1;
                state <= STATE_MULTIPLY_IMMEDIATE4;
                memory_write_input <=
                    multiply_immediate_product_mod_base[31:0];
                multiply_immediate_carry <=
                    multiply_immediate_product_div_base;
            end

            /* This state requests to read from
             * src1_address * word_width + index + 1. It also increments the
             * index. If the index is within the word width, the state goes
             * back to state 2. Otherwise, the multiply operation is over.
             */
            STATE_MULTIPLY_IMMEDIATE4: begin
                memory_write_enable <= 1'b0;
                memory_address <= src1_address_capture * word_width
                                + index + 1;
                index <= index + 1;
                if (index < word_width - 1) begin
                    state <= STATE_MULTIPLY_IMMEDIATE2;
                end else begin
                    internal_done <= 1'b1;
                    state <= STATE_WAIT_FOR_OP;
                end
            end

            /* This state requests to read
             *   src1_address * word_width + word_width - 1.
             * It also sets index to word_width - 1, and sets
             * divide_immediate_carry to zero.
             */
            STATE_DIVIDE_IMMEDIATE: begin
                memory_address <= src1_address_capture * word_width
                                + word_width - 1;
                index <= word_width - 1;
                divide_immediate_carry <= 64'd0;
                state <= STATE_DIVIDE_IMMEDIATE2;
            end

            /* This state waits for the read request to process.
             */
            STATE_DIVIDE_IMMEDIATE2: begin
                state <= STATE_DIVIDE_IMMEDIATE3;
            end

            /* This state calculates the dividend:
             *   divide_immediate_carry * base + read output.
             * It writes this dividend divided by the immediate to
             * dest_address * word_width + index. It sets the
             * dividend_immediate_carry register to this dividend modulo by
             * the immediate.
             */
            STATE_DIVIDE_IMMEDIATE3: begin
                memory_address <= dest_address_capture * word_width + index;
                memory_write_enable <= 1'b1;
                state <= STATE_DIVIDE_IMMEDIATE4;
                memory_write_input <= divide_immediate_quotient[31:0];
                divide_immediate_carry <= divide_immediate_remainder;
            end

            /* This state requests to read from
             * src1_address * word_width + index + 1. It also decrements the
             * index. If the index is within the word width, the state goes
             * back to state 2. Otherwise, the divide operation is over.
             */
            STATE_DIVIDE_IMMEDIATE4: begin
                memory_write_enable <= 1'b0;
                memory_address <= src1_address_capture * word_width
                                + index - 1;
                index <= index - 1;
                if (index > 0) begin
                    state <= STATE_DIVIDE_IMMEDIATE2;
                end else begin
                    internal_done <= 1'b1;
                    state <= STATE_WAIT_FOR_OP;
                end
            end

            /* This state requests to read from src1_address * word_width and
             * sets index to zero.
             */
            STATE_COPY: begin
                memory_address <= src1_address_capture * word_width;
                index <= 32'd0;
                state <= STATE_COPY2;
            end

            /* This state waits for the read request to process.
             */
            STATE_COPY2: begin
                state <= STATE_COPY3;
            end

            /* This state writes the read output to
             * dest_address * word_width + index.
             */
            STATE_COPY3: begin
                memory_address <= dest_address_capture * word_width + index;
                memory_write_enable <= 1'b1;
                state <= STATE_COPY4;
                memory_write_input <= memory_read_output;
            end

            /* This state requests to read from
             * src1_address * word_width + index + 1. It also increments the
             * index. If the index is within the word width, the state goes
             * back to state 2. Otherwise, the copy operation is over.
             */
            STATE_COPY4: begin
                memory_write_enable <= 1'b0;
                memory_address <= src1_address_capture * word_width
                                + index + 1;
                index <= index + 1;
                if (index < word_width - 1) begin
                    state <= STATE_COPY2;
                end else begin
                    internal_done <= 1'b1;
                    state <= STATE_WAIT_FOR_OP;
                end
            end

            /* This state requests to read from
             * src1_address * word_width + word_width - 1 - immediate and sets
             * index to zero.
             */
            STATE_LEFT_SHIFT: begin
                memory_address <= src1_address_capture * word_width
                                + word_width - 1 - immediate_capture;
                index <= word_width - 1;
                state <= STATE_LEFT_SHIFT2;
            end

            /* This state waits for the read request to process.
             */
            STATE_LEFT_SHIFT2: begin
                state <= STATE_LEFT_SHIFT3;
            end

            /* This state either writes the read output to
             * dest_address * word_width + index or zero depending on whether
             * index is greater than or equal to the immediate.
             */
            STATE_LEFT_SHIFT3: begin
                memory_address <= dest_address_capture * word_width + index;
                memory_write_enable <= 1'b1;
                state <= STATE_LEFT_SHIFT4;
                if (index >= immediate_capture) begin
                    memory_write_input <= memory_read_output;
                end else begin
                    memory_write_input <= 32'd0;
                end
            end

            /* This state requests to read from
             * src1_address * word_width + index - 1 - immediate. It also
             * decrements the index. If the index is within the word width,
             * the state goes back to state 2. Otherwise, the shift operation
             * is over.
             */
            STATE_LEFT_SHIFT4: begin
                memory_write_enable <= 1'b0;
                memory_address <= src1_address_capture * word_width
                                + index - 1 - immediate_capture;
                index <= index - 1;
                if (index > 0) begin
                    state <= STATE_LEFT_SHIFT2;
                end else begin
                    internal_done <= 1'b1;
                    state <= STATE_WAIT_FOR_OP;
                end
            end

            /* This state requests to read from
             * src1_address * word_width + immediate and sets index to zero.
             */
            STATE_RIGHT_SHIFT: begin
                memory_address <= src1_address_capture * word_width
                                + immediate_capture;
                index <= 0;
                state <= STATE_RIGHT_SHIFT2;
            end

            /* This state waits for the read request to process.
             */
            STATE_RIGHT_SHIFT2: begin
                state <= STATE_RIGHT_SHIFT3;
            end

            /* This state either writes the read output to
             * dest_address * word_width + index or zero depending on whether
             * index is less than word_width - immediate.
             */
            STATE_RIGHT_SHIFT3: begin
                memory_address <= dest_address_capture * word_width + index;
                memory_write_enable <= 1'b1;
                state <= STATE_RIGHT_SHIFT4;
                if (index < word_width - immediate_capture) begin
                    memory_write_input <= memory_read_output;
                end else begin
                    memory_write_input <= 32'd0;
                end
            end

            /* This state requests to read from
             * src1_address * word_width + index + 1 + immediate. It also
             * increments the index. If the index is within the word width,
             * the state goes back to state 2. Otherwise, the shift operation
             * is over.
             */
            STATE_RIGHT_SHIFT4: begin
                memory_write_enable <= 1'b0;
                memory_address <= src1_address_capture * word_width
                                + index + 1 + immediate_capture;
                index <= index + 1;
                if (index < word_width - 1) begin
                    state <= STATE_RIGHT_SHIFT2;
                end else begin
                    internal_done <= 1'b1;
                    state <= STATE_WAIT_FOR_OP;
                end
            end

            /* This state requests to read from
             * src1_address * word_width + word_width - 1.
             */
            STATE_OUTPUT: begin
                memory_address <= src1_address_capture * word_width
                                + word_width - 1;
                state <= STATE_OUTPUT2;
            end

            /* This state waits for the read request to process.
             */
            STATE_OUTPUT2: begin
                state <= STATE_OUTPUT3;
            end

            /* This state decrements the memory address of which is being
             * read. If the memory address is outside the bounds of the word
             * width, output whatever is read last and finish the output
             * operation. If the value read is zero, go to state 2 and read
             * the new memory address. If the value read is non-zero, go to
             * state 4 and read the new memory address.
             */
            STATE_OUTPUT3: begin
                memory_address <= memory_address - 1;
                if (memory_address <= src1_address_capture * word_width) begin
                    internal_result <= memory_read_output;
                    internal_valid_output <= 1'b1;
                    internal_done <= 1'b1;
                    state <= STATE_WAIT_FOR_OP;
                end else if (memory_read_output == 32'd0) begin
                    state <= STATE_OUTPUT2;
                end else begin
                    internal_result <= memory_read_output;
                    internal_valid_output <= 1'b1;
                    state <= STATE_OUTPUT4;
                end
            end

            /* This state waits for the read request to process and makes
             * valid_output low.
             */
            STATE_OUTPUT4: begin
                state <= STATE_OUTPUT5;
                internal_valid_output <= 1'b0;
            end

            /* This state sets valid_output high and outputs the read output.
             * It also decrements the memory address. If the memory address is
             * outside the word width, the operation is over. Otherwise, go to
             * state 4.
             */
            STATE_OUTPUT5: begin
                internal_result <= memory_read_output;
                internal_valid_output <= 1'b1;
                memory_address <= memory_address - 1;
                if (memory_address <= src1_address_capture * word_width) begin
                    internal_done <= 1'b1;
                    state <= STATE_WAIT_FOR_OP;
                end else begin
                    state <= STATE_OUTPUT4;
                end
            end


            /* This state requests to read from src1_address * word_width.
             */
            STATE_IS_ZERO: begin
                memory_address <= src1_address_capture * word_width;
                state <= STATE_IS_ZERO2;
            end

            /* This state waits for the read request to process.
             */
            STATE_IS_ZERO2: begin
                state <= STATE_IS_ZERO3;
            end

            /* This state checks if the read output is zero. If it is not,
             * result is zero and the operation is over. If the memory address
             * is outside the bounds, the result is one and the operation is
             * over. If neither case is true, increment the memory address and
             * go back to state 2.
             */
            STATE_IS_ZERO3: begin
                if (memory_read_output != 32'd0) begin
                    internal_done <= 1'b1;
                    internal_valid_output <= 1'b1;
                    internal_result <= 32'd0;
                    state <= STATE_WAIT_FOR_OP;
                end else if (memory_address >= src1_address_capture
                                             * word_width
                                             + word_width - 1) begin
                    internal_done <= 1'b1;
                    internal_valid_output <= 1'b1;
                    internal_result <= 32'd1;
                    state <= STATE_WAIT_FOR_OP;
                end else begin
                    memory_address <= memory_address + 1;
                    state <= STATE_IS_ZERO2;
                end
            end

            default: begin
            end
            endcase
        end
    end
endmodule
