%% Analyze uncontrolled current measurement noise
% Loads uncontrolled_current.mat, estimates the current-measurement noise
% distribution, runs a time-domain FFT, and checks possible harmonics.

clear; close all; clc;

scriptDir = fileparts(mfilename("fullpath"));
matFile = fullfile(scriptDir, "uncontrolled_current.mat");
outputDir = fullfile(scriptDir, "uncontrolled_current_analysis");
helperDir = "C:\Users\abuj\OneDrive - ZHAW\Code\Matlab\functions\myfunctions\Control";

if ~isfolder(outputDir)
    mkdir(outputDir);
end

addpath(helperDir);

S = load(matFile);
channels = flattenNumericChannels(S);

[time, current, currentName, timeName] = selectTimeAndCurrent(channels);
[time, current] = cleanAndAlignTimeSeries(time, current);

dt = median(diff(time));
Fs = 1 / dt;
duration = time(end) - time(1);

currentMean = mean(current, "omitnan");
noise = current - currentMean;
noiseDetrended = detrend(noise, "linear");

stats = computeNoiseStats(noise, noiseDetrended, Fs, duration, currentName, timeName);
writetable(struct2table(stats), fullfile(outputDir, "noise_distribution_stats.csv"));

fprintf("\nCurrent channel: %s\n", currentName);
fprintf("Time channel:    %s\n", timeName);
fprintf("Samples:         %d\n", numel(current));
fprintf("Duration:        %.6g s\n", duration);
fprintf("Fs:              %.6g Hz\n", Fs);
fprintf("Mean current:    %.6g A\n", currentMean);
fprintf("Noise std:       %.6g A\n", stats.NoiseStd_A);
fprintf("Noise RMS:       %.6g A\n", stats.NoiseRms_A);

plotTimeAndDistribution(time, current, noiseDetrended, stats, outputDir);

threshold = 0.10;
[detectedFrequencies, detectedAmplitudes, detectedPhases, dcGain] = ...
    fft_analyze_signal(noiseDetrended, Fs, true, threshold, false);
fftFig = gcf;
saveFigure(fftFig, fullfile(outputDir, "fft_analyze_signal_noise"));

fftTable = table( ...
    detectedFrequencies(:), ...
    detectedAmplitudes(:), ...
    detectedPhases(:), ...
    VariableNames=["Frequency_Hz", "Amplitude_A", "Phase_deg"]);
writetable(fftTable, fullfile(outputDir, "fft_detected_peaks.csv"));

fftTopTable = sortrows(fftTable, "Amplitude_A", "descend");
fftTopTable = fftTopTable(1:min(50, height(fftTopTable)), :);
writetable(fftTopTable, fullfile(outputDir, "fft_top_peaks.csv"));

[spectrumTable, harmonicTable, mainsHarmonicTable] = ...
    analyzeHarmonics(noiseDetrended, Fs, detectedFrequencies, detectedAmplitudes);
writetable(spectrumTable, fullfile(outputDir, "fft_single_sided_spectrum.csv"));
writetable(harmonicTable, fullfile(outputDir, "possible_harmonics.csv"));
writetable(mainsHarmonicTable, fullfile(outputDir, "mains_harmonic_check.csv"));

fprintf("\nFFT DC gain from helper: %.6g A\n", dcGain);
fprintf("Detected FFT peaks:      %d\n", height(fftTable));
if ~isempty(harmonicTable) && height(harmonicTable) > 0
    fprintf("Dominant candidate fundamental: %.6g Hz\n", harmonicTable.Fundamental_Hz(1));
end

angleChannel = selectAngleChannel(channels, numel(current), currentName, timeName);
if strlength(angleChannel.Name) > 0
    theta = angleChannel.Value(:);
    theta = theta(1:min(numel(theta), numel(noiseDetrended)));
    r = noiseDetrended(1:numel(theta));

    M = 1024;
    K = 80;
    useFft = true;
    [eBinned, Xout, ord, mag, ph] = angle_based_fft_v3( ...
        theta, r, M, K, useFft, true, true, false, 20, dt, "1sigma", true, 64);
    saveFigure(gcf, fullfile(outputDir, "angle_based_fft_noise"));

    maxOrder = floor(M / 2);
    orderTable = table( ...
        ord(1:maxOrder+1), ...
        mag(1:maxOrder+1), ...
        ph(1:maxOrder+1), ...
        VariableNames=["Order", "Magnitude_A", "Phase_rad"]);
    writetable(orderTable, fullfile(outputDir, "angle_based_fft_orders.csv"));

    save(fullfile(outputDir, "angle_based_fft_workspace.mat"), ...
        "eBinned", "Xout", "ord", "mag", "ph", "angleChannel");
