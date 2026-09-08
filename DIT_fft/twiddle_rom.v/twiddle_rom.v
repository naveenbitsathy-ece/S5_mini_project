`timescale 1ns/1ps

module twiddle_rom #(
    parameter TWIDDLE_WIDTH = 16
)(
    input  wire [2:0] addr,

    output reg signed [TWIDDLE_WIDTH-1:0] twiddle_real,
    output reg signed [TWIDDLE_WIDTH-1:0] twiddle_imag
);

    always @(*) begin

        case (addr)

            // W16^0 = 1.0000 - j0
            3'd0: begin
                twiddle_real = 16'sd32767;
                twiddle_imag = 16'sd0;
            end

            // W16^1 = 0.9239 - j0.3827
            3'd1: begin
                twiddle_real = 16'sd30273;
                twiddle_imag = -16'sd12539;
            end

            // W16^2 = 0.7071 - j0.7071
            3'd2: begin
                twiddle_real = 16'sd23170;
                twiddle_imag = -16'sd23170;
            end

            // W16^3 = 0.3827 - j0.9239
            3'd3: begin
                twiddle_real = 16'sd12539;
                twiddle_imag = -16'sd30273;
            end

            // W16^4 = 0 - j1
            3'd4: begin
                twiddle_real = 16'sd0;
                twiddle_imag = -16'sd32768;
            end

            // W16^5 = -0.3827 - j0.9239
            3'd5: begin
                twiddle_real = -16'sd12539;
                twiddle_imag = -16'sd30273;
            end

            // W16^6 = -0.7071 - j0.7071
            3'd6: begin
                twiddle_real = -16'sd23170;
                twiddle_imag = -16'sd23170;
            end

            // W16^7 = -0.9239 - j0.3827
            3'd7: begin
                twiddle_real = -16'sd30273;
                twiddle_imag = -16'sd12539;
            end

            default: begin
                twiddle_real = 16'sd0;
                twiddle_imag = 16'sd0;
            end

        endcase

    end

endmodule