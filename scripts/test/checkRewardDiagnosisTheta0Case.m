%% Check reward diagnosis bus for one raw theta0 case
% Requires the model to route the reward diagnosis bus to SimulationOutput
% variable simout.

clear
clc

scriptDir = fileparts(mfilename("fullpath"));
repoRoot = fileparts(fileparts(scriptDir));
cd(repoRoot)
addpath(genpath(fullfile(repoRoot, "scripts")))
paths = getFurutaPaths(ProjectRoot=repoRoot);

runDir = fullfile(paths.ResultsRoot, "DDPG", "run_20260604_existing_stage_results");
stageIndices = [1 2];

theta0Raw = [0; pi + deg2rad(1)];
theta2Error0 = -atan2(sin(theta0Raw(2) - pi), cos(theta0Raw(2) - pi));

fprintf("Raw theta0 = [%.6f; %.6f] rad\n", theta0Raw(1), theta0Raw(2));
fprintf("Expected theta2Error0 = %.6f rad = %.3f deg\n\n", ...
    theta2Error0, rad2deg(theta2Error0));

diagnosticDir = fullfile(paths.ResultsRoot, "diagnostics");
if ~isfolder(diagnosticDir)
    mkdir(diagnosticDir);
end

for stageIndex = stageIndices
    loaded = loadFurutaStageAgent(runDir, stageIndex, ...
        AssignToBase=true, ...
        LoadModel=true, ...
        RunInBackground=true);

    cfg = loaded.cfg;
    agent = loaded.agent;
    stage = loaded.stage;

    obsInfo = rlNumericSpec([cfg.Observation.Dimension 1], Name="observations");
    actInfo = rlNumericSpec([1 1], ...
        LowerLimit=cfg.Action.Min, ...
        UpperLimit=cfg.Action.Max, ...
        Name=cfg.Action.Name);

    env = rlSimulinkEnv(cfg.Model.Name, cfg.Model.AgentBlock, obsInfo, actInfo);
    env.ResetFcn = @localResetFcnFurutaCurriculum;

    fixedReset = struct( ...
        "mode", "fixed", ...
        "Theta1Error0", 0, ...
        "Theta2Error0", theta2Error0, ...
        "Omega1Error0", 0, ...
        "Omega2Error0", 0);

    assignin("base", "curriculumParams", fixedReset);
    assignin("base", "rewardParams", cfg.Reward);
    assignin("base", "safetyParams", cfg.Safety);

    set_param(cfg.Model.Name, ...
        FastRestart="off", ...
        StopTime=num2str(cfg.Training.EpisodeDuration), ...
        SignalLogging="on", ...
        SignalLoggingName="logsout");

    simOpts = rlSimulationOptions( ...
        MaxSteps=ceil(cfg.Training.EpisodeDuration / cfg.Agent.SampleTime), ...
        StopOnError="on");

    experiences = sim(env, agent, simOpts);
    signals = extractFurutaSignals(experiences);
    simData = experiences.SimulationInfo.getSimulationData(1);
    diagnosis = simData.get("simout");
    diagnosisTable = diagnosisToTable(diagnosis);

    fprintf("Stage %d: %s\n", stageIndex, stage.Name);
    fprintf("logsout final time %.6f s, any logged isDone = %d\n", ...
        signals.t(end), any(signals.isDone > 0.5));

    printAroundFirstDone(signals, diagnosisTable);

    filePrefix = sprintf("stage_%02d_theta0_one_degree_reward_diagnosis", stageIndex);
    writetable(diagnosisTable, fullfile(diagnosticDir, filePrefix + ".csv"));
    save(fullfile(diagnosticDir, filePrefix + ".mat"), ...
        "signals", "diagnosis", "diagnosisTable", "theta0Raw", "fixedReset", "stage");
end

%% Helpers