else
    note = "No angle-like vector with the same length as current was found. " + ...
        "Skipped angle_based_fft_v3 order analysis.";
    writelines(note, fullfile(outputDir, "angle_based_fft_skipped.txt"));
    fprintf("\n%s\n", note);
end

save(fullfile(outputDir, "uncontrolled_current_noise_analysis.mat"), ...
    "time", "current", "noise", "noiseDetrended", "Fs", "stats", ...
    "fftTable", "fftTopTable", "spectrumTable", "harmonicTable", ...
    "mainsHarmonicTable", "currentName", "timeName");

fprintf("\nSaved analysis outputs to:\n  %s\n", outputDir);

%% Local helper functions

function channels = flattenNumericChannels(S)
channels = struct("Name", {}, "Value", {});
fields = string(fieldnames(S));
for idx = 1:numel(fields)
    channels = appendNumericChannels(channels, fields(idx), S.(fields(idx)));
end
end

function channels = appendNumericChannels(channels, name, value)
if isnumeric(value) || islogical(value)
    if isvector(value) && numel(value) > 1
        channels(end+1).Name = string(name); %#ok<AGROW>
        channels(end).Value = double(value(:));
    elseif ismatrix(value) && min(size(value)) > 1
        for col = 1:size(value, 2)
            channels(end+1).Name = string(name) + "_col" + col; %#ok<AGROW>
            channels(end).Value = double(value(:, col));
        end
    end
elseif istimetable(value) || istable(value)
    varNames = string(value.Properties.VariableNames);
    for idx = 1:numel(varNames)
        channels = appendNumericChannels(channels, string(name) + "." + varNames(idx), value.(varNames(idx)));
    end
    if istimetable(value)
        channels(end+1).Name = string(name) + ".Time"; %#ok<AGROW>
        channels(end).Value = seconds(value.Properties.RowTimes - value.Properties.RowTimes(1));
    end
elseif isa(value, "timeseries")
    channels = appendNumericChannels(channels, string(name) + ".Time", value.Time);
    channels = appendNumericChannels(channels, string(name) + ".Data", squeeze(value.Data));
elseif isstruct(value)
    subFields = string(fieldnames(value));
    for element = 1:numel(value)
        suffix = "";
        if numel(value) > 1
            suffix = "(" + element + ")";
        end
        for idx = 1:numel(subFields)
            channels = appendNumericChannels( ...
                channels, string(name) + suffix + "." + subFields(idx), value(element).(subFields(idx)));
        end
    end
end
end

function [time, current, currentName, timeName] = selectTimeAndCurrent(channels)
if isempty(channels)
    error("analyzeCurrentNoise:NoNumericChannels", "No numeric vector channels were found in the MAT file.");
end

names = string({channels.Name});
lengths = arrayfun(@(c) numel(c.Value), channels);

timeScore = zeros(size(lengths));
for idx = 1:numel(channels)
    x = channels(idx).Value(:);
    finite = isfinite(x);
    monotonic = nnz(finite) > 2 && all(diff(x(finite)) > 0);
    name = lower(names(idx));
    timeScore(idx) = 5 * any(contains(name, ["time", "tout", "timestamp", "t_"])) + 3 * monotonic;
end

[~, timeIdx] = max(timeScore);
time = channels(timeIdx).Value(:);
timeName = names(timeIdx);

candidateLengths = abs(lengths - numel(time));
currentScore = -candidateLengths;
for idx = 1:numel(channels)
    name = lower(names(idx));
    currentScore(idx) = currentScore(idx) + ...
        10 * any(contains(name, ["current", "amp", "amps", "i_", "i.", "i"]));
    currentScore(idx) = currentScore(idx) - 1000 * (idx == timeIdx);
end

[~, currentIdx] = max(currentScore);
current = channels(currentIdx).Value(:);
currentName = names(currentIdx);

