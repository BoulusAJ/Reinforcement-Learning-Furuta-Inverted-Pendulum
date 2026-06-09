%% Rerun corrected fixed-case metrics and reward-diagnosis failure labels
% Evaluates saved Stage 1 and Stage 2 agents on:
%   1) the full post-stage fixed grid
%   2) the Stage-1-training-like fixed subset

clear
clc

repoRoot = "C:\Users\abuj\Code\Reinforcement-Learning-Furuta-Inverted-Pendulum";
cd(repoRoot)
addpath(genpath(fullfile(repoRoot, "scripts")))

runDir = fullfile(repoRoot, "results", "run_20260604_existing_stage_results");
stageIndices = [1 2];

stamp = string(datetime("now", "Format", "yyyyMMdd_HHmmss"));
diagnosticDir = fullfile(repoRoot, "results", "diagnostics", "corrected_eval_" + stamp);
if ~isfolder(diagnosticDir)
    mkdir(diagnosticDir);
end

allMetrics = table();
allSummaries = table();

for stageIndex = stageIndices
    loaded = loadFurutaStageAgent(runDir, stageIndex, ...
        AssignToBase=true, ...
        LoadModel=true, ...
        RunInBackground=true);

    cfg = loaded.cfg;
    agent = loaded.agent;
    stage = loaded.stage;
    evalCfg = makeFurutaEvalConfig(cfg);

    obsInfo = rlNumericSpec([cfg.Observation.Dimension 1], Name="observations");
    actInfo = rlNumericSpec([1 1], ...
        LowerLimit=cfg.Action.Min, ...
        UpperLimit=cfg.Action.Max, ...
        Name=cfg.Action.Name);

    env = rlSimulinkEnv(cfg.Model.Name, cfg.Model.AgentBlock, obsInfo, actInfo);
    env.ResetFcn = @localResetFcnFurutaCurriculum;

    set_param(cfg.Model.Name, ...
        FastRestart="off", ...
        StopTime=num2str(cfg.Training.EpisodeDuration), ...
        SignalLogging="on", ...
        SignalLoggingName="logsout");

    evalSets = {
        "post_stage_full", evalCfg.PostStageCases
        "stage1_training_like", evalCfg.TrainingCases
        };

    fprintf("\nStage %d: %s\n", stageIndex, stage.Name);

    for setIdx = 1:size(evalSets, 1)
        evalSetName = evalSets{setIdx, 1};
        cases = evalSets{setIdx, 2};
        cases.EvalSetName(:) = evalSetName;

        fprintf("  Evaluating %s (%d cases)...\n", evalSetName, height(cases));

        metrics = evaluateCasesWithDiagnosis( ...
            agent, env, cases, evalCfg, stageIndex, string(stage.Name), evalSetName);
        summary = summarizeWithDiagnosis(metrics, stageIndex, string(stage.Name), evalSetName);

        disp(summary)

        metricsFile = fullfile(diagnosticDir, ...
            sprintf("stage_%02d_%s_metrics_with_diagnosis.csv", stageIndex, evalSetName));
        summaryFile = fullfile(diagnosticDir, ...
            sprintf("stage_%02d_%s_summary_with_diagnosis.csv", stageIndex, evalSetName));
        writetable(metrics, metricsFile);
        writetable(summary, summaryFile);

        allMetrics = [allMetrics; metrics]; %#ok<AGROW>
        allSummaries = [allSummaries; summary]; %#ok<AGROW>
    end
end

save(fullfile(diagnosticDir, "corrected_post_stage_diagnosis.mat"), ...
    "allMetrics", "allSummaries", "runDir");
writetable(allMetrics, fullfile(diagnosticDir, "all_metrics_with_diagnosis.csv"));
writetable(allSummaries, fullfile(diagnosticDir, "all_summaries_with_diagnosis.csv"));

fprintf("\nSaved corrected evaluation diagnostics to:\n%s\n", diagnosticDir);

%% Helpers

function metrics = evaluateCasesWithDiagnosis(agent, env, cases, evalCfg, stageIndex, stageName, evalSetName)
simOpts = rlSimulationOptions( ...
    MaxSteps=evalCfg.MaxSteps, ...
    StopOnError="on");

metrics = table();

