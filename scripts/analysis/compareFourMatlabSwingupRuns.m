%COMPAREFOURMATLABSWINGUPRUNS Document four analytical swing-up TD3 runs.

scriptDir = fileparts(mfilename("fullpath"));
repoRoot = fileparts(fileparts(scriptDir));
cd(repoRoot)
addpath(genpath(fullfile(repoRoot, "scripts")))
paths = getFurutaPaths(ProjectRoot=repoRoot);

outputDir = fullfile(paths.OutputsRoot, "matlab_swingup_four_run_comparison");
if ~isfolder(outputDir)
    mkdir(outputDir);
end

runs = localRun( ...
    "64, original", ...
    "run_20260728_153540_td3_matlab_analytical_100hz_fast", ...
    "FurutaTD3_matlab_analytical_100hz_fast_actor1x64_critic2x64_final.mat", ...
    datetime(2026, 7, 28, 15, 35, 40));
runs(2) = localRun( ...
    "32, from scratch", ...
    "run_20260730_195820_td3_matlab_ode3_student_100hz_actor1x32_critic2x32", ...
    "FurutaTD3_matlab_ode3_student_100hz_actor1x32_critic2x32_final.mat", ...
    datetime(2026, 7, 30, 19, 58, 20));
runs(3) = localRun( ...
    "16, from scratch", ...
    "run_20260730_210332_882_td3_matlab_ode3_student_100hz_actor1x16_critic2x16", ...
    "FurutaTD3_matlab_ode3_student_100hz_actor1x16_critic2x16_final.mat", ...
    datetime(2026, 7, 30, 21, 3, 32.882));
runs(4) = localRun( ...
    "32, continued", ...
    "run_20260730_220652_985_resume_20260730_195820_td3_matlab_ode3_student_100hz_actor1x32_critic2x32", ...
    "FurutaTD3_matlab_ode3_student_100hz_actor1x32_critic2x32_continued_final.mat", ...
    datetime(2026, 7, 30, 22, 6, 52.985));

colors = lines(numel(runs));
summaryRows = cell(numel(runs), 18);

for runIndex = 1:numel(runs)
    runFolder = fullfile(paths.ResultsRoot, "TD3", runs(runIndex).Folder);
    agentFile = fullfile(runFolder, runs(runIndex).FinalFile);
    loaded = load(agentFile, "agent", "cfg", "trainingStats", "resumeInfo");
    rollout = localRollout(loaded.agent, loaded.cfg);
    if runIndex == 1
        results = rollout;
    else
        results(runIndex) = rollout; %#ok<SAGROW>
    end

    episodes = numel(loaded.trainingStats.EpisodeIndex);
    durationSeconds = localTrainingDurationSeconds( ...
        agentFile, runs(runIndex).StartTime, loaded);
    summaryRows(runIndex, :) = { ...
        runs(runIndex).Label, runs(runIndex).Folder, ...
        loaded.cfg.Agent.ActorHiddenLayerSizes, ...
        mat2str(loaded.cfg.Agent.CriticHiddenLayerSizes), ...
        episodes, durationSeconds, durationSeconds / 60, ...
        results(runIndex).Captured, results(runIndex).EndTime, ...
        results(runIndex).TotalReward, results(runIndex).CurrentRms, ...
        results(runIndex).CurrentTotalVariation, ...
        results(runIndex).CurrentVariationRate, ...
        results(runIndex).CurrentDirectionReversals, ...
        results(runIndex).AbsoluteCurrentIntegral, ...
        results(runIndex).SquaredCurrentIntegral, ...
        results(runIndex).EstimatedElectricalEnergy, ...
        results(runIndex).AbsoluteMechanicalWork};

    localPlotTrainingProgress(loaded.trainingStats, runs(runIndex).Label, ...
        colors(runIndex, :), outputDir, runIndex);
end

summary = cell2table(summaryRows, VariableNames=[ ...
    "Label", "RunFolder", "ActorHidden", "CriticHidden", "Episodes", ...
    "TrainingSeconds", "TrainingMinutes", "Captured", "CaptureOrEndTime", ...
    "TotalReward", "CurrentRms", "CurrentTotalVariation", ...
    "CurrentVariationRate", "CurrentDirectionReversals", ...
    "AbsoluteCurrentIntegral", "SquaredCurrentIntegral", ...
    "EstimatedElectricalEnergy", "AbsoluteMechanicalWork"]);
writetable(summary, fullfile(outputDir, "four_run_summary.csv"));

localPlotStateComparison(runs, results, colors, outputDir);
localPlotCurrentComparison(runs, results, colors, outputDir);
localPlotRewardComparison(runs, results, colors, outputDir);
localPlotBestIndividual(runs(1), results(1), colors(1, :), outputDir);

disp(summary)
fprintf("Comparison outputs: %s\n", outputDir);

function run = localRun(label, folder, finalFile, startTime)
run = struct(Label=label, Folder=folder, FinalFile=finalFile, StartTime=startTime);
end

