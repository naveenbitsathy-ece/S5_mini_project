`timescale 1ns / 1ps

module dit_fft_controller #(
    parameter N               = 256,
    parameter DATA_WIDTH      = 16,
    parameter COEFF_WIDTH     = 16,
    parameter FRAC_BITS       = 15,
    parameter ADDR_WIDTH      = $clog2(N),
    parameter STAGE_WIDTH     = $clog2($clog2(N)+1),
    parameter SCALE_PER_STAGE = 1
)(
    input  wire        clk,
    input  wire        rst_n,

    input  wire        start,
    input  wire [DATA_WIDTH-1:0] sample_in,
    input  wire        input_valid,

    output reg         busy,
    output reg         done,

    input  wire [ADDR_WIDTH-1:0] output_addr,
    output wire signed [DATA_WIDTH-1:0] output_real,
    output wire signed [DATA_WIDTH-1:0] output_imag
);

    reg signed [DATA_WIDTH-1:0] real_mem [0:N-1];
    reg signed [DATA_WIDTH-1:0] imag_mem [0:N-1];

    reg [ADDR_WIDTH-1:0] sample_count;
    reg [ADDR_WIDTH-1:0] group_base;
    reg [ADDR_WIDTH-1:0] j;
    reg [STAGE_WIDTH-1:0] stage;

    reg [ADDR_WIDTH-1:0] half_size;
    reg [ADDR_WIDTH:0]   span; // 9 bits to accommodate span == N (256)
    reg [ADDR_WIDTH-1:0] twiddle_addr;
    reg                  samples_ready;

    wire signed [COEFF_WIDTH-1:0] wr;
    wire signed [COEFF_WIDTH-1:0] wi;

   
    reg input_valid_d;
    always @(posedge clk) begin
        if (!rst_n)
            input_valid_d <= 1'b0;
        else
            input_valid_d <= input_valid;
    end

    wire sample_pulse = input_valid && !input_valid_d;

    // Twiddle factor ROM
    fft_twiddle_rom twiddle_rom (
        .addr(twiddle_addr[ADDR_WIDTH-2:0]),
        .twiddle_real(wr),
        .twiddle_imag(wi)
    );

    // Bit-reverse an input sample index
    function [ADDR_WIDTH-1:0] reverse_bits;
        input [ADDR_WIDTH-1:0] value;
        integer b;
        begin
            for (b = 0; b < ADDR_WIDTH; b = b + 1)
                reverse_bits[b] = value[ADDR_WIDTH-1-b];
        end
    endfunction

    // Stage and twiddle address calculations
    always @(*) begin
        if (stage != 0) begin
            half_size    = {{(ADDR_WIDTH-1){1'b0}}, 1'b1} << (stage - 1'b1);
            span         = {1'b0, half_size} << 1;
            twiddle_addr = j << (ADDR_WIDTH - stage);
        end
        else begin
            half_size    = {ADDR_WIDTH{1'b0}};
            span         = {(ADDR_WIDTH+1){1'b0}};
            twiddle_addr = {ADDR_WIDTH{1'b0}};
        end
    end

    // Butterfly arithmetic module integration
    wire [ADDR_WIDTH-1:0] addr_a = group_base + j;
    wire [ADDR_WIDTH-1:0] addr_b = group_base + j + half_size;

    wire signed [DATA_WIDTH:0] x_real;
    wire signed [DATA_WIDTH:0] x_imag;
    wire signed [DATA_WIDTH:0] y_real;
    wire signed [DATA_WIDTH:0] y_imag;

    dit_fft_butterfly u_butterfly (
        .a_real(real_mem[addr_a]),
        .a_imag(imag_mem[addr_a]),
        .b_real(real_mem[addr_b]),
        .b_imag(imag_mem[addr_b]),
        .wr(wr),
        .wi(wi),
        .x_real(x_real),
        .x_imag(x_imag),
        .y_real(y_real),
        .y_imag(y_imag)
    );

    assign output_real = real_mem[output_addr];
    assign output_imag = imag_mem[output_addr];

    always @(posedge clk) begin
        if (!rst_n) begin
            sample_count  <= 0;
            group_base    <= 0;
            j             <= 0;
            stage         <= 0;
            busy          <= 0;
            done          <= 0;
            samples_ready <= 0;
        end
        else begin
            done <= 1'b0;

            
            if (!busy && sample_pulse) begin
                real_mem[reverse_bits(sample_count)] <= $signed(sample_in);
                imag_mem[reverse_bits(sample_count)] <= 16'sh0000;

                if (sample_count == N-1) begin
                    sample_count  <= 0;
                    samples_ready <= 1'b1;
                end
                else begin
                    sample_count <= sample_count + 1'b1;
                end
            end

         
            if ((start || samples_ready) && !busy) begin
                busy          <= 1'b1;
                stage         <= 1;
                group_base    <= 0;
                j             <= 0;
                samples_ready <= 1'b0;
            end

            if (busy) begin
                if (SCALE_PER_STAGE) begin
                    real_mem[addr_a] <= x_real >>> 1;
                    imag_mem[addr_a] <= x_imag >>> 1;
                    real_mem[addr_b] <= y_real >>> 1;
                    imag_mem[addr_b] <= y_imag >>> 1;
                end
                else begin
                    real_mem[addr_a] <= x_real[DATA_WIDTH-1:0];
                    imag_mem[addr_a] <= x_imag[DATA_WIDTH-1:0];
                    real_mem[addr_b] <= y_real[DATA_WIDTH-1:0];
                    imag_mem[addr_b] <= y_imag[DATA_WIDTH-1:0];
                end

                if (j == half_size - 1'b1) begin
                    j <= 0;

                    if ({1'b0, group_base} + span >= N) begin
                        group_base <= 0;

                        if (stage == ADDR_WIDTH) begin
                            busy  <= 1'b0;
                            done  <= 1'b1;
                            stage <= 0;
                        end
                        else begin
                            stage <= stage + 1'b1;
                        end
                    end
                    else begin
                        group_base <= group_base + span[ADDR_WIDTH-1:0];
                    end
                end
                else begin
                    j <= j + 1'b1;
                end
            end
        end
    end

endmodule
