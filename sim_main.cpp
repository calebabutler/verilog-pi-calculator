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
