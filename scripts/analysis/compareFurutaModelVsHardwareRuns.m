function comparison = compareFurutaModelVsHardwareRuns(runFiles, options)
%COMPAREFURUTAMODELVSHARDWARERUNS Compare two or more saved test run files.
%
% Example:
%   compareFurutaModelVsHardwareRuns([
%       "results/model_vs_hardware/test1/.../run.mat"
%       "results/model_vs_hardware/test1/.../run.mat"
%   ], Label="hardware_vs_analytical");

arguments
    runFiles
    options.Label (1,1) string = "comparison"
    options.OutputRoot (1,1) string = ""
    options.ReferenceIndex (1,1) double = 1
    options.SaveComparison (1,1) logical = true
end

runFiles = string(runFiles);
if numel(runFiles) < 2
    error("compareFurutaModelVsHardwareRuns:NeedAtLeastTwoRuns", ...
        "Provide at least two run.mat files.");
end

if strlength(options.OutputRoot) == 0
    outputRoot = localDefaultOutputRoot();
else
    outputRoot = options.OutputRoot;
end

runs = repmat(struct(), numel(runFiles), 1);
for idx = 1:numel(runFiles)
    S = load(runFiles(idx), "signals", "metadata", "summary");
    if ~isfield(S, "signals")
        error("compareFurutaModelVsHardwareRuns:MissingSignals", ...
            "File does not contain saved signals: %s", runFiles(idx));
    end
    runs(idx).file = runFiles(idx);
    runs(idx).signals = S.signals;
    if isfield(S, "metadata")
        runs(idx).metadata = S.metadata;
    else
        runs(idx).metadata = struct(TestName="", SourceType="");
    end
    if isfield(S, "summary")
        runs(idx).summary = S.summary;
    else
        runs(idx).summary = table();
    end
    runs(idx).label = localRunLabel(runs(idx).metadata, idx);
end

reference = runs(options.ReferenceIndex).signals;
metrics = localComparisonMetrics(runs, reference, options.ReferenceIndex);

comparison = struct();
comparison.runs = runs;
comparison.metrics = metrics;
comparison.referenceIndex = options.ReferenceIndex;

if options.SaveComparison
    timestamp = string(datetime("now", "Format", "yyyyMMdd_HHmmss"));
    outDir = fullfile(outputRoot, timestamp + "_" + localSlug(options.Label));
    plotDir = fullfile(outDir, "plots");
    if ~isfolder(plotDir)
        mkdir(plotDir);
    end

    metricsPath = fullfile(outDir, "comparison_metrics.csv");
    matPath = fullfile(outDir, "comparison.mat");
    plotPath = fullfile(plotDir, "overlay.png");

    writetable(metrics, metricsPath);
    localOverlayPlot(runs, plotPath, options.Label);
    save(matPath, "comparison", "-v7.3");

    comparison.outputDir = outDir;
    comparison.metricsPath = metricsPath;
    comparison.plotPath = plotPath;
    comparison.matPath = matPath;
end
end

function metrics = localComparisonMetrics(runs, reference, referenceIndex)
rows = table();
for idx = 1:numel(runs)
    sig = runs(idx).signals;
    [tCommon, refInterp, sigInterp] = localAlignedSignals(reference, sig);

    theta1Err = sigInterp.theta1 - refInterp.theta1;
    theta2Err = sigInterp.theta2_wrapped - refInterp.theta2_wrapped;
    omega1Err = sigInterp.omega1 - refInterp.omega1;
    omega2Err = sigInterp.omega2 - refInterp.omega2;
    currentErr = sigInterp.current - refInterp.current;

    row = table( ...
        idx, idx == referenceIndex, string(runs(idx).label), string(runs(idx).file), ...
        tCommon(1), tCommon(end), numel(tCommon), ...
        rmsLocal(theta1Err), rmsLocal(theta2Err), ...
        rmsLocal(omega1Err), rmsLocal(omega2Err), rmsLocal(currentErr), ...
        max(abs(theta1Err)), max(abs(theta2Err)), ...
        max(abs(omega1Err)), max(abs(omega2Err)), max(abs(currentErr)), ...
        'VariableNames', [ ...
            "RunIndex", "IsReference", "RunLabel", "RunFile", ...
            "CompareStartTime", "CompareEndTime", "CompareNumSamples", ...
            "Theta1RMSError", "Theta2WrappedRMSError", ...
            "Omega1RMSError", "Omega2RMSError", "CurrentRMSError", ...
            "Theta1MaxAbsError", "Theta2WrappedMaxAbsError", ...
            "Omega1MaxAbsError", "Omega2MaxAbsError", "CurrentMaxAbsError"]);
    rows = [rows; row]; %#ok<AGROW>
