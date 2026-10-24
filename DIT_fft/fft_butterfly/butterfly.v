`timescale 1ns / 1ps

module dit_fft_butterfly (
    input  wire signed [15:0] a_real,
    input  wire signed [15:0] a_imag,
    input  wire signed [15:0] b_real,
    input  wire signed [15:0] b_imag,

    // Twiddle factor: W = wr + j*wi
    input  wire signed [15:0] wr,
    input  wire signed [15:0] wi,

    // Butterfly outputs have one extra bit for addition growth
    output wire signed [16:0] x_real,
    output wire signed [16:0] x_imag,
    output wire signed [16:0] y_real,
    output wire signed [16:0] y_imag
);

    localparam DATA_WIDTH  = 16;
    localparam COEFF_WIDTH = 16;
    localparam FRAC_BITS   = 15;
    localparam PROD_WIDTH  = DATA_WIDTH + COEFF_WIDTH;
    localparam SUM_WIDTH   = PROD_WIDTH + 1;

    // Complex multiplication: T = B * W
    wire signed [PROD_WIDTH-1:0] p1;
    wire signed [PROD_WIDTH-1:0] p2;
    wire signed [PROD_WIDTH-1:0] p3;
    wire signed [PROD_WIDTH-1:0] p4;

    assign p1 = b_real * wr;
    assign p2 = b_imag * wi;
    assign p3 = b_real * wi;
    assign p4 = b_imag * wr;

    // Keep full precision during multiplication and addition
    wire signed [SUM_WIDTH-1:0] t_real_full;
    wire signed [SUM_WIDTH-1:0] t_imag_full;

    assign t_real_full = $signed(p1) - $signed(p2);
    assign t_imag_full = $signed(p3) + $signed(p4);

    // Convert fixed-point product back to the input scale
    wire signed [SUM_WIDTH-1:0] t_real;
    wire signed [SUM_WIDTH-1:0] t_imag;

    assign t_real = t_real_full >>> FRAC_BITS;
    assign t_imag = t_imag_full >>> FRAC_BITS;

    // DIT butterfly: X = A + T, Y = A - T
    assign x_real = a_real + t_real;
    assign x_imag = a_imag + t_imag;

    assign y_real = a_real - t_real;
    assign y_imag = a_imag - t_imag;

endmodule
