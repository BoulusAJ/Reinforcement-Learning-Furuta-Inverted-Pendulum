function out = plotFurutaTrainingProgress(runDir, options)
%PLOTFURUTATRAININGPROGRESS Plot saved RL training progress for a run.
%
%   out = plotFurutaTrainingProgress(runDir) loads the final MAT file in
%   runDir, extracts trainingStats, and writes a MATLAB-style training
%   progress plot plus a CSV export into the same run folder.

arguments
    runDir (1,1) string
    options.FinalMat (1,1) string = ""
    options.OutputName (1,1) string = "training_progress"
    options.RewardOnlyOutputName (1,1) string = "training_reward"
    options.SaveRewardOnly (1,1) logical = true
    options.SaveFig (1,1) logical = true
    options.SaveCsv (1,1) logical = true
    options.Visible (1,1) logical = false
end

runDir = string(runDir);
if ~isfolder(runDir)
    error("plotFurutaTrainingProgress:MissingRunDir", ...
        "Run directory does not exist: %s", runDir);
end

finalMat = options.FinalMat;
if strlength(finalMat) == 0
    finalMat = findFinalMat(runDir);
end

[trainingStats, cfg, sourceMat, sourceVariable] = loadTrainingStats(runDir, finalMat);
T = trainingStatsToTable(trainingStats);
T = normalizeTrainingStatsTable(T);

if options.SaveCsv
    csvPath = fullfile(runDir, options.OutputName + ".csv");
    writetable(T, csvPath);
else
    csvPath = "";
end

figVisibility = "off";
if options.Visible
    figVisibility = "on";
end

fig = figure( ...
    Name="Furuta training progress", ...
    Color="w", ...
    Visible=figVisibility, ...
    Position=[100 100 1400 850]);

tl = tiledlayout(fig, 3, 1, TileSpacing="compact", Padding="compact");
title(tl, makePlotTitle(runDir, cfg), Interpreter="none", FontWeight="bold");

episode = T.Episode;

ax1 = nexttile(tl);
hold(ax1, "on");
plot(ax1, episode, T.EpisodeReward, Color=[0.20 0.45 0.80 0.35], LineWidth=0.8);
plot(ax1, episode, T.AverageReward, Color=[0.85 0.25 0.18], LineWidth=2.0);
grid(ax1, "on");
xlabel(ax1, "Episode");
ylabel(ax1, "Reward");
legend(ax1, ["Episode reward", "Average reward"], Location="best");
title(ax1, "Reward");

ax2 = nexttile(tl);
plot(ax2, episode, T.EpisodeSteps, Color=[0.13 0.55 0.35], LineWidth=1.1);
grid(ax2, "on");
xlabel(ax2, "Episode");
ylabel(ax2, "Steps");
title(ax2, "Episode Length");

ax3 = nexttile(tl);
if ismember("EpisodeQ0", T.Properties.VariableNames)
    plot(ax3, episode, T.EpisodeQ0, Color=[0.50 0.30 0.75], LineWidth=1.1);
    ylabel(ax3, "Q0");
    title(ax3, "Initial Q Estimate");
else
    plot(ax3, episode, T.StepCount, Color=[0.45 0.45 0.45], LineWidth=1.1);
    ylabel(ax3, "Step Count");
    title(ax3, "Cumulative Step Count");
end
grid(ax3, "on");
xlabel(ax3, "Episode");

linkaxes([ax1 ax2 ax3], "x");
xlim([max(1, min(episode)) max(episode)]);

pngPath = fullfile(runDir, options.OutputName + ".png");
exportgraphics(fig, pngPath, Resolution=200);

figPath = "";
if options.SaveFig
    figPath = fullfile(runDir, options.OutputName + ".fig");
    savefig(fig, figPath);
end

close(fig);

rewardPngPath = "";
rewardFigPath = "";
if options.SaveRewardOnly
    [rewardPngPath, rewardFigPath] = saveRewardOnlyPlot( ...
        runDir, options.RewardOnlyOutputName, T, cfg, options.Visible, options.SaveFig);
end

out = struct( ...
    RunDir=runDir, ...
    FinalMat=finalMat, ...
    SourceMat=sourceMat, ...
    SourceVariable=sourceVariable, ...
    PlotPath=string(pngPath), ...
    FigurePath=string(figPath), ...
    RewardPlotPath=string(rewardPngPath), ...
    RewardFigurePath=string(rewardFigPath), ...
    CsvPath=string(csvPath), ...
    NumEpisodes=height(T));

fprintf("Saved training progress plot:\n  %s\n", pngPath);
if strlength(rewardPngPath) > 0
    fprintf("Saved reward-only training plot:\n  %s\n", rewardPngPath);
end
if strlength(csvPath) > 0
    fprintf("Saved training stats CSV:\n  %s\n", csvPath);
