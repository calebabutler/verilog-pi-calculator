
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
