function finalPath = finalizeFurutaDirectTD3Run(runDir, options)
%FINALIZEFURUTADIRECTTD3RUN Run final evaluations for a completed TD3 run.
%
% Use this when training completed and saved an agent checkpoint, but the final
% post-training evaluation/save step failed.
%
% Example:
%   finalizeFurutaDirectTD3Run(fullfile("results", "TD3", ...
%       "run_20260616_233822_td3_mathworks_style_voltage"));

arguments
    runDir {mustBeTextScalar}
    options.AgentFile {mustBeTextScalar} = ""
    options.RunShortEvaluation (1,1) logical = true
    options.RunFullEvaluation (1,1) logical = true
    options.EvaluationModelName {mustBeTextScalar} = ""
    options.EvaluationAgentBlock {mustBeTextScalar} = ""
    options.EvaluationOutputDir {mustBeTextScalar} = ""
    options.SaveFinalMat (1,1) logical = true
end

runDir = string(runDir);
configPath = fullfile(runDir, "config", "run_config.json");
evalConfigPath = fullfile(runDir, "config", "eval_config.mat");

if ~isfile(configPath)
    error("finalizeFurutaDirectTD3Run:MissingConfig", ...
        "Missing run config: %s", configPath);
end

cfg = jsondecode(fileread(configPath));
cfg = normalizeRunConfig(cfg, runDir);

if isfile(evalConfigPath)
    S = load(evalConfigPath, "evalCfg");
    evalCfg = S.evalCfg;
else
    evalCfg = makeFurutaMathWorksStyleEvalConfig(cfg);
end

[cfg, evalCfg] = applyEvaluationOverrides(cfg, evalCfg, options);

agentPath = resolveAgentPath(runDir, options.AgentFile);
agentData = load(agentPath, "saved_agent");
if isfield(agentData, "saved_agent")
    agent = agentData.saved_agent;
else
    agentData = load(agentPath, "agent");
    agent = agentData.agent;
end

initFurutaModelWorkspace(cfg);
assignin("base", "rewardParams", cfg.Reward);
assignin("base", "safetyParams", cfg.Safety);

obsInfo = rlNumericSpec([cfg.Observation.Dimension 1], Name="observations");
actInfo = rlNumericSpec([1 1], ...
    LowerLimit=cfg.Action.Min, ...
    UpperLimit=cfg.Action.Max, ...
    Name=cfg.Action.Name);

if isfield(evalCfg, "ModelFile") && strlength(string(evalCfg.ModelFile)) > 0
    load_system(evalCfg.ModelFile);
end
evalEnv = rlSimulinkEnv(evalCfg.ModelName, evalCfg.AgentBlock, obsInfo, actInfo);
evalEnv.ResetFcn = @localResetFcnFurutaCurriculum;

evalLog = loadExistingEvaluationLog(cfg);

if options.RunShortEvaluation
    fprintf("\nRunning short fixed evaluation (%d cases)...\n", height(evalCfg.ShortCases));
    evalLog.short = evaluateFinalCases(agent, evalEnv, evalCfg.ShortCases, cfg, evalCfg, "short_final");
    writeEvaluationTables(evalLog.short, cfg, "short_final");
end

if options.RunFullEvaluation
    fprintf("\nRunning full fixed evaluation (%d cases)...\n", height(evalCfg.FullCases));
    evalLog.full = evaluateFinalCases(agent, evalEnv, evalCfg.FullCases, cfg, evalCfg, "full_final");
    writeEvaluationTables(evalLog.full, cfg, "full_final");
end

trainingStats = [];
finalPath = fullfile(cfg.Training.OutputRoot, cfg.Training.FinalSaveName);
if options.SaveFinalMat
    save(finalPath, "agent", "trainingStats", "cfg", "evalCfg", "evalLog", "agentPath");
    fprintf("Saved finalized run to %s\n", finalPath);
else
    finalPath = "";
end
end

