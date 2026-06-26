function saved = saveFurutaModelVsHardwareRun(simout, options)
%SAVEFURUTAMODELVSHARDWARERUN Save one model-vs-hardware test run cleanly.
%
% Example:
%   saved = saveFurutaModelVsHardwareRun(simout, ...
%       TestName="test1_constant_current_0p2A_disable_0p8s", ...
%       SourceType="hardware", ...
%       Description="Real system, current command 0.2 A, disabled at 0.8 s.");

arguments
    simout
    options.TestName (1,1) string = "unnamed_test"
    options.SourceType (1,1) string {mustBeMember(options.SourceType, ...
        ["hardware", "simulation", "analytical", "simscape", "other"])} = "other"
    options.Description (1,1) string = ""
    options.ModelDescription (1,1) string = ""
    options.InputDescription (1,1) string = ""
    options.CurrentCommand (1,1) double = NaN
    options.EnableDisableTime (1,1) double = NaN
    options.Duration (1,1) double = NaN
    options.SampleTime (1,1) double = NaN
    options.OutputRoot (1,1) string = ""
    options.RunLabel (1,1) string = ""
    options.SaveRawSimout (1,1) logical = true
    options.MakePlot (1,1) logical = true
end

if strlength(options.OutputRoot) == 0
    outputRoot = localDefaultOutputRoot();
else
    outputRoot = options.OutputRoot;
end

signals = extractFurutaModelVsHardwareSignals(simout, ...
    SampleTime=options.SampleTime, ...
    SourceLabel=options.SourceType);

timestamp = string(datetime("now", "Format", "yyyyMMdd_HHmmss"));
testSlug = localSlug(options.TestName);
if strlength(options.RunLabel) > 0
    runSlug = localSlug(options.RunLabel);
else
    runSlug = localSlug(options.SourceType);
end

runDir = fullfile(outputRoot, testSlug, timestamp + "_" + runSlug);
plotDir = fullfile(runDir, "plots");
if ~isfolder(plotDir)
    mkdir(plotDir);
end

metadata = localMetadata(options, timestamp, runDir);
summary = localSummaryTable(signals, metadata);

matPath = fullfile(runDir, "run.mat");
metadataPath = fullfile(runDir, "metadata.json");
summaryPath = fullfile(runDir, "summary.csv");
plotPath = fullfile(plotDir, "quicklook.png");

if options.SaveRawSimout
    save(matPath, "signals", "metadata", "summary", "simout", "-v7.3");
else
    save(matPath, "signals", "metadata", "summary", "-v7.3");
end

localWriteJson(metadataPath, metadata);
writetable(summary, summaryPath);

if options.MakePlot
    localQuicklookPlot(signals, metadata, plotPath);
else
    plotPath = "";
end

saved = struct();
saved.runDir = runDir;
saved.matPath = matPath;
saved.metadataPath = metadataPath;
saved.summaryPath = summaryPath;
saved.plotPath = plotPath;
saved.signals = signals;
saved.metadata = metadata;
saved.summary = summary;
end

function metadata = localMetadata(options, timestamp, runDir)
metadata = struct();
metadata.Timestamp = timestamp;
metadata.TestName = options.TestName;
metadata.SourceType = options.SourceType;
metadata.Description = options.Description;
metadata.ModelDescription = options.ModelDescription;
metadata.InputDescription = options.InputDescription;
metadata.CurrentCommand = options.CurrentCommand;
metadata.EnableDisableTime = options.EnableDisableTime;
metadata.Duration = options.Duration;
metadata.SampleTime = options.SampleTime;
metadata.RunDirectory = runDir;
metadata.ChannelLayout = [ ...
    "theta1", "theta2", "omega1", "omega2", ...
    "theta2_wrapped", "enable", "current_cmd", "current"];
end

function summary = localSummaryTable(signals, metadata)
t = signals.t;
enableOffTime = NaN;
idxOff = find(signals.enable < 0.5, 1, "first");
if ~isempty(idxOff)
    enableOffTime = t(idxOff);
end

summary = table( ...
    string(metadata.TestName), ...
    string(metadata.SourceType), ...
    t(1), t(end), numel(t), signals.dt_median, signals.fs_median, ...
    max(abs(signals.theta1)), ...
    max(abs(signals.theta2_wrapped)), ...
    max(abs(signals.theta2_upright_error)), ...
    max(abs(signals.omega1)), ...
    max(abs(signals.omega2)), ...
    mean(signals.current_cmd, "omitnan"), ...
    max(abs(signals.current_cmd)), ...
    max(abs(signals.current)), ...
    trapz(t, abs(signals.current)), ...
    enableOffTime, ...
    'VariableNames', [ ...
        "TestName", "SourceType", ...
        "StartTime", "EndTime", "NumSamples", "MedianDt", "MedianFs", ...
        "MaxAbsTheta1", "MaxAbsTheta2Wrapped", "MaxAbsTheta2UprightError", ...
        "MaxAbsOmega1", "MaxAbsOmega2", ...
        "MeanCurrentCommand", "MaxAbsCurrentCommand", "MaxAbsCurrent", ...
        "CurrentAbsIntegral", "EnableOffTime"]);
end

function localQuicklookPlot(signals, metadata, plotPath)
fig = figure("Visible", "off", "Color", "w");
layout = tiledlayout(fig, 4, 1, "TileSpacing", "compact", "Padding", "compact");
title(layout, metadata.TestName + " - " + metadata.SourceType, "Interpreter", "none");

nexttile
plot(signals.t, rad2deg(signals.theta1), "LineWidth", 1.0);
grid on
ylabel("theta1 [deg]")

nexttile
plot(signals.t, rad2deg(signals.theta2_wrapped), "LineWidth", 1.0);
hold on
plot(signals.t, rad2deg(signals.theta2_upright_error), "LineWidth", 1.0);
grid on
ylabel("theta2 [deg]")
legend(["wrapped", "upright error"], "Location", "best")

nexttile
plot(signals.t, signals.omega1, "LineWidth", 1.0);
hold on
plot(signals.t, signals.omega2, "LineWidth", 1.0);
grid on
ylabel("omega [rad/s]")
legend(["omega1", "omega2"], "Location", "best")

nexttile
plot(signals.t, signals.current_cmd, "LineWidth", 1.0);
hold on
plot(signals.t, signals.current, "LineWidth", 1.0);
stairs(signals.t, signals.enable, "LineWidth", 1.0);
grid on
ylabel("current / enable")
xlabel("time [s]")
legend(["I cmd [A]", "I [A]", "enable"], "Location", "best")

exportgraphics(fig, plotPath, "Resolution", 160);
close(fig);
end

function localWriteJson(path, value)
fid = fopen(path, "w");
if fid < 0
    error("saveFurutaModelVsHardwareRun:WriteJsonFailed", ...
        "Could not write JSON file: %s", path);
end
cleanupObj = onCleanup(@() fclose(fid));
fprintf(fid, "%s", jsonencode(value, PrettyPrint=true));
end

function outputRoot = localDefaultOutputRoot()
scriptDir = fileparts(mfilename("fullpath"));
repoRoot = fileparts(fileparts(scriptDir));
outputRoot = fullfile(repoRoot, "results", "model_vs_hardware");
end

function slug = localSlug(value)
slug = lower(regexprep(string(value), "[^a-zA-Z0-9]+", "_"));
slug = regexprep(slug, "^_+|_+$", "");
if strlength(slug) == 0
    slug = "run";
end
end
