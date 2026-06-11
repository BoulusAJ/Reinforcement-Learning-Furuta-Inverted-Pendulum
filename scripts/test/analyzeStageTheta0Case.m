%% Analyze saved stage agents on one raw theta0 case
% Compares Stage 1 and Stage 2 on the raw Simulink initial condition:
% theta0 = [0; pi + deg2rad(1)].

clear
clc

repoRoot = "C:\Users\abuj\Code\Reinforcement-Learning-Furuta-Inverted-Pendulum";
cd(repoRoot)
addpath(genpath(fullfile(repoRoot, "scripts")))

runDir = fullfile(repoRoot, "results", "DDPG", "run_20260604_existing_stage_results");
stageIndices = [1 2];
theta0Raw = [0; pi + deg2rad(1)];
omega0Raw = [0; 0];

runMissingPostStageEvaluation = true;
useParallelForPostStageEvaluation = true;
plotTimeSeries = true;
saveDiagnostics = true;

%% Convert raw theta0 to the controller-facing error convention

theta1Error0 = -theta0Raw(1);
theta2Error0 = -atan2(sin(theta0Raw(2) - pi), cos(theta0Raw(2) - pi));
omega1Error0 = -omega0Raw(1);
omega2Error0 = -omega0Raw(2);

oneDegreeCase = table( ...
    1, theta1Error0, theta2Error0, omega1Error0, omega2Error0, "theta0_one_degree", ...
    'VariableNames', ["CaseID", "Theta1Error0", "Theta2Error0", "Omega1Error0", "Omega2Error0", "EvalSetName"]);

fprintf("Raw theta0 = [%.6f; %.6f] rad\n", theta0Raw(1), theta0Raw(2));
fprintf("Equivalent errors = [theta1 %.6f, theta2 %.6f] rad = [%.3f, %.3f] deg\n\n", ...
    theta1Error0, theta2Error0, rad2deg(theta1Error0), rad2deg(theta2Error0));

%% Load stages, inspect saved/evaluated post-stage summaries, and run the one-degree case

stageResults = struct([]);
postStageSummaries = table();
oneDegreeMetrics = table();

for idx = 1:numel(stageIndices)
    stageIndex = stageIndices(idx);
    loaded = loadFurutaStageAgent(runDir, stageIndex, ...
        AssignToBase=true, ...
        LoadModel=true, ...
        RunInBackground=true);

    cfg = loaded.cfg;
    agent = loaded.agent;
    stage = loaded.stage;

    if isfield(loaded, "evalCfg")
        evalCfg = loaded.evalCfg;
    else
        evalCfg = makeFurutaEvalConfig(cfg);
    end

    obsInfo = rlNumericSpec([cfg.Observation.Dimension 1], Name="observations");
    actInfo = rlNumericSpec([1 1], ...
        LowerLimit=cfg.Action.Min, ...
        UpperLimit=cfg.Action.Max, ...
        Name=cfg.Action.Name);
    env = rlSimulinkEnv(cfg.Model.Name, cfg.Model.AgentBlock, obsInfo, actInfo);
    env.ResetFcn = @localResetFcnFurutaCurriculum;

    fprintf("Stage %d: %s\n", stageIndex, stage.Name);

    if isfield(loaded, "postStageEval") && ~isempty(loaded.postStageEval)
        postStageEval = loaded.postStageEval;
        fprintf("Saved post-stage summary:\n");
        disp(postStageEval.summary)
    elseif runMissingPostStageEvaluation
        fprintf("No saved post-stage summary found. Running fixed post-stage evaluation now...\n");
        postStageEval = evaluateFurutaController( ...
            agent, env, evalCfg.PostStageCases, evalCfg, ...
            "ControllerName", "DDPG", ...
            "EvalSetName", "post_stage_full", ...
            "StageIndex", stageIndex, ...
            "StageName", stage.Name, ...
            "RunInBackground", true, ...
            "UseFastRestart", false, ...
            "UseParallel", useParallelForPostStageEvaluation, ...
            "RequestedWorkers", cfg.Training.RequestedWorkers, ...
            "AllowPoolRestart", false);
        fprintf("Fresh post-stage summary:\n");
        disp(postStageEval.summary)
    else
        postStageEval = [];
        warning("No post-stage summary available for Stage %d.", stageIndex);
    end

    if ~isempty(postStageEval)
        postStageSummaries = [postStageSummaries; postStageEval.summary]; %#ok<AGROW>
    end

    [signals, metrics] = runOneCaseWithSignals(agent, env, oneDegreeCase, evalCfg);
    metrics.StageIndex = stageIndex;
    metrics.StageName = string(stage.Name);
    oneDegreeMetrics = [oneDegreeMetrics; metrics]; %#ok<AGROW>

    fprintf("One-degree case metrics:\n");
    disp(metrics)
    fprintf("First logged errors [theta1 theta2 omega1 omega2] = [%.6f %.6f %.6f %.6f]\n", ...
        signals.theta1Error(1), signals.theta2Error(1), signals.omega1Error(1), signals.omega2Error(1));
    fprintf("Final time %.4f s, any isDone = %d, max |theta2Error| = %.3f deg\n\n", ...
        signals.t(end), any(signals.isDone > 0.5), rad2deg(max(abs(signals.theta2Error))));
    printFirstSamples(signals);

    stageResults(idx).StageIndex = stageIndex; %#ok<SAGROW>
    stageResults(idx).StageName = string(stage.Name);
    stageResults(idx).PostStageEval = postStageEval;
    stageResults(idx).OneDegreeSignals = signals;
    stageResults(idx).OneDegreeMetrics = metrics;
