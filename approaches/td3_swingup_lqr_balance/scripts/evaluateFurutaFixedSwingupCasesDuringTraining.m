function [statistic, scores, data] = ...
    evaluateFurutaFixedSwingupCasesDuringTraining(agent, ~, trainingInfo, cfg)
%EVALUATEFURUTAFIXEDSWINGUPCASESDURINGTRAINING Fixed-case capture evaluator.
%
% statistic is the fraction of cases that terminate in the LQR capture
% region. scores contains episode returns. data contains case-level results
% for debugging and evaluation after training.

cases = cfg.Evaluation.FixedSwingupCases;
numCases = height(cases);
scores = zeros(numCases, 1);
captured = false(numCases, 1);
safetyTerminated = false(numCases, 1);
timedOut = false(numCases, 1);
captureTime = nan(numCases, 1);
episodeSteps = zeros(numCases, 1);

if isprop(agent, "UseExplorationPolicy")
    useExplorationPolicy = agent.UseExplorationPolicy;
    agent.UseExplorationPolicy = false;
    restoreExploration = onCleanup( ...
        @() localRestoreExploration(agent, useExplorationPolicy)); %#ok<NASGU>
end

for caseIndex = 1:numCases
    caseCfg = cfg;
    caseCfg.MatlabEnvironment.Reset.Theta1Range = ...
        deg2rad(cases.Theta1Deg(caseIndex)) * [1 1];
    caseCfg.MatlabEnvironment.Reset.Theta2Range = ...
        deg2rad(cases.Theta2Deg(caseIndex)) * [1 1];
    caseCfg.MatlabEnvironment.Reset.Omega1Range = ...
        cases.Omega1(caseIndex) * [1 1];
    caseCfg.MatlabEnvironment.Reset.Omega2Range = ...
        cases.Omega2(caseIndex) * [1 1];

    evalEnv = createFurutaAnalyticalSwingupEnvSimulinkConvention(caseCfg);
    observation = reset(evalEnv);
    finalDiagnosis = struct();

    for stepIndex = 1:caseCfg.Done.MaxSteps
        action = getAction(agent, observation);
        [observation, reward, isDone, info] = step(evalEnv, action);
        scores(caseIndex) = scores(caseIndex) + reward;

        if isDone
            finalDiagnosis = info.LastDiagnosis;
            break;
        end
    end

    episodeSteps(caseIndex) = stepIndex;
    if isfield(finalDiagnosis, "captured")
        captured(caseIndex) = finalDiagnosis.captured;
    end
    if isfield(finalDiagnosis, "isUnsafe")
        safetyTerminated(caseIndex) = finalDiagnosis.isUnsafe;
    end
    if isfield(finalDiagnosis, "rawStateUnsafe")
        safetyTerminated(caseIndex) = safetyTerminated(caseIndex) || ...
            finalDiagnosis.rawStateUnsafe;
    end
    if isfield(finalDiagnosis, "timeout")
        timedOut(caseIndex) = finalDiagnosis.timeout;
    end
    if captured(caseIndex)
        captureTime(caseIndex) = stepIndex * caseCfg.Agent.SampleTime;
    end
end

data = cases;
data.EpisodeReward = scores;
data.EpisodeSteps = episodeSteps;
data.Captured = captured;
data.SafetyTerminated = safetyTerminated;
data.TimedOut = timedOut;
data.CaptureTime = captureTime;
data.TrainingEpisode = repmat(trainingInfo.EpisodeIndex, numCases, 1);

% Restore the training agent state before a best checkpoint is saved.
if exist("useExplorationPolicy", "var")
    agent.UseExplorationPolicy = useExplorationPolicy;
end
[statistic, evaluatorState] = localUpdateBestCheckpoint( ...
    agent, data, trainingInfo, cfg);

fprintf("Fixed evaluation at episode %d: capture %d/%d, safety %d, " + ...
    "timeout %d, perfect streak %d/%d.\n", ...
    trainingInfo.EpisodeIndex, sum(captured), numCases, ...
    sum(safetyTerminated), sum(timedOut), ...
    evaluatorState.ConsecutivePerfect, evaluatorState.RequiredConsecutivePerfect);
end

function localRestoreExploration(agent, useExplorationPolicy)
agent.UseExplorationPolicy = useExplorationPolicy;
end

function [statistic, state] = localUpdateBestCheckpoint(agent, data, trainingInfo, cfg)
persistent evaluatorState

runKey = string(cfg.Training.OutputRoot);
requiredPerfect = 1;
if isfield(cfg.Evaluation, "RequiredConsecutivePerfect")
    requiredPerfect = cfg.Evaluation.RequiredConsecutivePerfect;
end

if isempty(evaluatorState) || evaluatorState.RunKey ~= runKey
    evaluatorState = struct( ...
        RunKey=runKey, ...
        BestCaptured=-1, ...
        BestSafety=inf, ...
        BestMeanCaptureTime=inf, ...
        BestEpisode=0, ...
        ConsecutivePerfect=0, ...
        RequiredConsecutivePerfect=requiredPerfect);
end

numCases = height(data);
numCaptured = sum(data.Captured);
numSafety = sum(data.SafetyTerminated);
successfulTimes = data.CaptureTime(data.Captured);
if isempty(successfulTimes)
    meanCaptureTime = inf;
else
    meanCaptureTime = mean(successfulTimes);
end

if numCaptured == numCases
    evaluatorState.ConsecutivePerfect = evaluatorState.ConsecutivePerfect + 1;
else
    evaluatorState.ConsecutivePerfect = 0;
end

isBetter = numCaptured > evaluatorState.BestCaptured || ...
    (numCaptured == evaluatorState.BestCaptured && ...
        numSafety < evaluatorState.BestSafety) || ...
    (numCaptured == evaluatorState.BestCaptured && ...
        numSafety == evaluatorState.BestSafety && ...
        meanCaptureTime < evaluatorState.BestMeanCaptureTime);

if isBetter
    evaluatorState.BestCaptured = numCaptured;
    evaluatorState.BestSafety = numSafety;
    evaluatorState.BestMeanCaptureTime = meanCaptureTime;
    evaluatorState.BestEpisode = trainingInfo.EpisodeIndex;

    evaluationData = data; %#ok<NASGU>
    evaluationSummary = struct( ...
        TrainingEpisode=trainingInfo.EpisodeIndex, ...
        Captured=numCaptured, ...
        NumCases=numCases, ...
        CaptureRate=numCaptured / numCases, ...
        SafetyTerminations=numSafety, ...
        Timeouts=sum(data.TimedOut), ...
        MeanCaptureTime=meanCaptureTime); %#ok<NASGU>
    bestPath = fullfile(cfg.Training.OutputRoot, ...
        "best_fixed_evaluation_agent.mat");
    save(bestPath, "agent", "evaluationData", "evaluationSummary", "cfg");
    fprintf("Saved improved fixed-evaluation checkpoint: %s\n", bestPath);
end

rawCaptureRate = numCaptured / numCases;
if evaluatorState.ConsecutivePerfect >= requiredPerfect
    statistic = 1.0;
elseif rawCaptureRate >= 1.0
    % Prevent StopTrainingValue=1 from firing on the first perfect result.
    statistic = 1.0 - 1 / (100 * requiredPerfect);
else
    statistic = rawCaptureRate;
end

state = evaluatorState;
end
