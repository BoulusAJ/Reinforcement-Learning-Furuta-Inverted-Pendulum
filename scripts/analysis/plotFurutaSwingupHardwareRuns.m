function analysis = plotFurutaSwingupHardwareRuns(runFiles, options)
%PLOTFURUTASWINGUPHARDWARERUNS Overlay and average saved swing-up runs.
%
% Example:
%   files = [
%       "results/model_vs_hardware/swingup_500hz_long_hardware_20260707/20260707_171506_hardware_closed_loop/run.mat"
%       "results/model_vs_hardware/swingup_500hz_long_hardware_20260707/20260707_171625_hardware_closed_loop/run.mat"
%   ];
%   analysis = plotFurutaSwingupHardwareRuns(files);
%
% Runs are aligned so t=0 is the first enable-on sample. The average is
% computed on a common time grid. Samples outside each run's available time
% range are treated as missing, so different run lengths are allowed.

arguments
    runFiles
    options.Label (1,1) string = "swingup hardware runs"
    options.Fields (1,:) string = [ ...
        "theta1", "theta2_wrapped", "omega1", "omega2", ...
        "current_cmd", "current"]
    options.TimeStep (1,1) double = NaN
    options.MaxTime (1,1) double = NaN
    options.MinRunsForAverage (1,1) double = 2
    options.SaveOutput (1,1) logical = false
    options.OutputRoot (1,1) string = ""
end

runFiles = string(runFiles);
runFiles = runFiles(:);

if numel(runFiles) < 1
    error("plotFurutaSwingupHardwareRuns:NoRuns", ...
        "Provide at least one run.mat file.");
end

runs = localLoadRuns(runFiles);
timeStep = localTimeStep(runs, options.TimeStep);
maxTime = localMaxTime(runs, options.MaxTime);
tGrid = (0:timeStep:maxTime).';

average = localAverageRuns(runs, options.Fields, tGrid, options.MinRunsForAverage);

overlayFigure = localOverlayPlot(runs, options.Fields, options.Label);
averageFigure = localAveragePlot(average, options.Fields, options.Label);

analysis = struct();
analysis.runFiles = runFiles;
analysis.runs = runs;
analysis.tGrid = tGrid;
analysis.average = average;
analysis.overlayFigure = overlayFigure;
analysis.averageFigure = averageFigure;

if options.SaveOutput
    analysis.outputDir = localSaveOutput(analysis, options);
end
end

function runs = localLoadRuns(runFiles)
runs = repmat(struct(), numel(runFiles), 1);

for idx = 1:numel(runFiles)
    S = load(runFiles(idx));
    if isfield(S, "enabledSignals")
        signals = S.enabledSignals;
    elseif isfield(S, "signals")
        signals = localEnabledSignalsFromFullRun(S.signals);
    else
        error("plotFurutaSwingupHardwareRuns:MissingSignals", ...
            "File does not contain enabledSignals or signals: %s", runFiles(idx));
    end

    if ~isfield(signals, "t") || numel(signals.t) < 2
        error("plotFurutaSwingupHardwareRuns:EmptyEnabledWindow", ...
            "Run has no usable enabled window: %s", runFiles(idx));
    end

    runs(idx).file = runFiles(idx);
    runs(idx).signals = signals;
    runs(idx).metadata = localOptionalField(S, "metadata", struct());
    runs(idx).swingupInfo = localOptionalField(S, "swingupInfo", struct());
    runs(idx).label = localRunLabel(runFiles(idx), runs(idx).metadata, idx);
end
end

function enabledSignals = localEnabledSignalsFromFullRun(signals)
enableMask = signals.enable > 0.5;
idxEnableOn = find(enableMask, 1, "first");

if isempty(idxEnableOn)
    enabledSignals = struct("t", []);
    return
end

