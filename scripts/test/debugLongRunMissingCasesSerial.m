%% Serial debug for long-run full-evaluation cases that hung in parfor
% Run this after training if full parallel evaluation stalls. It evaluates
% selected case IDs one-by-one, prints timing, and writes partial results
% after every completed case.

scriptDir = fileparts(mfilename("fullpath"));
repoRoot = fileparts(fileparts(scriptDir));
cd(repoRoot)
addpath(genpath(fullfile(repoRoot, "scripts")))

runDir = fullfile("results", "TD3", ...
    "run_20260618_223832_td3_mathworks_style_pi_current_1b_500hz_long");
agentFile = "Agent5000.mat";
caseIDs = [13 15 95 96 97 98 99 100 107 108 109 110 111];

outputDir = fullfile(runDir, "analysis", "missing_cases_serial_debug");
if ~isfolder(outputDir)
    mkdir(outputDir);
end

cfg = jsondecode(fileread(fullfile(runDir, "config", "run_config.json")));
cfg = normalizeLoadedConfig(cfg, runDir);
S = load(fullfile(runDir, "config", "eval_config.mat"), "evalCfg");
evalCfg = S.evalCfg;

agentPath = fullfile(runDir, "saved_agents", agentFile);
A = load(agentPath);
if isfield(A, "saved_agent")
    agent = A.saved_agent;
elseif isfield(A, "agent")
    agent = A.agent;
else
    error("debugLongRunMissingCasesSerial:MissingAgent", ...
        "Agent file does not contain saved_agent or agent: %s", agentPath);
end

initFurutaModelWorkspace(cfg);
assignin("base", "agent", agent);
assignin("base", "cfg", cfg);
assignin("base", "rewardParams", cfg.Reward);
assignin("base", "safetyParams", cfg.Safety);

if isfield(evalCfg, "ModelFile") && strlength(string(evalCfg.ModelFile)) > 0
    load_system(evalCfg.ModelFile);
else
    load_system(evalCfg.ModelName);
end

allCases = readtable(fullfile(runDir, "config", "full_eval_cases.csv"));
cases = allCases(ismember(allCases.CaseID, caseIDs), :);

obsInfo = rlNumericSpec([cfg.Observation.Dimension 1], Name="observations");
actInfo = rlNumericSpec([1 1], ...
    LowerLimit=cfg.Action.Min, ...
    UpperLimit=cfg.Action.Max, ...
    Name=cfg.Action.Name);

env = rlSimulinkEnv(evalCfg.ModelName, evalCfg.AgentBlock, obsInfo, actInfo);
env.ResetFcn = @localResetFcnFurutaCurriculum;

simOpts = rlSimulationOptions( ...
    MaxSteps=evalCfg.MaxSteps, ...
    StopOnError="on");

metricsPath = fullfile(outputDir, "missing_cases_serial_metrics.csv");
timingPath = fullfile(outputDir, "missing_cases_serial_timing.csv");

allMetrics = table();
timingRows = table();

fprintf("Serial debugging %d cases from %s\n", height(cases), runDir);
fprintf("Writing partial results to %s\n\n", outputDir);