function result = localRollout(agent, cfg)
cfg.MatlabEnvironment.Reset.Theta1Range = [0 0];
cfg.MatlabEnvironment.Reset.Theta2Range = [0 0];
cfg.MatlabEnvironment.Reset.Omega1Range = [0 0];
cfg.MatlabEnvironment.Reset.Omega2Range = [0 0];

usesSimulinkConvention = isfield(cfg.Observation, "ErrorConvention") && ...
    string(cfg.Observation.ErrorConvention) == "reference_minus_measurement";
if usesSimulinkConvention
    env = createFurutaAnalyticalSwingupEnvSimulinkConvention(cfg);
    convention = "reference-minus-measurement, ode3";
else
    env = createFurutaAnalyticalSwingupEnv(cfg);
    convention = "legacy positive-state signs, RK4";
end

maxSteps = cfg.Done.MaxSteps;
state = zeros(maxSteps + 1, 4);
current = zeros(maxSteps, 1);
reward = zeros(maxSteps, 1);
[observation, info] = reset(env);
state(1, :) = info.State(:)';

for stepIndex = 1:maxSteps
    action = getAction(agent, observation);
    [observation, reward(stepIndex), isDone, info] = step(env, action);
    state(stepIndex + 1, :) = info.State(:)';
    current(stepIndex) = info.LastCurrentCommand;
    if isDone
        break;
    end
end

numSteps = stepIndex;
result = struct();
result.State = state(1:numSteps + 1, :);
result.Current = current(1:numSteps);
result.Reward = reward(1:numSteps);
result.StateTime = (0:numSteps)' * cfg.Agent.SampleTime;
result.StepTime = (1:numSteps)' * cfg.Agent.SampleTime;
result.EndTime = result.StateTime(end);
result.TotalReward = sum(result.Reward);
result.CurrentRms = sqrt(mean(result.Current.^2));
result.CurrentTotalVariation = sum(abs(diff(result.Current)));
result.CurrentVariationRate = result.CurrentTotalVariation / result.EndTime;
activeSign = sign(result.Current);
activeSign(abs(result.Current) < 0.05) = 0;
activeSign = activeSign(activeSign ~= 0);
result.CurrentDirectionReversals = sum(diff(activeSign) ~= 0);
sampleTime = cfg.Agent.SampleTime;
result.AbsoluteCurrentIntegral = sum(abs(result.Current)) * sampleTime;
result.SquaredCurrentIntegral = sum(result.Current.^2) * sampleTime;
omega1 = result.State(1:numSteps, 3);
motorPower = cfg.Motor.R * result.Current.^2 + ...
    cfg.Motor.km * result.Current .* omega1;
result.EstimatedElectricalEnergy = sum(max(motorPower, 0)) * sampleTime;
result.AbsoluteMechanicalWork = sum(abs( ...
    cfg.Motor.km * result.Current .* omega1)) * sampleTime;
result.Captured = isfield(info.LastDiagnosis, "captured") && ...
    info.LastDiagnosis.captured;
result.Convention = convention;
result.FinalDiagnosis = info.LastDiagnosis;
end

function durationSeconds = localTrainingDurationSeconds(agentFile, startTime, loaded)
if isfield(loaded, "resumeInfo") && ...
        isfield(loaded.resumeInfo, "StartTime") && ...
        isfield(loaded.resumeInfo, "EndTime")
    durationSeconds = seconds(loaded.resumeInfo.EndTime - loaded.resumeInfo.StartTime);
    return;
end
fileInfo = dir(agentFile);
finishTime = datetime(fileInfo.datenum, ConvertFrom="datenum");
durationSeconds = seconds(finishTime - startTime);
end

function localPlotTrainingProgress(stats, label, color, outputDir, runIndex)
episode = stats.EpisodeIndex;
fig = figure(Visible="off", Color="w", Position=[100 100 1100 800]);
layout = tiledlayout(fig, 3, 1, TileSpacing="compact", Padding="compact");

nexttile(layout)
plot(episode, stats.EpisodeReward, Color=0.65 + 0.35 * color);
hold on
plot(episode, stats.AverageReward, Color=color, LineWidth=1.4);
ylabel("Reward");
legend("Episode", "Average", Location="best");
grid on

nexttile(layout)
plot(episode, stats.EpisodeSteps, Color=color);
ylabel("Steps");
grid on

nexttile(layout)
plot(episode, stats.EpisodeQ0, Color=color);
ylabel("Episode Q0");
xlabel("Episode");
grid on
title(layout, "Training progress: " + label);

name = sprintf("training_progress_%d", runIndex);
exportgraphics(fig, fullfile(outputDir, name + ".png"), Resolution=180);
savefig(fig, fullfile(outputDir, name + ".fig"));
close(fig)
end

function localPlotStateComparison(runs, results, colors, outputDir)
fig = figure(Visible="off", Color="w", Position=[100 100 1200 900]);
layout = tiledlayout(fig, 4, 1, TileSpacing="compact", Padding="compact");
labels = ["theta1 (deg)", "theta2 (deg)", "omega1 (rad/s)", "omega2 (rad/s)"];
for stateIndex = 1:4
    nexttile(layout)
    hold on
    for runIndex = 1:numel(runs)
        values = results(runIndex).State(:, stateIndex);
        if stateIndex <= 2
            values = rad2deg(values);
        end
        plot(results(runIndex).StateTime, values, ...
            Color=colors(runIndex, :), LineWidth=1.25, ...
            DisplayName=runs(runIndex).Label);
        xline(results(runIndex).EndTime, "--", Color=colors(runIndex, :), ...
            Alpha=0.35, HandleVisibility="off");
    end
    ylabel(labels(stateIndex));
    grid on