enableOnTime = signals.t(idxEnableOn);
enabledSignals = struct();
enabledSignals.t = signals.t(enableMask) - enableOnTime;
enabledSignals.theta1 = signals.theta1(enableMask);
enabledSignals.theta2 = signals.theta2(enableMask);
enabledSignals.omega1 = signals.omega1(enableMask);
enabledSignals.omega2 = signals.omega2(enableMask);
enabledSignals.theta2_wrapped = signals.theta2_wrapped(enableMask);
enabledSignals.current_cmd = signals.current_cmd(enableMask);
enabledSignals.current = signals.current(enableMask);
enabledSignals.enable = signals.enable(enableMask);
end

function value = localOptionalField(S, fieldName, defaultValue)
if isfield(S, fieldName)
    value = S.(fieldName);
else
    value = defaultValue;
end
end

function timeStep = localTimeStep(runs, requestedTimeStep)
if isfinite(requestedTimeStep)
    timeStep = requestedTimeStep;
    return
end

dt = NaN(numel(runs), 1);
for idx = 1:numel(runs)
    t = runs(idx).signals.t(:);
    dt(idx) = median(diff(t), "omitnan");
end

timeStep = median(dt, "omitnan");
if ~isfinite(timeStep) || timeStep <= 0
    timeStep = 0.002;
end
end

function maxTime = localMaxTime(runs, requestedMaxTime)
if isfinite(requestedMaxTime)
    maxTime = requestedMaxTime;
    return
end

runEndTimes = NaN(numel(runs), 1);
for idx = 1:numel(runs)
    runEndTimes(idx) = runs(idx).signals.t(end);
end
maxTime = max(runEndTimes, [], "omitnan");
end

function average = localAverageRuns(runs, fields, tGrid, minRunsForAverage)
average = struct();
average.t = tGrid;
average.minRunsForAverage = minRunsForAverage;

for fieldIdx = 1:numel(fields)
    fieldName = fields(fieldIdx);
    Y = NaN(numel(tGrid), numel(runs));

    for runIdx = 1:numel(runs)
        signals = runs(runIdx).signals;
        if ~isfield(signals, fieldName)
            continue
        end

        t = signals.t(:);
        y = signals.(fieldName)(:);
        validTime = tGrid >= t(1) & tGrid <= t(end);
        Y(validTime, runIdx) = interp1(t, y, tGrid(validTime), "linear");
    end

    n = sum(isfinite(Y), 2);
    meanY = mean(Y, 2, "omitnan");
    stdY = std(Y, 0, 2, "omitnan");

    meanY(n < minRunsForAverage) = NaN;
    stdY(n < minRunsForAverage) = NaN;

    average.(fieldName).values = Y;
    average.(fieldName).mean = meanY;
    average.(fieldName).std = stdY;
    average.(fieldName).count = n;
end
end

function fig = localOverlayPlot(runs, fields, label)
fig = figure("Color", "w", "Name", label + " overlay");
layout = tiledlayout(fig, numel(fields), 1, ...
    "TileSpacing", "compact", "Padding", "compact");
title(layout, label + " - aligned at enable on", "Interpreter", "none");

for fieldIdx = 1:numel(fields)
    fieldName = fields(fieldIdx);
    nexttile
    hold on

    for runIdx = 1:numel(runs)
        signals = runs(runIdx).signals;
        if ~isfield(signals, fieldName)
            continue
        end

        y = localPlotUnits(signals.(fieldName), fieldName);
        plot(signals.t, y, "LineWidth", 0.9, ...
            "DisplayName", runs(runIdx).label);
    end

    grid on
    ylabel(localYAxisLabel(fieldName))
    legend("Location", "best", "Interpreter", "none")
end

xlabel("time since enable on [s]")
end

function fig = localAveragePlot(average, fields, label)
fig = figure("Color", "w", "Name", label + " average");
layout = tiledlayout(fig, numel(fields), 1, ...
    "TileSpacing", "compact", "Padding", "compact");