end
metrics = rows;
end

function [tCommon, refInterp, sigInterp] = localAlignedSignals(ref, sig)
tStart = max(ref.t(1), sig.t(1));
tEnd = min(ref.t(end), sig.t(end));
idx = ref.t >= tStart & ref.t <= tEnd;
tCommon = ref.t(idx);
if numel(tCommon) < 2
    error("compareFurutaModelVsHardwareRuns:NoOverlap", ...
        "The reference run and comparison run do not have enough overlapping time.");
end

fields = ["theta1", "theta2_wrapped", "omega1", "omega2", "current"];
for k = 1:numel(fields)
    name = fields(k);
    refInterp.(name) = interp1(ref.t, ref.(name), tCommon, "linear", "extrap");
    sigInterp.(name) = interp1(sig.t, sig.(name), tCommon, "linear", "extrap");
end
end

function localOverlayPlot(runs, plotPath, label)
fig = figure("Visible", "off", "Color", "w");
layout = tiledlayout(fig, 5, 1, "TileSpacing", "compact", "Padding", "compact");
title(layout, label, "Interpreter", "none");

localPlotField(runs, "theta1", "theta1 [deg]", true);
localPlotField(runs, "theta2_wrapped", "theta2 wrapped [deg]", true);
localPlotField(runs, "omega1", "omega1 [rad/s]", false);
localPlotField(runs, "omega2", "omega2 [rad/s]", false);
localPlotField(runs, "current", "current [A]", false);
xlabel("time [s]")

exportgraphics(fig, plotPath, "Resolution", 170);
close(fig);
end

function localPlotField(runs, fieldName, yLabel, convertToDeg)
nexttile
hold on
for idx = 1:numel(runs)
    y = runs(idx).signals.(fieldName);
    if convertToDeg
        y = rad2deg(y);
    end
    plot(runs(idx).signals.t, y, "LineWidth", 1.0, ...
        "DisplayName", runs(idx).label);
end
grid on
ylabel(yLabel)
legend("Location", "best", "Interpreter", "none")
end

function y = rmsLocal(x)
x = x(:);
x = x(isfinite(x));
if isempty(x)
    y = NaN;
else
    y = sqrt(mean(x.^2));
end
end

function label = localRunLabel(metadata, idx)
parts = strings(0);
if isfield(metadata, "SourceType") && strlength(string(metadata.SourceType)) > 0
    parts(end+1) = string(metadata.SourceType); %#ok<AGROW>
end
if isfield(metadata, "ModelDescription") && strlength(string(metadata.ModelDescription)) > 0
    parts(end+1) = string(metadata.ModelDescription); %#ok<AGROW>
end
if isempty(parts)
    label = "run_" + idx;
else
    label = strjoin(parts, " - ");
end
end

function slug = localSlug(value)
slug = lower(regexprep(string(value), "[^a-zA-Z0-9]+", "_"));
slug = regexprep(slug, "^_+|_+$", "");
if strlength(slug) == 0
    slug = "comparison";
end
end

function outputRoot = localDefaultOutputRoot()
scriptDir = fileparts(mfilename("fullpath"));
repoRoot = fileparts(fileparts(scriptDir));
paths = getFurutaPaths(ProjectRoot=repoRoot);
outputRoot = fullfile(paths.ResultsRoot, "model_vs_hardware", "comparisons");
end
