`timescale 1ns / 1ps

module fft_twiddle_rom (
    input  wire [6:0] addr,
    output wire signed [15:0] twiddle_real,
    output wire signed [15:0] twiddle_imag
);

    localparam N           = 256;
    localparam ADDR_WIDTH  = 7;
    localparam COEFF_WIDTH = 16;

    reg signed [COEFF_WIDTH-1:0] real_rom [0:N/2-1];
    reg signed [COEFF_WIDTH-1:0] imag_rom [0:N/2-1];

    initial begin
        $readmemh("twiddle256_real.mem", real_rom);
        $readmemh("twiddle256_img.mem",  imag_rom);
    end

    assign twiddle_real = real_rom[addr];
    assign twiddle_imag = imag_rom[addr];

endmodule