end
xlabel("Time (s)");
comparisonLegend = legend("show");
comparisonLegend.Layout.Tile = "east";
title(layout, "Four-agent swing-up state comparison from the hanging state");
exportgraphics(fig, fullfile(outputDir, "comparison_states.png"), Resolution=180);
savefig(fig, fullfile(outputDir, "comparison_states.fig"));
close(fig)
end

function localPlotCurrentComparison(runs, results, colors, outputDir)
fig = figure(Visible="off", Color="w", Position=[100 100 1200 550]);
ax = axes(fig);
hold(ax, "on")
for runIndex = 1:numel(runs)
    stairs(ax, results(runIndex).StepTime, results(runIndex).Current, ...
        Color=colors(runIndex, :), LineWidth=1.2, DisplayName=runs(runIndex).Label);
    xline(ax, results(runIndex).EndTime, "--", Color=colors(runIndex, :), ...
        Alpha=0.35, HandleVisibility="off");
end
yline(ax, 1.5, ":k", "Current limit", HandleVisibility="off");
yline(ax, -1.5, ":k", HandleVisibility="off");
xlabel(ax, "Time (s)");
ylabel(ax, "Current command (A)");
title(ax, "Four-agent current-command comparison");
legend(ax, Location="best");
grid(ax, "on");
exportgraphics(fig, fullfile(outputDir, "comparison_current.png"), Resolution=180);
savefig(fig, fullfile(outputDir, "comparison_current.fig"));
close(fig)
end

function localPlotRewardComparison(runs, results, colors, outputDir)
fig = figure(Visible="off", Color="w", Position=[100 100 1200 550]);
ax = axes(fig);
hold(ax, "on")
for runIndex = 1:numel(runs)
    plot(ax, results(runIndex).StepTime, results(runIndex).Reward, ...
        Color=colors(runIndex, :), LineWidth=1.2, DisplayName=runs(runIndex).Label);
    xline(ax, results(runIndex).EndTime, "--", Color=colors(runIndex, :), ...
        Alpha=0.35, HandleVisibility="off");
end
xlabel(ax, "Time (s)");
ylabel(ax, "Reward per step");
title(ax, "Reward comparison (terminal reward scales differ between runs)");
legend(ax, Location="best");
grid(ax, "on");
exportgraphics(fig, fullfile(outputDir, "comparison_reward.png"), Resolution=180);
savefig(fig, fullfile(outputDir, "comparison_reward.fig"));
close(fig)
end

function localPlotBestIndividual(run, result, color, outputDir)
fig = figure(Visible="off", Color="w", Position=[100 100 1100 850]);
layout = tiledlayout(fig, 4, 1, TileSpacing="compact", Padding="compact");
labels = ["theta1 (deg)", "theta2 (deg)", "omega1 (rad/s)", "omega2 (rad/s)"];
for stateIndex = 1:4
    nexttile(layout)
    values = result.State(:, stateIndex);
    if stateIndex <= 2
        values = rad2deg(values);
    end
    plot(result.StateTime, values, Color=color, LineWidth=1.3);
    xline(result.EndTime, "--k", "LQR controller takes over", ...
        LabelVerticalAlignment="middle");
    ylabel(labels(stateIndex));
    grid on
end
xlabel("Time (s)");
title(layout, "Best agent states: " + run.Label);
exportgraphics(fig, fullfile(outputDir, "best_64_states.png"), Resolution=180);
savefig(fig, fullfile(outputDir, "best_64_states.fig"));
close(fig)

fig = figure(Visible="off", Color="w", Position=[100 100 1100 500]);
stairs(result.StepTime, result.Current, Color=color, LineWidth=1.3);
xline(result.EndTime, "--k", "LQR controller takes over");
yline(1.5, ":k", "Current limit", HandleVisibility="off");
yline(-1.5, ":k", HandleVisibility="off");
xlabel("Time (s)"); ylabel("Current command (A)");
title("Best agent current command"); grid on
exportgraphics(fig, fullfile(outputDir, "best_64_current.png"), Resolution=180);
savefig(fig, fullfile(outputDir, "best_64_current.fig"));
close(fig)

fig = figure(Visible="off", Color="w", Position=[100 100 1100 500]);
plot(result.StepTime, result.Reward, Color=color, LineWidth=1.3);
xline(result.EndTime, "--k", "LQR controller takes over");
xlabel("Time (s)"); ylabel("Reward per step");
title(sprintf("Best agent reward, total %.3f", result.TotalReward)); grid on
exportgraphics(fig, fullfile(outputDir, "best_64_reward.png"), Resolution=180);
savefig(fig, fullfile(outputDir, "best_64_reward.fig"));
close(fig)
end
