`timescale 1ns/1ps

module butterfly #(
    parameter DATA_WIDTH = 12,
    parameter TWIDDLE_WIDTH = 16,
    parameter OUTPUT_WIDTH = DATA_WIDTH + TWIDDLE_WIDTH
)(
    input  wire                         clk,
    input  wire                         rst_n,

    // Complex input A
    input  wire signed [DATA_WIDTH-1:0] A_real,
    input  wire signed [DATA_WIDTH-1:0] A_imag,

    // Complex input B
    input  wire signed [DATA_WIDTH-1:0] B_real,
    input  wire signed [DATA_WIDTH-1:0] B_imag,

    // Complex twiddle factor W
    input  wire signed [TWIDDLE_WIDTH-1:0] W_real,
    input  wire signed [TWIDDLE_WIDTH-1:0] W_imag,

    input  wire valid_in,

    // Complex output X
    output reg signed [OUTPUT_WIDTH:0] X_real,
    output reg signed [OUTPUT_WIDTH:0] X_imag,

    // Complex output Y
    output reg signed [OUTPUT_WIDTH:0] Y_real,
    output reg signed [OUTPUT_WIDTH:0] Y_imag,

    output reg valid_out
);

    //------------------------------------------------
    // Intermediate multiplication
    //------------------------------------------------

    reg signed [DATA_WIDTH+TWIDDLE_WIDTH-1:0] mult1;
    reg signed [DATA_WIDTH+TWIDDLE_WIDTH-1:0] mult2;
    reg signed [DATA_WIDTH+TWIDDLE_WIDTH-1:0] mult3;
    reg signed [DATA_WIDTH+TWIDDLE_WIDTH-1:0] mult4;

    reg signed [DATA_WIDTH+TWIDDLE_WIDTH:0] BW_real;
    reg signed [DATA_WIDTH+TWIDDLE_WIDTH:0] BW_imag;

    //------------------------------------------------
    // Butterfly
    //
    // BW = B × W
    //
    // BW_real = B_real*W_real - B_imag*W_imag
    //
    // BW_imag = B_real*W_imag + B_imag*W_real
    //
    // X = A + BW
    // Y = A - BW
    //------------------------------------------------

    always @(posedge clk or negedge rst_n)
    begin

        if (!rst_n)
        begin

            mult1 = 0;
            mult2 = 0;
            mult3 = 0;
            mult4 = 0;

            BW_real = 0;
            BW_imag = 0;

            X_real <= 0;
            X_imag <= 0;

            Y_real <= 0;
            Y_imag <= 0;

            valid_out <= 1'b0;
        end

        else
        begin

            valid_out <= 1'b0;

            if (valid_in)
            begin

                //----------------------------------------
                // Complex multiplication
                //----------------------------------------

                mult1 = B_real * W_real;
                mult2 = B_imag * W_imag;

                mult3 = B_real * W_imag;
                mult4 = B_imag * W_real;

                BW_real = mult1 - mult2;
                BW_imag = mult3 + mult4;

                //----------------------------------------
                // Butterfly addition
                //----------------------------------------

                X_real <= A_real + BW_real;
                X_imag <= A_imag + BW_imag;

                //----------------------------------------
                // Butterfly subtraction
                //----------------------------------------

                Y_real <= A_real - BW_real;
                Y_imag <= A_imag - BW_imag;

                valid_out <= 1'b1;

            end

        end

    end

endmodule