`timescale 1ns / 1ps

module fft_buffer (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [15:0] sample_in_buff,
    input  wire        input_valid_buff,

    output reg  [7:0]  sample_count,
    output reg         buffer_full
);

    localparam DATA_WIDTH = 16;
    localparam N_b          = 256;
    localparam ADDR_WIDTH = 8;

    reg [DATA_WIDTH-1:0] fft_mem [0:N_b-1];

    integer i;

    always @(posedge clk) begin
        if (!rst_n) begin
            sample_count <= 0;
            buffer_full  <= 1'b0;

            for (i = 0; i < N_b; i = i + 1)
                fft_mem[i] <= {DATA_WIDTH{1'b0}};
        end
        else begin
            if (input_valid_buff && !buffer_full) begin
                fft_mem[sample_count] <= sample_in_buff;

                if (sample_count == N_b-1) begin
                    buffer_full <= 1'b1;
                end
                else begin
                    sample_count <= sample_count + 1'b1;
                end
            end
        end
    end

endmodule