if numel(time) ~= numel(current)
    n = min(numel(time), numel(current));
    warning("analyzeCurrentNoise:LengthMismatch", ...
        "Time and current lengths differ. Truncating both to %d samples.", n);
    time = time(1:n);
    current = current(1:n);
end
end

function [time, x] = cleanAndAlignTimeSeries(time, x)
time = double(time(:));
x = double(x(:));
valid = isfinite(time) & isfinite(x);
time = time(valid);
x = x(valid);

[time, order] = sort(time);
x = x(order);

duplicate = [false; diff(time) <= 0];
time = time(~duplicate);
x = x(~duplicate);

time = time - time(1);
end

function stats = computeNoiseStats(noise, noiseDetrended, Fs, duration, currentName, timeName)
noise = noise(:);
noiseDetrended = noiseDetrended(:);

stats = struct();
stats.CurrentChannel = string(currentName);
stats.TimeChannel = string(timeName);
stats.NumSamples = numel(noise);
stats.Duration_s = duration;
stats.SampleRate_Hz = Fs;
stats.NoiseMean_A = mean(noise, "omitnan");
finiteNoise = noiseDetrended(isfinite(noiseDetrended));
stats.NoiseStd_A = std(finiteNoise);
stats.NoiseRms_A = sqrt(mean(finiteNoise.^2));
stats.NoisePeakToPeak_A = max(noiseDetrended) - min(noiseDetrended);
stats.NoiseSkewness = skewness(finiteNoise, 0);
stats.NoiseKurtosis = kurtosis(finiteNoise, 0);
stats.NoiseMedian_A = median(noiseDetrended, "omitnan");
stats.NoiseMad_A = median(abs(finiteNoise - median(finiteNoise)));

try
    [h, p] = lillietest(noiseDetrended);
    stats.LillieforsRejectNormal = double(h);
    stats.LillieforsPValue = p;
catch
    stats.LillieforsRejectNormal = NaN;
    stats.LillieforsPValue = NaN;
end

try
    [h, p] = jbtest(noiseDetrended);
    stats.JarqueBeraRejectNormal = double(h);
    stats.JarqueBeraPValue = p;
catch
    stats.JarqueBeraRejectNormal = NaN;
    stats.JarqueBeraPValue = NaN;
end
end

function plotTimeAndDistribution(time, current, noise, stats, outputDir)
fig = figure("Name", "Current measurement noise distribution", "Color", "w");
tiledlayout(fig, 3, 1, TileSpacing="compact", Padding="compact");

nexttile;
plot(time, current, "LineWidth", 0.8);
grid on;
xlabel("Time (s)");
ylabel("Current (A)");
title("Raw current measurement");

nexttile;
plot(time, noise, "LineWidth", 0.8);
grid on;
xlabel("Time (s)");
ylabel("Noise (A)");
title("Mean-removed and linearly detrended noise");

nexttile;
histogram(noise, "Normalization", "pdf");
hold on;
sigma = stats.NoiseStd_A;
mu = mean(noise, "omitnan");
xFit = linspace(mu - 5*sigma, mu + 5*sigma, 500);
normalPdf = exp(-0.5 * ((xFit - mu) / sigma).^2) / (sigma * sqrt(2*pi));
plot(xFit, normalPdf, "r", "LineWidth", 1.5);
grid on;
xlabel("Noise (A)");
ylabel("Probability density");
title("Noise histogram and fitted normal PDF");
legend(["Measured", "Normal fit"], Location="best");

saveFigure(fig, fullfile(outputDir, "noise_time_distribution"));

try
    fig = figure("Name", "Current measurement noise QQ plot", "Color", "w");
    qqplot(noise);
    grid on;
    title("Normal Q-Q plot of current measurement noise");
    saveFigure(fig, fullfile(outputDir, "noise_normal_qq"));
catch err
    warning("analyzeCurrentNoise:QqPlotSkipped", ...
        "Could not create Q-Q plot: %s", err.message);
end
end

function [spectrumTable, harmonicTable, mainsHarmonicTable] = analyzeHarmonics(noise, Fs, detectedFrequencies, detectedAmplitudes)
noise = noise(:);
L = numel(noise);
Y = fft(noise);
P2 = abs(Y / L);
P1 = P2(1:floor(L/2)+1);
P1(2:end-1) = 2 * P1(2:end-1);
f = Fs * (0:floor(L/2))' / L;