function tbl = diagnosisToTable(diagnosis)
names = [
    "theta1Unsafe"
    "theta2Unsafe"
    "omega1Unsafe"
    "omega2Unsafe"
    "theta1Error_used_by_reward"
    "theta2Error_used_by_reward"
    "omega1Error_used_by_reward"
    "omega2Error_used_by_reward"
    "u_used_by_reward"
    "uPrev_used_by_reward"
    "rewardTerm_aliveBonus"
    "rewardTerm_theta2Error"
    "rewardTerm_theta1Error"
    "rewardTerm_velocity"
    "rewardTerm_actionEffort"
    "rewardTerm_actionSmoothness"
    "rewardTerm_uprightBonus"
    "rewardTerm_unsafePenalty"];

t = diagnosis.(names(1)).Time(:);
tbl = table(t, 'VariableNames', "t");

for idx = 1:numel(names)
    ts = diagnosis.(names(idx));
    data = squeeze(ts.Data);
    tbl.(names(idx)) = double(data(:));
end
end

function printAroundFirstDone(signals, diagnosisTable)
idxDone = find(signals.isDone > 0.5, 1, "first");
if isempty(idxDone)
    fprintf("No logged isDone sample found.\n\n");
    return;
end

tDone = signals.t(idxDone);
idxDiag = find(diagnosisTable.t >= tDone, 1, "first");
if isempty(idxDiag)
    idxDiag = height(diagnosisTable);
end

lo = max(1, idxDiag - 5);
hi = min(height(diagnosisTable), idxDiag + 5);

cols = [
    "t"
    "theta1Unsafe"
    "theta2Unsafe"
    "omega1Unsafe"
    "omega2Unsafe"
    "theta1Error_used_by_reward"
    "theta2Error_used_by_reward"
    "omega1Error_used_by_reward"
    "omega2Error_used_by_reward"
    "u_used_by_reward"
    "uPrev_used_by_reward"
    "rewardTerm_aliveBonus"
    "rewardTerm_theta2Error"
    "rewardTerm_theta1Error"
    "rewardTerm_velocity"
    "rewardTerm_actionEffort"
    "rewardTerm_actionSmoothness"
    "rewardTerm_uprightBonus"
    "rewardTerm_unsafePenalty"];

fprintf("First logged isDone at t = %.6f s\n", tDone);
disp(diagnosisTable(lo:hi, cols))

    maxFlags = varfun(@max, diagnosisTable(:, [
        "theta1Unsafe"
        "theta2Unsafe"
        "omega1Unsafe"
        "omega2Unsafe"]));
fprintf("Unsafe flags seen over whole returned diagnosis signal:\n");
    disp(maxFlags)
    printFirstUnsafeTimes(diagnosisTable);

    fprintf("Diagnosis maxima:\n");
fprintf("  max |theta1Error_used_by_reward| = %.6g\n", ...
    max(abs(diagnosisTable.theta1Error_used_by_reward)));
fprintf("  max |theta2Error_used_by_reward| = %.6g rad = %.3f deg\n", ...
    max(abs(diagnosisTable.theta2Error_used_by_reward)), ...
    rad2deg(max(abs(diagnosisTable.theta2Error_used_by_reward))));
fprintf("  max |omega1Error_used_by_reward| = %.6g\n", ...
    max(abs(diagnosisTable.omega1Error_used_by_reward)));
    fprintf("  max |omega2Error_used_by_reward| = %.6g\n\n", ...
        max(abs(diagnosisTable.omega2Error_used_by_reward)));
end

function printFirstUnsafeTimes(diagnosisTable)
flagNames = [
    "theta1Unsafe"
    "theta2Unsafe"
    "omega1Unsafe"
    "omega2Unsafe"];

for idx = 1:numel(flagNames)
    flag = flagNames(idx);
    firstIdx = find(diagnosisTable.(flag) > 0.5, 1, "first");
    if isempty(firstIdx)
        fprintf("  first %s: never\n", flag);
    else
        fprintf("  first %s: t = %.6f s\n", flag, diagnosisTable.t(firstIdx));
    end
end
end