end
end

function [pngPath, figPath] = saveRewardOnlyPlot(runDir, outputName, T, cfg, visible, saveFig)
figVisibility = "off";
if visible
    figVisibility = "on";
end

fig = figure( ...
    Name="Furuta reward progress", ...
    Color="w", ...
    Visible=figVisibility, ...
    Position=[100 100 1300 650]);

ax = axes(fig);
hold(ax, "on");
plot(ax, T.Episode, T.EpisodeReward, Color=[0.20 0.45 0.80 0.35], LineWidth=0.8);
plot(ax, T.Episode, T.AverageReward, Color=[0.85 0.25 0.18], LineWidth=2.2);
grid(ax, "on");
xlabel(ax, "Episode");
ylabel(ax, "Reward");
title(ax, makePlotTitle(runDir, cfg), Interpreter="none", FontWeight="bold");
legend(ax, ["Episode reward", "Average reward"], Location="best");
xlim(ax, [max(1, min(T.Episode)) max(T.Episode)]);

pngPath = fullfile(runDir, outputName + ".png");
exportgraphics(fig, pngPath, Resolution=200);

figPath = "";
if saveFig
    figPath = fullfile(runDir, outputName + ".fig");
    savefig(fig, figPath);
end

close(fig);
end

function [trainingStats, cfg, sourceMat, sourceVariable] = loadTrainingStats(runDir, finalMat)
cfg = struct();
sourceMat = string(finalMat);
sourceVariable = "trainingStats";

if strlength(finalMat) > 0
    S = load(finalMat, "trainingStats", "cfg");
    if isfield(S, "cfg")
        cfg = S.cfg;
    end
    if isfield(S, "trainingStats") && ~isempty(S.trainingStats)
        trainingStats = S.trainingStats;
        return
    end
end

stageStats = loadStageTrainingStats(runDir);
if ~isempty(stageStats)
    trainingStats = stageStats;
    sourceMat = string(fullfile(runDir, "stages"));
    sourceVariable = "stage trainingStats";
    return
end

checkpointMat = findLatestAgentCheckpoint(runDir);
if strlength(checkpointMat) > 0
    C = load(checkpointMat, "savedAgentResult");
    if isfield(C, "savedAgentResult") && ~isempty(C.savedAgentResult)
        trainingStats = C.savedAgentResult;
        sourceMat = checkpointMat;
        sourceVariable = "savedAgentResult";
        return
    end
end

error("plotFurutaTrainingProgress:MissingTrainingStats", ...
    "No non-empty trainingStats in %s, no stage trainingStats, and no savedAgentResult checkpoint in %s.", ...
    finalMat, fullfile(runDir, "saved_agents"));
end

function T = loadStageTrainingStats(runDir)
stageFiles = dir(fullfile(runDir, "stages", "*.mat"));
T = table();
if isempty(stageFiles)
    return
end

[~, order] = sort({stageFiles.name});
stageFiles = stageFiles(order);

episodeOffset = 0;
stepOffset = 0;
for idx = 1:numel(stageFiles)
    stagePath = fullfile(stageFiles(idx).folder, stageFiles(idx).name);
    S = load(stagePath, "trainingStats", "stage");
    if ~isfield(S, "trainingStats") || isempty(S.trainingStats)
        continue
    end

    stageTable = normalizeTrainingStatsTable(trainingStatsToTable(S.trainingStats));
    stageTable.Episode = stageTable.Episode + episodeOffset;
    stageTable.StepCount = stageTable.StepCount + stepOffset;
    stageTable.StageIndex = repmat(idx, height(stageTable), 1);

    stageName = "stage_" + idx;
    if isfield(S, "stage") && isfield(S.stage, "Name")
        stageName = string(S.stage.Name);
    end
    stageTable.StageName = repmat(stageName, height(stageTable), 1);

    T = [T; stageTable]; %#ok<AGROW>
    episodeOffset = max(T.Episode);
    stepOffset = max(T.StepCount);
end
end

function checkpointMat = findLatestAgentCheckpoint(runDir)
files = dir(fullfile(runDir, "saved_agents", "Agent*.mat"));
checkpointMat = "";
if isempty(files)
    return
end

episode = nan(numel(files), 1);
for idx = 1:numel(files)
    token = regexp(files(idx).name, "^Agent(\d+)\.mat$", "tokens", "once");
    if ~isempty(token)
        episode(idx) = str2double(token{1});
    end
end

if all(isnan(episode))
    [~, idx] = max([files.datenum]);
else
    [~, idx] = max(episode);
end
checkpointMat = string(fullfile(files(idx).folder, files(idx).name));
end

function finalMat = findFinalMat(runDir)
files = dir(fullfile(runDir, "*_final.mat"));
if isempty(files)
    files = dir(fullfile(runDir, "*.mat"));