function result = evaluateFinalCases(agent, evalEnv, cases, cfg, evalCfg, evalSetName)
result = evaluateFurutaController( ...
    agent, evalEnv, cases, evalCfg, ...
    "ControllerName", cfg.Agent.Algorithm, ...
    "EvalSetName", evalSetName, ...
    "StageIndex", NaN, ...
    "StageName", "mathworks_style_single_run", ...
    "RunInBackground", true, ...
    "UseFastRestart", false, ...
    "UseParallel", cfg.Evaluation.UseParallel, ...
    "RequestedWorkers", cfg.Evaluation.RequestedWorkers, ...
    "AllowPoolRestart", cfg.Evaluation.AllowPoolRestart);
end

function writeEvaluationTables(evalResult, cfg, evalSetName)
if ~isfolder(cfg.Training.EvalDir)
    mkdir(cfg.Training.EvalDir);
end

writetable(evalResult.metrics, ...
    fullfile(cfg.Training.EvalDir, evalSetName + "_metrics.csv"));
writetable(evalResult.summary, ...
    fullfile(cfg.Training.EvalDir, evalSetName + "_summary.csv"));
end

function evalLog = loadExistingEvaluationLog(cfg)
evalLog = struct();
evalLog.short = loadEvaluationTablesIfPresent(cfg, "short_final");
evalLog.full = loadEvaluationTablesIfPresent(cfg, "full_final");
end

function [cfg, evalCfg] = applyEvaluationOverrides(cfg, evalCfg, options)
if strlength(string(options.EvaluationModelName)) > 0
    evalCfg.ModelName = string(options.EvaluationModelName);
    cfg.Model.EvaluationName = evalCfg.ModelName;
end

if strlength(string(options.EvaluationAgentBlock)) > 0
    evalCfg.AgentBlock = string(options.EvaluationAgentBlock);
    cfg.Model.EvaluationAgentBlock = evalCfg.AgentBlock;
elseif strlength(string(options.EvaluationModelName)) > 0
    evalCfg.AgentBlock = evalCfg.ModelName + "/RL Agent";
    cfg.Model.EvaluationAgentBlock = evalCfg.AgentBlock;
end

if strlength(string(options.EvaluationOutputDir)) > 0
    cfg.Training.EvalDir = string(options.EvaluationOutputDir);
end
end

function evalResult = loadEvaluationTablesIfPresent(cfg, evalSetName)
evalResult = [];
metricsPath = fullfile(cfg.Training.EvalDir, evalSetName + "_metrics.csv");
summaryPath = fullfile(cfg.Training.EvalDir, evalSetName + "_summary.csv");

if isfile(metricsPath) && isfile(summaryPath)
    evalResult = struct( ...
        "metrics", readtable(metricsPath), ...
        "summary", readtable(summaryPath));
end
end

function agentPath = resolveAgentPath(runDir, agentFile)
if strlength(string(agentFile)) > 0
    agentPath = fullfile(runDir, "saved_agents", string(agentFile));
    if ~isfile(agentPath)
        agentPath = fullfile(runDir, string(agentFile));
    end
    if ~isfile(agentPath)
        error("finalizeFurutaDirectTD3Run:AgentFileNotFound", ...
            "Could not find requested agent file: %s", agentFile);
    end
    return;
end

agentFiles = dir(fullfile(runDir, "saved_agents", "Agent*.mat"));
if isempty(agentFiles)
    error("finalizeFurutaDirectTD3Run:NoSavedAgents", ...
        "No saved Agent*.mat files found under %s", fullfile(runDir, "saved_agents"));
end

episodes = zeros(numel(agentFiles), 1);
for idx = 1:numel(agentFiles)
    token = regexp(agentFiles(idx).name, "Agent(\d+)\.mat", "tokens", "once");
    if ~isempty(token)
        episodes(idx) = str2double(token{1});
    end
end

[~, bestIdx] = max(episodes);
agentPath = fullfile(agentFiles(bestIdx).folder, agentFiles(bestIdx).name);
end

function cfg = normalizeRunConfig(cfg, runDir)
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