spectrumTable = table(f, P1(:), VariableNames=["Frequency_Hz", "Amplitude_A"]);

freq = detectedFrequencies(:);
amp = detectedAmplitudes(:);
valid = isfinite(freq) & isfinite(amp) & freq > 0;
freq = freq(valid);
amp = amp(valid);

if isempty(freq)
    harmonicTable = table();
    mainsHarmonicTable = makeMainsHarmonicTable(f, P1);
    return;
end

minFundamentalHz = 1.0;
fundamentalCandidates = find(freq >= minFundamentalHz);
if isempty(fundamentalCandidates)
    fundamentalCandidates = 1:numel(freq);
end

[~, localIdxFundamental] = max(amp(fundamentalCandidates));
idxFundamental = fundamentalCandidates(localIdxFundamental);
f0 = freq(idxFundamental);
resolution = Fs / L;
tolerance = max(2 * resolution, 0.02 * f0);
maxHarmonic = floor((Fs / 2) / f0);

harmonicNumber = (1:maxHarmonic)';
expectedFrequency = harmonicNumber * f0;
matchedFrequency = nan(size(expectedFrequency));
matchedAmplitude = nan(size(expectedFrequency));
frequencyError = nan(size(expectedFrequency));

for idx = 1:numel(harmonicNumber)
    [err, matchIdx] = min(abs(freq - expectedFrequency(idx)));
    if err <= tolerance
        matchedFrequency(idx) = freq(matchIdx);
        matchedAmplitude(idx) = amp(matchIdx);
        frequencyError(idx) = err;
    end
end

keep = isfinite(matchedFrequency);
harmonicTable = table( ...
    repmat(f0, nnz(keep), 1), ...
    harmonicNumber(keep), ...
    expectedFrequency(keep), ...
    matchedFrequency(keep), ...
    frequencyError(keep), ...
    matchedAmplitude(keep), ...
    VariableNames=[ ...
        "Fundamental_Hz", ...
        "HarmonicNumber", ...
        "ExpectedFrequency_Hz", ...
        "MatchedFrequency_Hz", ...
        "FrequencyError_Hz", ...
        "Amplitude_A"]);

mainsHarmonicTable = makeMainsHarmonicTable(f, P1);
end

function mainsHarmonicTable = makeMainsHarmonicTable(f, P1)
baseFrequencies = [50; 60];
nyquist = max(f);

base = [];
harmonicNumber = [];
frequency = [];
amplitude = [];

for baseIdx = 1:numel(baseFrequencies)
    fBase = baseFrequencies(baseIdx);
    maxHarmonic = floor(nyquist / fBase);
    for h = 1:maxHarmonic
        fTarget = fBase * h;
        [~, idx] = min(abs(f - fTarget));
        base(end+1, 1) = fBase; %#ok<AGROW>
        harmonicNumber(end+1, 1) = h; %#ok<AGROW>
        frequency(end+1, 1) = f(idx); %#ok<AGROW>
        amplitude(end+1, 1) = P1(idx); %#ok<AGROW>
    end
end

mainsHarmonicTable = table( ...
    base, harmonicNumber, frequency, amplitude, ...
    VariableNames=["MainsBase_Hz", "HarmonicNumber", "NearestFrequency_Hz", "Amplitude_A"]);
end

function angleChannel = selectAngleChannel(channels, targetLength, currentName, timeName)
angleChannel = struct("Name", "", "Value", []);
names = string({channels.Name});
for idx = 1:numel(channels)
    name = lower(names(idx));
    isAngleLike = any(contains(name, ["theta", "angle", "phi", "position", "encoder"]));
    isExcluded = strcmp(names(idx), string(currentName)) || strcmp(names(idx), string(timeName));
    if isAngleLike && ~isExcluded && abs(numel(channels(idx).Value) - targetLength) <= 1
        angleChannel = channels(idx);
        return;
    end
end
end

function saveFigure(fig, basePath)
basePath = string(basePath);
savefig(fig, basePath + ".fig");
exportgraphics(fig, basePath + ".png", Resolution=200);
end
