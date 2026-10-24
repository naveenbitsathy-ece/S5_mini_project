`timescale 1ns / 1ps

module tb_fft;

    localparam integer N = 256;
    localparam integer DATA_WIDTH = 16;
    localparam integer FS_HZ = 1000;
    localparam integer CLK_PERIOD = 10;

    reg clk;
    reg rst_n;

    // Moving-average filter input interface
    reg  [DATA_WIDTH-1:0] sample_in;
    reg                   sample_valid;

    // Moving-average filter output interface
    wire [DATA_WIDTH-1:0] sample_out;
    wire                  output_valid;

    // FFT control/output interface
    reg                   start;
    reg  [7:0]             output_addr;
    wire                  busy;
    wire                  done;
    wire signed [15:0]     fft_real;
    wire signed [15:0]     fft_imag;
    wire [16:0]            fft_magnitude;

    // Test data and report variables
    reg [DATA_WIDTH-1:0] samples [0:N-1];
    integer i;
    integer wait_cycles;
    integer fd_bins;
    integer fd_trace;
    integer fd_report;

    // Report/plot signals requested:
    // fft_bin is the selected output address.
    wire [7:0] fft_bin = output_addr;
    // The FFT buffer signal here represents the filtered sample stream
    // presented to fft_top. It is not an internal RAM probe.
    wire [DATA_WIDTH-1:0] fft_buffer = sample_out;
    // Frequency metadata for the selected bin: k*Fs/N.
    wire [31:0] fft_frequency = (output_addr * FS_HZ) / N;

    // ---------------------------------------------------------
    // Clock: 100 MHz
    // ---------------------------------------------------------
    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // ---------------------------------------------------------
    // Moving-average filter DUT
    // Uses the parameter names from the user's moving_average RTL.
    // ---------------------------------------------------------
    moving_average #(
        .DATA_WIDTH(DATA_WIDTH),
        .N_f(12)
    ) u_moving_average (
        .clk(clk),
        .rst_n(rst_n),
        .sample_in(sample_in),
        .sample_valid(sample_valid),
        .sample_out(sample_out),
        .output_valid(output_valid)
    );

    // ---------------------------------------------------------
    // FFT DUT
    // ---------------------------------------------------------
    fft_top #(
        .N(N),
        .DATA_WIDTH(DATA_WIDTH),
        .COEFF_WIDTH(16),
        .FRAC_BITS(15),
        .SCALE_PER_STAGE(1)
    ) u_fft (
        .clk(clk),
        .rst_n(rst_n),
        .sample_in_fft(sample_out),
        .input_valid(output_valid),
        .start(start),
        .output_addr(output_addr),
        .busy(busy),
        .done(done),
        .fft_real(fft_real),
        .fft_imag(fft_imag),
        .fft_magnitude_out(fft_magnitude)
    );

    // ---------------------------------------------------------
    // Waveform dump: add tb_fft.vcd to GTKWave or another viewer.
    // ---------------------------------------------------------
    initial begin
        $dumpfile("tb_fft.vcd");
        $dumpvars(0, tb_fft);
    end

    // ---------------------------------------------------------
    // CSV and text report files
    // ---------------------------------------------------------
    initial begin
        fd_bins   = $fopen("fft_output_bins.csv", "w");
        fd_trace  = $fopen("fft_signal_trace.csv", "w");
        fd_report = $fopen("fft_simulation_report.txt", "w");

        if (fd_bins == 0 || fd_trace == 0 || fd_report == 0) begin
            $display("ERROR: Unable to open report output files.");
            $finish;
        end

        $fwrite(fd_bins, "fft_bin,fft_real,fft_imag,fft_frequency_hz,fft_magnitude\n");
        $fwrite(fd_trace, "time_ns,clk,rst_n,sample_in,sample_valid,sample_out,output_valid,fft_real,fft_imag,fft_bin,fft_buffer,fft_frequency,fft_magnitude,busy,done,start\n");
        $fwrite(fd_report, "FFT + Moving Average Testbench Report\n");
        $fwrite(fd_report, "FFT size: %0d\nSampling frequency: %0d Hz\nClock period: %0d ns\nMoving-average window: 12\n", N, FS_HZ, CLK_PERIOD);
        $fwrite(fd_report, "Input pattern: baseline 2000; sample 0=166, sample 1=420, sample 2=673\n");
        $fwrite(fd_report, "Captured signals: clk, rst_n, sample_in, sample_valid, sample_out, output_valid, fft_real, fft_imag, fft_bin, fft_buffer, fft_frequency, fft_magnitude\n");
    end

    // Trace the requested major signals on every clock edge.
    always @(posedge clk) begin
        if (fd_trace != 0) begin
            $fwrite(fd_trace, "%0t,%0b,%0b,%0d,%0b,%0d,%0b,%0d,%0d,%0d,%0d,%0d,%0d,%0b,%0b,%0b\n",
                $time, clk, rst_n, sample_in, sample_valid, sample_out,
                output_valid, $signed(fft_real), $signed(fft_imag),
                fft_bin, fft_buffer, fft_frequency, fft_magnitude,
                busy, done, start);
        end
    end

    // ---------------------------------------------------------
    // Test sequence
    // ---------------------------------------------------------
    initial begin
        rst_n       = 1'b0;
        sample_in   = {DATA_WIDTH{1'b0}};
        sample_valid = 1'b0;
        start       = 1'b0;
        output_addr = 8'd0;

        // Example stimulus: mostly DC with first three samples changed.
        for (i = 0; i < N; i = i + 1)
            samples[i] = 16'd2000;

        samples[0] = 16'd166;
        samples[1] = 16'd420;
        samples[2] = 16'd673;

        repeat (4) @(negedge clk);
        rst_n = 1'b1;
        repeat (2) @(negedge clk);

        $display("[%0t] Sending %0d samples through moving-average filter", $time, N);

        // Drive one sample-valid pulse per input sample.
        for (i = 0; i < N; i = i + 1) begin
            @(negedge clk);
            sample_in    = samples[i];
            sample_valid = 1'b1;
            @(negedge clk);
            sample_valid = 1'b0;
        end

        @(negedge clk);
        sample_in = 0;
        $display("[%0t] Input stimulus complete", $time);

        // Assert start for designs that require an explicit start.
        // If the FFT controller auto-starts on a full 256-sample frame,
        // this pulse should be harmless only if that controller supports it.
        @(negedge clk);
        start = 1'b1;
        @(negedge clk);
        start = 1'b0;

        // Wait for FFT completion with timeout.
        wait_cycles = 0;
        while (done !== 1'b1 && wait_cycles < 20000) begin
            @(negedge clk);
            wait_cycles = wait_cycles + 1;
        end

        if (done !== 1'b1) begin
            $display("ERROR: FFT done did not assert before timeout.");
            $fwrite(fd_report, "RESULT: FAIL - FFT done timeout after %0d cycles\n", wait_cycles);
            close_reports;
            $finish;
        end

        $display("[%0t] FFT completed after %0d wait cycles", $time, wait_cycles);
        $fwrite(fd_report, "RESULT: done asserted after %0d wait cycles\n", wait_cycles);

        // Read and log every output bin.
        for (i = 0; i < N; i = i + 1) begin
            @(negedge clk);
            output_addr = i[7:0];
            #1;
            $fwrite(fd_bins, "%0d,%0d,%0d,%0d,%0d\n",
                i, $signed(fft_real), $signed(fft_imag),
                (i * FS_HZ) / N, fft_magnitude);

            if (i < 16)
                $display("Bin %0d: Real=%0d Imag=%0d Frequency=%0d Hz Magnitude=%0d",
                    i, $signed(fft_real), $signed(fft_imag),
                    (i * FS_HZ) / N, fft_magnitude);
        end

        $fwrite(fd_report, "Output bins recorded: %0d\n", N);
        $fwrite(fd_report, "NOTE: Numerical FFT correctness requires comparison against a trusted reference.\n");
        $display("Reports written: fft_signal_trace.csv, fft_output_bins.csv, fft_simulation_report.txt");
        close_reports;
        $finish;
    end

    // ---------------------------------------------------------
    // Report file closure task
    // ---------------------------------------------------------
    task close_reports;
        begin
            if (fd_bins != 0)   $fclose(fd_bins);
            if (fd_trace != 0)  $fclose(fd_trace);
            if (fd_report != 0) $fclose(fd_report);
        end
    endtask

    // ---------------------------------------------------------
    // Global simulation timeout
    // ---------------------------------------------------------
    initial begin
        #5000000;
        $display("ERROR: Global simulation timeout!");
        if (fd_report != 0) begin
            $fwrite(fd_report, "RESULT: FAIL - global simulation timeout\n");
            $fclose(fd_report);
        end
        if (fd_bins != 0)  $fclose(fd_bins);
        if (fd_trace != 0) $fclose(fd_trace);
        $finish;
    end

endmodule
