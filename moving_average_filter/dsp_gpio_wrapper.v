
`timescale 1ns / 1ps

module dsp_gpio_wrapper #(
    parameter GPIO_WIDTH = 17
)(
    input  wire                  clk,
    input  wire                  rst_n,

    input  wire [GPIO_WIDTH-1:0] gpio_out,
    output wire [GPIO_WIDTH-1:0] gpio_in
);

    wire [15:0] sample_in;
    wire        sample_valid;

    wire [15:0] filtered_sample;
    wire        filtered_valid;

    assign sample_in    = gpio_out[15:0];
    assign sample_valid = gpio_out[16];

    moving_average #(
        .DATA_WIDTH(16),
        .N_f(12)
    ) filter_inst (
        .clk          (clk),
        .rst_n        (rst_n),
        .sample_in    (sample_in),
        .sample_valid (sample_valid),
        .sample_out   (filtered_sample),
        .output_valid (filtered_valid)
    );

    wire        fft_busy;
    wire        fft_done;

    wire signed [15:0] fft_real;
    wire signed [15:0] fft_imag;
    wire        [16:0] fft_magnitude_out;

    wire [7:0] fft_output_addr;

    wire fft_start = 1'b0;
    assign fft_output_addr = 8'd0;

    fft_top #(
        .N(256),
        .DATA_WIDTH(16),
        .COEFF_WIDTH(16),
        .FRAC_BITS(15),
        .SCALE_PER_STAGE(1)
    ) fft_inst (
        .clk              (clk),
        .rst_n            (rst_n),
        .sample_in_fft    (filtered_sample),
        .input_valid      (filtered_valid),
        .start            (fft_start),
        .output_addr      (fft_output_addr),
        .busy             (fft_busy),
        .done             (fft_done),
        .fft_real         (fft_real),
        .fft_imag         (fft_imag),
        .fft_magnitude_out(fft_magnitude_out)
    );

    assign gpio_in[15:0] = filtered_sample;
    assign gpio_in[16]   = filtered_valid;

endmodule
