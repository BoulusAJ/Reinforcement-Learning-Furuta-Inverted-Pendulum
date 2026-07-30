function summary = plotRecentFurutaTrainingProgress(options)
%PLOTRECENTFURUTATRAININGPROGRESS Plot training progress for recent runs.
%
%   summary = plotRecentFurutaTrainingProgress() selects the newest 15
%   results/*/run_* folders by timestamp in the run folder name and calls
%   plotFurutaTrainingProgress for each run when training data is available.
%   If a run has only training_console.log, the log is parsed into a
%   trainingStats MAT file first, then the existing plotter is used.

arguments
    options.ResultsRoot (1,1) string = ""
    options.NumRuns (1,1) double {mustBeInteger, mustBePositive} = 15
    options.SummaryName (1,1) string = "recent_training_progress_summary.csv"
    options.Visible (1,1) logical = false
end

resultsRoot = string(options.ResultsRoot);
if strlength(resultsRoot) == 0
    paths = getFurutaPaths();
    resultsRoot = paths.ResultsRoot;
end
runDirs = findRunDirs(resultsRoot);
if isempty(runDirs)
    error("plotRecentFurutaTrainingProgress:NoRuns", ...
        "No run_* folders found under %s.", resultsRoot);
end

runDirs = sortRunDirsByTimestamp(runDirs);
runDirs = runDirs(1:min(options.NumRuns, numel(runDirs)));

rows = repmat(struct( ...
    RunDir="", ...
    RunName="", ...
    Plotted=false, ...
    Source="", ...
    NumEpisodes=nan, ...
    PlotPath="", ...
    RewardPlotPath="", ...
    CsvPath="", ...
    Message=""), numel(runDirs), 1);

for idx = 1:numel(runDirs)
    runDir = runDirs(idx);
    [~, runName] = fileparts(runDir);
    rows(idx).RunDir = runDir;
    rows(idx).RunName = string(runName);

    try
        out = plotFurutaTrainingProgress(runDir, Visible=options.Visible);
        rows(idx) = fillSuccessRow(rows(idx), out);
        continue
    catch statsErr
        [parsedMat, parseMessage] = parseTrainingConsoleLog(runDir);
        if strlength(parsedMat) == 0
            rows(idx).Message = string(statsErr.message) + " | " + parseMessage;
            fprintf("Skipped %s: %s\n", runName, rows(idx).Message);
            continue
        end
    end

    try
        out = plotFurutaTrainingProgress( ...
            runDir, ...
            FinalMat=parsedMat, ...
            Visible=options.Visible);
        rows(idx) = fillSuccessRow(rows(idx), out);
        rows(idx).Source = "training_console.log";
    catch plotErr
        rows(idx).Message = string(plotErr.message);
        fprintf("Skipped %s after console parse: %s\n", runName, rows(idx).Message);
    end
end

summary = struct2table(rows);
summaryPath = fullfile(resultsRoot, options.SummaryName);
writetable(summary, summaryPath);
fprintf("Saved recent training progress summary:\n  %s\n", summaryPath);
end

function runDirs = findRunDirs(resultsRoot)
families = dir(resultsRoot);
families = families([families.isdir]);
runDirs = strings(0, 1);

for familyIdx = 1:numel(families)
    familyName = string(families(familyIdx).name);
    if familyName == "." || familyName == ".."
        continue
    end

    listing = dir(fullfile(families(familyIdx).folder, families(familyIdx).name, "run_*"));
    listing = listing([listing.isdir]);
    for runIdx = 1:numel(listing)
        runDirs(end + 1, 1) = string(fullfile(listing(runIdx).folder, listing(runIdx).name)); %#ok<AGROW>
    end
end
end

function runDirs = sortRunDirsByTimestamp(runDirs)
timestamps = NaT(numel(runDirs), 1);
for idx = 1:numel(runDirs)
    [~, runName] = fileparts(runDirs(idx));
    token = regexp(runName, "^run_(\d{8})_(\d{6})", "tokens", "once");
    if isempty(token)
        timestamps(idx) = datetime(0, 1, 1);
    else
        timestamps(idx) = datetime(string(token{1}) + string(token{2}), InputFormat="yyyyMMddHHmmss");
    end
end

[~, order] = sort(timestamps, "descend");
runDirs = runDirs(order);
end

function row = fillSuccessRow(row, out)
row.Plotted = true;
row.Source = out.SourceVariable;
row.NumEpisodes = out.NumEpisodes;
row.PlotPath = out.PlotPath;
row.RewardPlotPath = out.RewardPlotPath;
row.CsvPath = out.CsvPath;
row.Message = "ok";
end

function [parsedMat, message] = parseTrainingConsoleLog(runDir)
parsedMat = "";
logPath = fullfile(runDir, "training_console.log");
if ~isfile(logPath)
    message = "No training_console.log found.";
    return
end

txt = fileread(logPath);
expr = [ ...
    "Episode:\s*(\d+)\s*/\s*(\d+)\s*\|\s*" + ...
    "Episode reward:\s*([-+]?\d+(?:\.\d+)?)\s*\|\s*" + ...
    "Episode steps:\s*(\d+)\s*\|\s*" + ...
    "Average reward:\s*([-+]?\d+(?:\.\d+)?)\s*\|\s*" + ...
    "Step Count:\s*(\d+)\s*\|\s*" + ...
    "Episode Q0:\s*([-+]?\d+(?:\.\d+)?)" ...
    ];

tokens = regexp(txt, expr, "tokens");
if isempty(tokens)
    message = "No episode rows found in training_console.log.";
    return
end

M = str2double(vertcat(tokens{:}));
trainingStats = struct( ...
    Episode=M(:, 1), ...
    EpisodeReward=M(:, 3), ...
    EpisodeSteps=M(:, 4), ...
    AverageReward=M(:, 5), ...
    StepCount=M(:, 6), ...
    EpisodeQ0=M(:, 7));

parsedMat = string(fullfile(runDir, "training_console_parsed.mat"));
save(parsedMat, "trainingStats");
message = "Parsed " + string(size(M, 1)) + " console episodes.";
end
