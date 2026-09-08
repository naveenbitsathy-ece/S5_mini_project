`timescale 1ns/1ps

module butterfly_tb;

    //------------------------------------------------
    // Parameters
    //------------------------------------------------

    parameter DATA_WIDTH = 12;
    parameter TWIDDLE_WIDTH = 16;
    parameter OUTPUT_WIDTH = DATA_WIDTH + TWIDDLE_WIDTH;

    //------------------------------------------------
    // DUT signals
    //------------------------------------------------

    reg clk;
    reg rst_n;

    reg signed [DATA_WIDTH-1:0] A_real;
    reg signed [DATA_WIDTH-1:0] A_imag;

    reg signed [DATA_WIDTH-1:0] B_real;
    reg signed [DATA_WIDTH-1:0] B_imag;

    reg signed [TWIDDLE_WIDTH-1:0] W_real;
    reg signed [TWIDDLE_WIDTH-1:0] W_imag;

    reg valid_in;

    wire signed [OUTPUT_WIDTH:0] X_real;
    wire signed [OUTPUT_WIDTH:0] X_imag;

    wire signed [OUTPUT_WIDTH:0] Y_real;
    wire signed [OUTPUT_WIDTH:0] Y_imag;

    wire valid_out;

    integer errors;

    //------------------------------------------------
    // DUT
    //------------------------------------------------

    butterfly #(
        .DATA_WIDTH(DATA_WIDTH),
        .TWIDDLE_WIDTH(TWIDDLE_WIDTH),
        .OUTPUT_WIDTH(OUTPUT_WIDTH)
    ) uut (

        .clk(clk),
        .rst_n(rst_n),

        .A_real(A_real),
        .A_imag(A_imag),

        .B_real(B_real),
        .B_imag(B_imag),

        .W_real(W_real),
        .W_imag(W_imag),

        .valid_in(valid_in),

        .X_real(X_real),
        .X_imag(X_imag),

        .Y_real(Y_real),
        .Y_imag(Y_imag),

        .valid_out(valid_out)
    );

    //------------------------------------------------
    // Clock
    //------------------------------------------------

    initial
        clk = 1'b0;

    always #5 clk = ~clk;

    //------------------------------------------------
    // Test
    //------------------------------------------------

    initial
    begin

        errors = 0;

        A_real = 0;
        A_imag = 0;

        B_real = 0;
        B_imag = 0;

        W_real = 0;
        W_imag = 0;

        valid_in = 0;

        //------------------------------------------------
        // Reset
        //------------------------------------------------

        rst_n = 0;

        #20;

        rst_n = 1;

        //------------------------------------------------
        // Test 1
        //
        // A = 10 + j0
        // B = 5 + j0
        // W = 1 + j0
        //
        // X = 15 + j0
        // Y = 5 + j0
        //------------------------------------------------

        @(negedge clk);

        A_real = 12'sd10;
        A_imag = 12'sd0;

        B_real = 12'sd5;
        B_imag = 12'sd0;

        W_real = 16'sd1;
        W_imag = 16'sd0;

        valid_in = 1'b1;

        @(posedge clk);

        #1;

        valid_in = 1'b0;

        //------------------------------------------------
        // Check valid
        //------------------------------------------------

        if (valid_out !== 1'b1)
        begin
            $display("ERROR: valid_out not asserted");
            errors = errors + 1;
        end

        //------------------------------------------------
        // Check X
        //------------------------------------------------

        if (X_real !== 15)
        begin
            $display(
                "ERROR: X_real = %0d, Expected = 15",
                X_real
            );

            errors = errors + 1;
        end
        else
            $display("PASS: X_real = %0d", X_real);

        if (X_imag !== 0)
        begin
            $display(
                "ERROR: X_imag = %0d, Expected = 0",
                X_imag
            );

            errors = errors + 1;
        end
        else
            $display("PASS: X_imag = %0d", X_imag);

        //------------------------------------------------
        // Check Y
        //------------------------------------------------

        if (Y_real !== 5)
        begin
            $display(
                "ERROR: Y_real = %0d, Expected = 5",
                Y_real
            );

            errors = errors + 1;
        end
        else
            $display("PASS: Y_real = %0d", Y_real);

        if (Y_imag !== 0)
        begin
            $display(
                "ERROR: Y_imag = %0d, Expected = 0",
                Y_imag
            );

            errors = errors + 1;
        end
        else
            $display("PASS: Y_imag = %0d", Y_imag);

        //------------------------------------------------
        // Final result
        //------------------------------------------------

        #20;

        $display("");
        $display("========================================");

        if (errors == 0)
        begin
            $display("      BUTTERFLY TEST PASSED");
            $display("      NO ERRORS");
        end
        else
        begin
            $display("      BUTTERFLY TEST FAILED");
            $display("      ERRORS = %0d", errors);
        end

        $display("========================================");

        $finish;

    end

    //------------------------------------------------
    // Waveform
    //------------------------------------------------

    initial
    begin

        $dumpfile("butterfly.vcd");
        $dumpvars(0, butterfly_tb);

    end

endmodule