end

%% Compare summaries and one-degree metrics

disp("Post-stage summary comparison:")
disp(postStageSummaries)

disp("One-degree case comparison:")
disp(oneDegreeMetrics(:, [ ...
    "StageIndex", "StageName", "SimTime", "Terminated", "Failed", ...
    "MaxAbsTheta2Error", "MaxAbsOmegaError", "FinalTheta2MAE", "CaseCost"]))

%% Optional export for later inspection

if saveDiagnostics
    diagnosticDir = fullfile(repoRoot, "results", "diagnostics");
    if ~isfolder(diagnosticDir)
        mkdir(diagnosticDir);
    end

    save(fullfile(diagnosticDir, "stage_theta0_one_degree_diagnostic.mat"), ...
        "stageResults", "postStageSummaries", "oneDegreeMetrics", "oneDegreeCase", "theta0Raw");
    writetable(postStageSummaries, ...
        fullfile(diagnosticDir, "stage_theta0_one_degree_post_stage_summaries.csv"));
    writetable(oneDegreeMetrics, ...
        fullfile(diagnosticDir, "stage_theta0_one_degree_metrics.csv"));
end

%% Plot one-degree time series for Stage 1 and Stage 2

if plotTimeSeries
    figure("Name", "One-degree theta0 case: errors")
    tiledlayout(2, 1)

    nexttile
    hold on
    for idx = 1:numel(stageResults)
        sig = stageResults(idx).OneDegreeSignals;
        plot(sig.t, rad2deg(sig.theta2Error), DisplayName="Stage " + stageResults(idx).StageIndex)
    end
    ylabel("theta2 error [deg]")
    grid on
    legend(Location="best")

    nexttile
    hold on
    for idx = 1:numel(stageResults)
        sig = stageResults(idx).OneDegreeSignals;
        plot(sig.t, rad2deg(sig.theta1Error), DisplayName="Stage " + stageResults(idx).StageIndex)
    end
    xlabel("Time [s]")
    ylabel("theta1 error [deg]")
    grid on

    figure("Name", "One-degree theta0 case: action and safety")
    tiledlayout(3, 1)

    nexttile
    hold on
    for idx = 1:numel(stageResults)
        sig = stageResults(idx).OneDegreeSignals;
        plot(sig.t, sig.action, DisplayName="Stage " + stageResults(idx).StageIndex)
    end
    ylabel("action [-]")
    grid on
    legend(Location="best")

    nexttile
    hold on
    for idx = 1:numel(stageResults)
        sig = stageResults(idx).OneDegreeSignals;
        plot(sig.t, sig.torque_command, DisplayName="Stage " + stageResults(idx).StageIndex)
    end
    ylabel("torque cmd [Nm]")
    grid on

    nexttile
    hold on
    for idx = 1:numel(stageResults)
        sig = stageResults(idx).OneDegreeSignals;
        stairs(sig.t, sig.isDone, DisplayName="Stage " + stageResults(idx).StageIndex)
    end
    xlabel("Time [s]")
    ylabel("isDone")
    ylim([-0.1 1.1])
    grid on
end

%% Helper

function [signals, metrics] = runOneCaseWithSignals(agent, env, oneCase, evalCfg)
fixedReset = struct( ...
    "mode", "fixed", ...
    "Theta1Error0", oneCase.Theta1Error0, ...
    "Theta2Error0", oneCase.Theta2Error0, ...
    "Omega1Error0", oneCase.Omega1Error0, ...
    "Omega2Error0", oneCase.Omega2Error0);

assignin("base", "curriculumParams", fixedReset);
env.ResetFcn = @localResetFcnFurutaCurriculum;

if bdIsLoaded(evalCfg.ModelName)
    set_param(evalCfg.ModelName, FastRestart="off");
    set_param(evalCfg.ModelName, StopTime=num2str(evalCfg.Tf));
    set_param(evalCfg.ModelName, SignalLogging="on", SignalLoggingName="logsout");
end

simOpts = rlSimulationOptions( ...
    MaxSteps=evalCfg.MaxSteps, ...
    StopOnError="on");

experiences = sim(env, agent, simOpts);
signals = extractFurutaSignals(experiences);
metrics = computeFurutaMetrics(experiences, oneCase, evalCfg);
end

function printFirstSamples(signals)
n = min(12, numel(signals.t));
sampleTable = table( ...
    signals.t(1:n), ...
    rad2deg(signals.theta2Error(1:n)), ...
    signals.omega1Error(1:n), ...
    signals.omega2Error(1:n), ...
    signals.action(1:n), ...
    signals.reward(1:n), ...
    signals.isDone(1:n), ...
    'VariableNames', ["t", "theta2Error_deg", "omega1Error", "omega2Error", "action", "reward", "isDone"]);

fprintf("First logged samples:\n");
disp(sampleTable)
end
