`timescale 1ns/1ps

module fft_buffer #(
    parameter FFT_SIZE   = 16,
    parameter DATA_WIDTH = 12
)(
    input  wire                     clk,
    input  wire                     rst_n,

    // Write side
    input  wire [DATA_WIDTH-1:0]    filtered_data,
    input  wire                     filtered_valid,

    // Read side
    input  wire                     buffer_read_en,
    input  wire [$clog2(FFT_SIZE)-1:0] buffer_addr,
    output reg  [DATA_WIDTH-1:0]    buffer_data,

    // Frame status
    output reg                     fft_frame_valid
);

    reg [DATA_WIDTH-1:0] fft_buffer [0:FFT_SIZE-1];

    reg [$clog2(FFT_SIZE)-1:0] sample_count;

    integer i;

    always @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            sample_count    <= 0;
            fft_frame_valid <= 1'b0;
            buffer_data     <= 0;

            for (i = 0; i < FFT_SIZE; i = i + 1)
                fft_buffer[i] <= 0;

        end

        else begin

            // Default
            fft_frame_valid <= 1'b0;

            //-----------------------------------------
            // WRITE FILTERED SAMPLE
            //-----------------------------------------

            if (filtered_valid) begin

                fft_buffer[sample_count] <= filtered_data;

                if (sample_count == FFT_SIZE-1) begin
                    sample_count    <= 0;
                    fft_frame_valid <= 1'b1;
                end
                else begin
                    sample_count <= sample_count + 1'b1;
                end

            end

            //-----------------------------------------
            // READ FFT SAMPLE
            //-----------------------------------------

            if (buffer_read_en) begin
                buffer_data <= fft_buffer[buffer_addr];
            end

        end

    end

endmodule