for i = 1:height(cases)
    fixedReset = struct( ...
        "mode", "fixed", ...
        "Theta1Error0", cases.Theta1Error0(i), ...
        "Theta2Error0", cases.Theta2Error0(i), ...
        "Omega1Error0", cases.Omega1Error0(i), ...
        "Omega2Error0", cases.Omega2Error0(i));

    assignin("base", "curriculumParams", fixedReset);
    env.ResetFcn = @localResetFcnFurutaCurriculum;

    experiences = sim(env, agent, simOpts);
    row = computeFurutaMetrics(experiences, cases(i, :), evalCfg);
    row.StageIndex = stageIndex;
    row.StageName = stageName;
    row.EvalSetName(:) = evalSetName;
    row.EvaluatedAt = datetime("now");

    diagnosisRow = classifyFromDiagnosis(experiences);
    row = [row diagnosisRow]; %#ok<AGROW>

    metrics = [metrics; row]; %#ok<AGROW>

    fprintf("    %2d/%2d: theta2=%6.1f deg, omega2=%5.1f -> failed=%d, cause=%s, t=%.4f\n", ...
        i, height(cases), rad2deg(cases.Theta2Error0(i)), cases.Omega2Error0(i), ...
        row.Failed, row.PrimaryFailureCause, row.FirstUnsafeTime);
end
end

function diagnosisRow = classifyFromDiagnosis(experiences)
simData = experiences.SimulationInfo.getSimulationData(1);
diagnosis = simData.get("simout");

flagNames = [
    "theta1Unsafe"
    "theta2Unsafe"
    "omega1Unsafe"
    "omega2Unsafe"];

    valueNames = [
    "theta1Error_used_by_reward"
    "theta2Error_used_by_reward"
    "omega1Error_used_by_reward"
    "omega2Error_used_by_reward"
    "u_used_by_reward"];

t = diagnosis.(flagNames(1)).Time(:);
flagFirstTimes = NaN(1, numel(flagNames));
flagSeen = false(1, numel(flagNames));

for idx = 1:numel(flagNames)
    data = squeeze(diagnosis.(flagNames(idx)).Data);
    flagSeen(idx) = any(data(:) > 0.5);
    firstIdx = find(data(:) > 0.5, 1, "first");
    if ~isempty(firstIdx)
        flagFirstTimes(idx) = t(firstIdx);
    end
end

[firstUnsafeTime, firstFlagIdx] = min(flagFirstTimes, [], "omitnan");
if isempty(firstUnsafeTime) || isnan(firstUnsafeTime)
    firstUnsafeTime = NaN;
    primaryCause = "none";
else
    primaryCause = erase(flagNames(firstFlagIdx), "Unsafe");
end

maxValues = zeros(1, numel(valueNames));
for idx = 1:numel(valueNames)
    data = squeeze(diagnosis.(valueNames(idx)).Data);
    maxValues(idx) = max(abs(data(:)));
end

diagnosisRow = table( ...
    flagSeen(1), flagSeen(2), flagSeen(3), flagSeen(4), ...
    flagFirstTimes(1), flagFirstTimes(2), flagFirstTimes(3), flagFirstTimes(4), ...
    firstUnsafeTime, string(primaryCause), ...
    maxValues(1), maxValues(2), maxValues(3), maxValues(4), maxValues(5), ...
    'VariableNames', [ ...
        "DiagTheta1Unsafe", "DiagTheta2Unsafe", "DiagOmega1Unsafe", "DiagOmega2Unsafe", ...
        "FirstTheta1UnsafeTime", "FirstTheta2UnsafeTime", "FirstOmega1UnsafeTime", "FirstOmega2UnsafeTime", ...
        "FirstUnsafeTime", "PrimaryFailureCause", ...
        "DiagMaxAbsTheta1Error", "DiagMaxAbsTheta2Error", "DiagMaxAbsOmega1Error", "DiagMaxAbsOmega2Error", "DiagMaxAbsAction"]);
end

function summary = summarizeWithDiagnosis(metrics, stageIndex, stageName, evalSetName)
summary = table( ...
    stageIndex, stageName, evalSetName, height(metrics), ...
    mean(metrics.Failed), ...
    mean(metrics.Terminated), ...
    mean(metrics.DiagTheta1Unsafe), ...
    mean(metrics.DiagTheta2Unsafe), ...
    mean(metrics.DiagOmega1Unsafe), ...
    mean(metrics.DiagOmega2Unsafe), ...
    mean(metrics.SimTime, "omitnan"), ...
    median(metrics.SimTime, "omitnan"), ...
    max(rad2deg(metrics.MaxAbsTheta2Error), [], "omitnan"), ...
    mean(metrics.CaseCost, "omitnan"), ...
    'VariableNames', [ ...
        "StageIndex", "StageName", "EvalSetName", "NumCases", ...
        "FailureRate", "TerminationRate", ...
        "Theta1UnsafeRate", "Theta2UnsafeRate", "Omega1UnsafeRate", "Omega2UnsafeRate", ...
        "MeanSimTime", "MedianSimTime", "MaxAbsTheta2ErrorDeg", "MeanCaseCost"]);
end
