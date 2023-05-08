
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

#include "Vpi_calculator.h"
#include "verilated.h"

int main(int argc, char** argv) {
    const unsigned int REQUEST_DIGITS = 1000000;
    bool is_first_run = true;

    Verilated::commandArgs(argc, argv);
    Vpi_calculator* top = new Vpi_calculator;

    top->clock = 0;
    top->reset_n = 0;
    top->start = 0;
    top->digits = REQUEST_DIGITS;

    while (!Verilated::gotFinish()) {
        top->eval();
        if (is_first_run) {
            top->reset_n = 1;
            top->start = 1;
            is_first_run = false;
        }
        top->clock = !top->clock;
        if (top->clock) {
            if (top->valid_output) {
                VL_PRINTF("%09d\n", top->pi_digit);
                if (top->done) {
                    break;
                }
            }
        }
    }

    top->final();
    delete top;
    return 0;
}
