clc;
clear;
close all;

% INPUT SIGNAL SETTINGS

N = 256;             % Number of samples
Fs = 1000;           % Sampling frequency in Hz
A1 = 200;            % Amplitude of first sine wave
f1 = 1400;              % Frequency of first sine wave
A2 = 200;             % Amplitude of second sine wave
f2 = 290;             % Frequency of second sine wave
DC = 2000;            % DC offset
windowSize = 12;

n = (0:N-1)';
t = n/Fs;
x = DC + A1*sin(2*pi*f1*t) + A2*sin(2*pi*f2*t);
samples = round(x);
samples = double(samples(:));

if any(samples < 0) || any(samples > 65535)
    error('Input samples must be between 0 and 65535.');
end
fprintf('Generated %d input samples.\n', N);

% MATLAB REFERENCE MOVING-AVERAGE FILTER
reference = zeros(N,1);
for k = 1:N
    firstIndex = max(1, k-windowSize+1);
    reference(k) = floor(sum(samples(firstIndex:k))/windowSize);
end

% UART COMMUNICATION WITH ZEDBOARD
portName = 'COM3';
baudRate = 115200;
s = serial(portName, 'BaudRate', baudRate, 'DataBits', 8, ...
    'Parity', 'none', 'StopBits', 1, 'FlowControl', 'none', 'Timeout', 5);

try
    fopen(s);
    flushinput(s);
    fprintf('UART connected: %s\n', portName);
    fprintf('Flushing FPGA moving-average filter delay line with zeros...\n');

    for flush_idx = 1:16
        fwrite(s, uint8([0; 0]), 'uint8');
        response = fread(s, 2, 'uint8');
        if numel(response) ~= 2
            error('UART timeout during warm-up at zero sample %d.', flush_idx);
        end
    end

    fprintf('Sending samples to FPGA...\n');
    fpga_output = zeros(N,1);

    for k = 1:N
        sample = uint16(samples(k));
        lowByte = uint8(bitand(sample, 255));
        highByte = uint8(bitshift(sample, -8));
        fwrite(s, [lowByte; highByte], 'uint8');

        response = fread(s, 2, 'uint8');
        if numel(response) ~= 2
            error('UART timeout at sample %d. Check COM3 and Vitis.', k);
        end

        fpga_output(k) = double(response(1)) + 256*double(response(2));
        if fpga_output(k) == 65535
            error('FPGA error marker received at sample %d.', k);
        end
        if mod(k,32) == 0 || k == N
            fprintf('Received %d / %d samples\n', k, N);
        end
    end

    fclose(s);
    delete(s);
    clear s;
catch ME
    if strcmp(get(s,'Status'),'open')
        fclose(s);
    end
    delete(s);
    clear s;
    rethrow(ME);
end

fprintf('FPGA processing completed.\n');

% COMPARE MATLAB AND FPGA MOVING-AVERAGE OUTPUTS
errorValues = fpga_output - reference;
maxError = max(abs(errorValues));
mismatchCount = sum(errorValues ~= 0);

fprintf('\nMaximum absolute error: %g\n', maxError);
fprintf('Number of mismatches: %d\n', mismatchCount);
if mismatchCount == 0
    fprintf('PASS: All FPGA outputs match MATLAB reference.\n');
else
    fprintf('CHECK: Some FPGA outputs do not match.\n');
end

% PLOTS (not embedded in Excel)
figure;
plot(t, samples, 'b-', 'LineWidth', 1.2);
hold on;
plot(t, reference, 'g--', 'LineWidth', 1.5);
plot(t, fpga_output, 'r:', 'LineWidth', 1.5);
grid on;
xlabel('Time (seconds)');
ylabel('Amplitude');
title('Moving Average Filter: MATLAB and FPGA');
legend('Input Signal', 'MATLAB Reference', 'FPGA Output', 'Location', 'best');

figure;
plot(t, errorValues, 'k-', 'LineWidth', 1.2);
grid on;
xlabel('Time (seconds)');
ylabel('Error');
title('FPGA Output Error');

% EXCEL OUTPUT: ONLY Results AND Summary SHEETS.
% No Detailed_FFT_Spectrum sheet, charts, colors, or formatting.
outputFolder = uigetdir(pwd, ...
    'Select folder for DSP Excel results');

if isequal(outputFolder, 0)

    disp('Excel saving cancelled.');

else

    excelFile = fullfile(outputFolder, ...
        'DSP_FPGA_Results.xlsx');

end 

fft_bin = (0:N-1)';
fft_frequency = fft_bin * Fs / N;
fft_buffer_data = double(fpga_output(:));

% This is a MATLAB FFT calculated from FPGA-filtered samples,
% not an FFT result received from the FPGA FFT core.
fft_complex_scaled = fft(fft_buffer_data, N) / N;
fft_magnitude = round(abs(fft_complex_scaled));

headers = {
    'Sample Index', 'Time (s)', 'Input Sample', 'MATLAB Reference', ...
    'FPGA Output', 'Error', 'FFT Bin', 'FFT Buffer', ...
    'FFT Frequency (Hz)', 'FFT Magnitude'
};

results = [(1:N)', t, samples, reference, fpga_output, errorValues, ...
    fft_bin, fft_buffer_data, fft_frequency, fft_magnitude];

xlswrite(excelFile, headers, 'Results', 'A1');
xlswrite(excelFile, results, 'Results', 'A2');

if mismatchCount == 0
    comparisonResult = 'PASS';
else
    comparisonResult = 'CHECK';
end

summary = {
    'Parameter', 'Value';
    'Sample Count', N;
    'Sampling Frequency (Hz)', Fs;
    'DC Offset', DC;
    'Amplitude 1', A1;
    'Frequency 1 (Hz)', f1;
    'Amplitude 2', A2;
    'Frequency 2 (Hz)', f2;
    'Moving Average Window', windowSize;
    'Maximum Absolute Error', maxError;
    'Mismatch Count', mismatchCount;
    'Comparison Result', comparisonResult;
    'FFT Size', N;
    'FFT Frequency Resolution (Hz)', Fs/N;
    'FFT Nyquist Frequency (Hz)', Fs/2;
    'FFT Data Source', 'MATLAB FFT from FPGA moving-average outputs';
    'MATLAB Reference FFT', 'Calculated from FPGA output data';
    'FFT Output Status', 'MATLAB-calculated; not read from FPGA FFT hardware'
};

xlswrite(excelFile, summary, 'Summary', 'A1');
fprintf('\nResults saved in:\n%s\n', excelFile);
fprintf('Excel sheets: Results and Summary only.\n');
fprintf('No Detailed_FFT_Spectrum sheet, charts, colors, or formatting added.\n');