title(layout, label + " - average on common grid", "Interpreter", "none");

for fieldIdx = 1:numel(fields)
    fieldName = fields(fieldIdx);
    if ~isfield(average, fieldName)
        continue
    end

    t = average.t;
    meanY = localPlotUnits(average.(fieldName).mean, fieldName);
    stdY = localPlotUnits(average.(fieldName).std, fieldName);
    count = average.(fieldName).count;

    nexttile
    hold on
    localShadedStd(t, meanY, stdY);
    plot(t, meanY, "k", "LineWidth", 1.8, "DisplayName", "mean");
    yyaxis right
    plot(t, count, "Color", [0.45 0.45 0.45], "LineStyle", ":", ...
        "LineWidth", 0.9, "DisplayName", "run count");
    ylabel("run count")
    yyaxis left
    grid on
    ylabel(localYAxisLabel(fieldName))
end

xlabel("time since enable on [s]")
end

function localShadedStd(t, meanY, stdY)
valid = isfinite(meanY) & isfinite(stdY);
if nnz(valid) < 2
    return
end

x = [t(valid); flipud(t(valid))];
y = [meanY(valid) - stdY(valid); flipud(meanY(valid) + stdY(valid))];
fill(x, y, [0.75 0.82 0.92], ...
    "EdgeColor", "none", "FaceAlpha", 0.35, ...
    "DisplayName", "mean +/- 1 std");
end

function y = localPlotUnits(y, fieldName)
if any(fieldName == ["theta1", "theta2", "theta2_wrapped"])
    y = rad2deg(y);
end
end

function label = localYAxisLabel(fieldName)
switch fieldName
    case "theta1"
        label = "theta1 [deg]";
    case "theta2"
        label = "theta2 raw [deg]";
    case "theta2_wrapped"
        label = "theta2 wrapped [deg]";
    case "omega1"
        label = "omega1 [rad/s]";
    case "omega2"
        label = "omega2 [rad/s]";
    case "current_cmd"
        label = "i cmd [A]";
    case "current"
        label = "current [A]";
    case "enable"
        label = "enable";
    otherwise
        label = fieldName;
end
end

function label = localRunLabel(runFile, metadata, idx)
if isfield(metadata, "Timestamp") && strlength(string(metadata.Timestamp)) > 0
    label = string(metadata.Timestamp);
    return
end

[runDir, ~, ~] = fileparts(runFile);
[~, label] = fileparts(runDir);
if strlength(label) == 0
    label = "run_" + idx;
end
end

function outputDir = localSaveOutput(analysis, options)
if strlength(options.OutputRoot) == 0
    outputRoot = localDefaultOutputRoot();
else
    outputRoot = options.OutputRoot;
end

timestamp = string(datetime("now", "Format", "yyyyMMdd_HHmmss"));
outputDir = fullfile(outputRoot, timestamp + "_" + localSlug(options.Label));
plotDir = fullfile(outputDir, "plots");
if ~isfolder(plotDir)
    mkdir(plotDir);
end

exportgraphics(analysis.overlayFigure, fullfile(plotDir, "overlay.png"), ...
    "Resolution", 170);
exportgraphics(analysis.averageFigure, fullfile(plotDir, "average.png"), ...
    "Resolution", 170);
save(fullfile(outputDir, "swingup_overlay_average.mat"), "analysis", "-v7.3");
end

function outputRoot = localDefaultOutputRoot()
scriptDir = fileparts(mfilename("fullpath"));
repoRoot = fileparts(fileparts(scriptDir));
outputRoot = fullfile(repoRoot, "results", "model_vs_hardware", "comparisons");
end

function slug = localSlug(value)
slug = lower(regexprep(string(value), "[^a-zA-Z0-9]+", "_"));
slug = regexprep(slug, "^_+|_+$", "");
if strlength(slug) == 0
    slug = "swingup_average";
end
end