for idx = 1:height(cases)
    caseRow = cases(idx, :);
    fprintf("[%s] Starting CaseID %d (%d/%d)\n", ...
        string(datetime("now")), caseRow.CaseID, idx, height(cases));

    elapsedSeconds = NaN;
    status = "failed";
    message = "";
    tStart = tic;

    try
        assignin("base", "curriculumParams", makeFixedReset(caseRow));
        assignin("base", "rewardParams", evalCfg.Reward);
        assignin("base", "safetyParams", evalCfg.Safety);
        env.ResetFcn = @localResetFcnFurutaCurriculum;

        experiences = sim(env, agent, simOpts);

        elapsedSeconds = toc(tStart);
        status = "completed";
        caseMetrics = computeFurutaMetrics(experiences, caseRow, evalCfg);
        caseMetrics.ControllerName = "TD3";
        caseMetrics.EvalSetName(:) = "missing_cases_serial_debug";
        caseMetrics.StageIndex = NaN;
        caseMetrics.StageName = "long_run_missing_case_debug";
        caseMetrics.TrainingEpisode = NaN;
        caseMetrics.EvaluatedAt = datetime("now");
        caseMetrics.ElapsedWallSeconds = elapsedSeconds;
        allMetrics = [allMetrics; caseMetrics]; %#ok<AGROW>
        writetable(allMetrics, metricsPath);

        fprintf("[%s] Finished CaseID %d in %.2f s, terminated=%d, failed=%d\n\n", ...
            string(datetime("now")), caseRow.CaseID, elapsedSeconds, ...
            caseMetrics.Terminated, caseMetrics.Failed);
    catch err
        elapsedSeconds = toc(tStart);
        status = "error";
        message = string(getReport(err, "extended", "hyperlinks", "off"));
        fprintf(2, "[%s] CaseID %d errored after %.2f s: %s\n\n", ...
            string(datetime("now")), caseRow.CaseID, elapsedSeconds, err.message);
    end

    timingRow = table( ...
        caseRow.CaseID, ...
        caseRow.Theta1Error0, caseRow.Theta2Error0, ...
        caseRow.Omega1Error0, caseRow.Omega2Error0, ...
        string(status), string(message), elapsedSeconds, datetime("now"), ...
        'VariableNames', [ ...
            "CaseID", ...
            "Theta1Error0", "Theta2Error0", ...
            "Omega1Error0", "Omega2Error0", ...
            "Status", "Message", "ElapsedWallSeconds", "FinishedAt"]);
    timingRows = [timingRows; timingRow]; %#ok<AGROW>
    writetable(timingRows, timingPath);
end

fprintf("Done. Completed %d/%d cases.\n", height(allMetrics), height(cases));

function fixedReset = makeFixedReset(caseRow)
fixedReset = struct();
fixedReset.mode = "fixed";
fixedReset.Theta1Error0 = caseRow.Theta1Error0;
fixedReset.Theta2Error0 = caseRow.Theta2Error0;
fixedReset.Omega1Error0 = caseRow.Omega1Error0;
fixedReset.Omega2Error0 = caseRow.Omega2Error0;
end

function cfg = normalizeLoadedConfig(cfg, runDir)
runDir = string(runDir);
cfg.ProjectRoot = string(cfg.ProjectRoot);

cfg.Model.TrainingName = string(cfg.Model.TrainingName);
cfg.Model.EvaluationName = string(cfg.Model.EvaluationName);
cfg.Model.Name = string(cfg.Model.Name);
if isfield(cfg.Model, "TrainingFile")
    cfg.Model.TrainingFile = string(cfg.Model.TrainingFile);
end
if isfield(cfg.Model, "EvaluationFile")
    cfg.Model.EvaluationFile = string(cfg.Model.EvaluationFile);
end
cfg.Model.TrainingAgentBlock = string(cfg.Model.TrainingAgentBlock);
cfg.Model.EvaluationAgentBlock = string(cfg.Model.EvaluationAgentBlock);
cfg.Model.AgentBlock = string(cfg.Model.AgentBlock);

cfg.Action.Name = string(cfg.Action.Name);
cfg.Action.PhysicalInterface = string(cfg.Action.PhysicalInterface);
cfg.Agent.Algorithm = string(cfg.Agent.Algorithm);

cfg.Training.SavePrefix = string(cfg.Training.SavePrefix);
cfg.Training.RunName = string(cfg.Training.RunName);
cfg.Training.ResultsDir = string(cfg.Training.ResultsDir);
cfg.Training.OutputRoot = runDir;
cfg.Training.StageDir = fullfile(runDir, "stages");
cfg.Training.EvalDir = fullfile(runDir, "evaluation");
cfg.Training.ConfigDir = fullfile(runDir, "config");
cfg.Training.SavedAgentDir = fullfile(runDir, "saved_agents");
cfg.Training.FinalSaveName = string(cfg.Training.FinalSaveName);
cfg.Training.StopTrainingCriteria = string(cfg.Training.StopTrainingCriteria);
cfg.Training.SaveAgentCriteria = string(cfg.Training.SaveAgentCriteria);
cfg.Training.ParallelMode = string(cfg.Training.ParallelMode);
cfg.Training.Reset.Name = string(cfg.Training.Reset.Name);
end
