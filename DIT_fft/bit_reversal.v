`timescale 1ns / 1ps

module bit_reversal (
    input  wire        clk,
    input  wire        rst_n,

    input  wire        input_valid_br,
    input  wire [15:0] sample_in_br,

    output reg         reorder_done,

    input  wire [7:0]  read_addr,
    output wire [15:0] sample_out_br
);

    localparam DATA_WIDTH = 16;
    localparam N          = 256;
    localparam ADDR_WIDTH = 8;

    reg [DATA_WIDTH-1:0] fft_mem [0:N-1];

    reg [ADDR_WIDTH-1:0] input_count;

    integer i;
    reg [ADDR_WIDTH-1:0] temp_addr;

    // Reverse the bits of an address
    always @(*) begin
        temp_addr = {ADDR_WIDTH{1'b0}};

        for (i = 0; i < ADDR_WIDTH; i = i + 1)
            temp_addr[i] = input_count[ADDR_WIDTH-1-i];
    end

    // Write incoming samples in bit-reversed order
    always @(posedge clk) begin
        if (!rst_n) begin
            input_count  <= 0;
            reorder_done <= 1'b0;
        end
        else if (input_valid_br && !reorder_done) begin
            fft_mem[temp_addr] <= sample_in_br;

            if (input_count == N-1) begin
                reorder_done <= 1'b1;
            end
            else begin
                input_count <= input_count + 1'b1;
            end
        end
    end

    // Read samples in the order required by the FFT stages
    assign sample_out_br = fft_mem[read_addr];

endmodule