end
if isempty(files)
    finalMat = "";
    return
end

[~, idx] = max([files.datenum]);
finalMat = string(fullfile(files(idx).folder, files(idx).name));
end

function T = trainingStatsToTable(trainingStats)
if istable(trainingStats)
    T = trainingStats;
    return
end

if isstruct(trainingStats)
    T = structStatsToTable(trainingStats);
    return
end

props = string(properties(trainingStats));
data = struct();
targetHeight = 0;

for idx = 1:numel(props)
    name = props(idx);
    try
        value = trainingStats.(name);
    catch
        continue
    end

    if ~(isnumeric(value) || islogical(value) || isduration(value))
        continue
    end
    if isrow(value)
        value = value(:);
    end

    if iscolumn(value) && numel(value) > 1
        data.(matlab.lang.makeValidName(name)) = value;
        targetHeight = max(targetHeight, numel(value));
    end
end

if targetHeight == 0
    try
        T = structStatsToTable(struct(trainingStats));
        if height(T) > 0
            return
        end
    catch
    end

    error("plotFurutaTrainingProgress:UnsupportedStats", ...
        "Could not convert trainingStats of class %s to a table.", class(trainingStats));
end

T = struct2table(data);
end

function T = structStatsToTable(stats)
if numel(stats) > 1
    T = struct2table(stats);
    return
end

fields = string(fieldnames(stats));
data = struct();
targetHeight = 0;

for idx = 1:numel(fields)
    name = fields(idx);
    value = stats.(name);
    if ~(isnumeric(value) || islogical(value) || isduration(value))
        continue
    end
    if isrow(value)
        value = value(:);
    end

    if iscolumn(value) && numel(value) > 1
        data.(matlab.lang.makeValidName(name)) = value;
        targetHeight = max(targetHeight, numel(value));
    end
end

if targetHeight == 0
    T = table();
else
    T = struct2table(data);
end
end

function T = normalizeTrainingStatsTable(T)
T.Properties.VariableNames = matlab.lang.makeUniqueStrings( ...
    matlab.lang.makeValidName(T.Properties.VariableNames));

T = addCanonicalColumn(T, "Episode", ...
    ["Episode", "EpisodeIndex", "EpisodeNumber", "EpisodeCount"], (1:height(T))');
T = addCanonicalColumn(T, "EpisodeReward", ...
    ["EpisodeReward", "Reward"], []);
T = addCanonicalColumn(T, "EpisodeSteps", ...
    ["EpisodeSteps", "EpisodeStepCount", "Steps"], []);
T = addCanonicalColumn(T, "AverageReward", ...
    ["AverageReward", "AverageEpisodeReward", "AvgReward"], []);
T = addCanonicalColumn(T, "StepCount", ...
    ["StepCount", "TotalAgentSteps", "TotalSteps"], []);

if ~ismember("EpisodeReward", T.Properties.VariableNames)
    error("plotFurutaTrainingProgress:MissingRewardColumn", ...
        "Could not find an episode reward column in trainingStats.");
end
if ~ismember("AverageReward", T.Properties.VariableNames)
    T.AverageReward = movmean(T.EpisodeReward, min(10, height(T)), "omitnan");
end
if ~ismember("EpisodeSteps", T.Properties.VariableNames)
    T.EpisodeSteps = nan(height(T), 1);
end
if ~ismember("StepCount", T.Properties.VariableNames)
    T.StepCount = cumsum(fillmissing(T.EpisodeSteps, "constant", 0));
end

T.Episode = double(T.Episode);
T.EpisodeReward = double(T.EpisodeReward);
T.AverageReward = double(T.AverageReward);
T.EpisodeSteps = double(T.EpisodeSteps);
T.StepCount = double(T.StepCount);

if ismember("EpisodeQ0", T.Properties.VariableNames)
    T.EpisodeQ0 = double(T.EpisodeQ0);
end

keep = ["Episode", "EpisodeReward", "EpisodeSteps", "AverageReward", "StepCount", "EpisodeQ0"];
keep = keep(ismember(keep, T.Properties.VariableNames));
T = T(:, keep);
end

function T = addCanonicalColumn(T, canonicalName, candidates, fallback)
if ismember(canonicalName, T.Properties.VariableNames)
    return
end

names = string(T.Properties.VariableNames);
for candidate = candidates
    idx = find(strcmpi(names, candidate), 1);
    if ~isempty(idx)
        T.(canonicalName) = T.(names(idx));
        return
    end
end

if ~isempty(fallback)
    T.(canonicalName) = fallback;
end
end

function txt = makePlotTitle(runDir, cfg)
[~, runName] = fileparts(runDir);
txt = string(runName);

if isfield(cfg, "Agent") && isfield(cfg.Agent, "Algorithm")
    txt = txt + " (" + string(cfg.Agent.Algorithm) + ")";
end
end
