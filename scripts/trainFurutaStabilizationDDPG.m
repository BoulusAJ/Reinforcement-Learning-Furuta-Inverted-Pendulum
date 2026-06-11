%function trainFurutaStabilizationDDPG()
%TRAINFURUTASTABILIZATIONDDPG Train a near-upright Furuta RL controller.
%
% Complete the Simulink model and block names in makeFurutaConfig.m before
% running this script.

cd("C:\Users\abuj\Code\Reinforcement-Learning-Furuta-Inverted-Pendulum")
addpath(genpath("scripts"))

% temp
p = 'C:\GhostLabServer\Ghostlab';
normalize = @(s) regexprep(char(s), '[\\/]+$', '');
entries = cellfun(normalize, strsplit(path, pathsep), 'UniformOutput', false);
if any(strcmpi(entries, normalize(p)))
    rmpath(p)
    rehash toolboxcache
end

cfg = makeFurutaConfig();
initFurutaModelWorkspace(cfg);
modelState = prepareModelForTraining(cfg);
cleanupModel = onCleanup(@() restoreTrainingModel(cfg.Model.Name, modelState));

obsInfo = rlNumericSpec([cfg.Observation.Dimension 1], Name="observations");
actInfo = rlNumericSpec([1 1], ...
    LowerLimit=cfg.Action.Min, ...
    UpperLimit=cfg.Action.Max, ...
    Name=cfg.Action.Name);

env = rlSimulinkEnv(cfg.Model.TrainingName, cfg.Model.TrainingAgentBlock, obsInfo, actInfo);
env.ResetFcn = @localResetFcnFurutaCurriculum;

agent = createFurutaAgent(obsInfo, actInfo, cfg);
evalCfg = makeFurutaEvalConfig(cfg);
evalLog = struct();
evalLog.postStage = [];

prepareRunOutputFolders(cfg);
writeRunConfig(cfg, evalCfg);

if cfg.Training.UseParallel
    pool = gcp("nocreate");
    if isempty(pool)
        pool = parpool("Processes", cfg.Training.RequestedWorkers);
    elseif pool.NumWorkers ~= cfg.Training.RequestedWorkers
        warning("trainFurutaStabilizationDDPG:ParallelPoolSizeMismatch", ...
            "Using existing pool with %d workers instead of requested %d workers.", ...
            pool.NumWorkers, cfg.Training.RequestedWorkers);
    end
end

for k = 1:numel(cfg.Curriculum)
    stage = cfg.Curriculum(k);
    assignin("base", "curriculumParams", stage.Reset);
    assignin("base", "rewardParams", cfg.Reward);
    assignin("base", "safetyParams", cfg.Safety);

    agent = setStageExplorationNoise(agent, stage.NoiseStd);

    trainOpts = rlTrainingOptions( ...
        MaxEpisodes=stage.MaxEpisodes, ...
        MaxStepsPerEpisode=ceil(cfg.Training.EpisodeDuration / cfg.Agent.SampleTime), ...
        Verbose=cfg.Training.Verbose, ...
        Plots=cfg.Training.PlotMode, ...
        ScoreAveragingWindowLength=cfg.Training.ScoreAveragingWindowLength, ...
        StopTrainingCriteria=cfg.Training.StopTrainingCriteria, ...
        StopTrainingValue=cfg.Training.StopTrainingValue, ...
        SaveAgentCriteria="EpisodeReward", ...
        SaveAgentValue=cfg.Training.StopTrainingValue, ...
        SaveAgentDirectory=cfg.Training.SavedAgentDir, ...
        UseParallel=cfg.Training.UseParallel);

    if cfg.Training.UseParallel
        trainOpts.ParallelizationOptions.Mode = cfg.Training.ParallelMode;
        trainOpts.ParallelizationOptions.DataToSendFromWorkers = "experiences";
        trainOpts.ParallelizationOptions.StepsUntilDataIsSent = cfg.Training.StepsUntilDataIsSent;
    end

    trainingStats = train(agent, env, trainOpts);

    postStageEval = [];
    if cfg.Evaluation.UsePostStageEvaluation
        fprintf("\nRunning post-stage evaluation for Stage %d: %s\n", k, stage.Name);
        evalEnv = rlSimulinkEnv(evalCfg.ModelName, evalCfg.AgentBlock, obsInfo, actInfo);
        evalEnv.ResetFcn = @localResetFcnFurutaCurriculum;
        postStageEval = evaluateFurutaController( ...
            agent, evalEnv, evalCfg.PostStageCases, evalCfg, ...
            "ControllerName", cfg.Agent.Algorithm, ...
            "EvalSetName", "post_stage_full", ...
            "StageIndex", k, ...
            "StageName", stage.Name, ...
            "RunInBackground", true, ...
            "UseFastRestart", cfg.Training.UseFastRestart, ...
            "UseParallel", cfg.Training.UseParallel, ...
            "RequestedWorkers", cfg.Training.RequestedWorkers, ...
            "AllowPoolRestart", false);
        evalLog.postStage = [evalLog.postStage; postStageEval.summary];
        writeEvaluationTables(postStageEval, cfg, k, stage.Name);
    end

    save(fullfile(cfg.Training.StageDir, ...
        sprintf("%s_stage_%02d_%s.mat", cfg.Training.SavePrefix, k, stage.Name)), ...
        "agent", "stage", "trainingStats", "postStageEval", "evalCfg", "cfg");
end

save(fullfile(cfg.Training.OutputRoot, cfg.Training.FinalSaveName), ...
    "agent", "cfg", "evalCfg", "evalLog");
%end

function prepareRunOutputFolders(cfg)
folders = [
    cfg.Training.ResultsDir
    cfg.Training.OutputRoot
    cfg.Training.StageDir
    cfg.Training.EvalDir
    cfg.Training.ConfigDir
    cfg.Training.SavedAgentDir
    ];

for i = 1:numel(folders)
    if ~isfolder(folders(i))
        mkdir(folders(i));
    end
end
end

function agent = createFurutaAgent(obsInfo, actInfo, cfg)
switch upper(string(cfg.Agent.Algorithm))
    case "DDPG"
        agent = createDDPGAgentFuruta(obsInfo, actInfo, cfg.Agent);
    case "TD3"
        agent = createTD3AgentFuruta(obsInfo, actInfo, cfg.Agent);
    otherwise
        error("trainFurutaStabilization:UnsupportedAgent", ...
            "Unsupported agent algorithm: %s", cfg.Agent.Algorithm);
end
end

function agent = setStageExplorationNoise(agent, noiseStd)
if isprop(agent.AgentOptions, "NoiseOptions")
    agent.AgentOptions.NoiseOptions.StandardDeviation = noiseStd;
elseif isprop(agent.AgentOptions, "ExplorationModel")
    agent.AgentOptions.ExplorationModel.StandardDeviation = noiseStd;
else
    warning("trainFurutaStabilization:UnsupportedNoiseOptions", ...
        "Could not set stage exploration noise for this agent type.");
end
end

function modelState = prepareModelForTraining(cfg)
modelName = cfg.Model.Name;

if cfg.Training.RunInBackground
    load_system(modelName);
else
    open_system(modelName);
end

modelState = struct();
modelState.oldFastRestart = get_param(modelName, "FastRestart");
modelState.oldSignalLogging = get_param(modelName, "SignalLogging");
modelState.oldSignalLoggingName = get_param(modelName, "SignalLoggingName");

if strcmp(modelState.oldFastRestart, "on")
    set_param(modelName, FastRestart="off");
end

if cfg.Training.DisableSignalLogging
    set_param(modelName, SignalLogging="off");
end

if cfg.Training.DisableScopes
    disableScopeViewers(modelName);
end

if cfg.Training.UseFastRestart
    set_param(modelName, FastRestart="on");
end
end

function disableScopeViewers(modelName)
try
    scopes = find_system(modelName, ...
        LookUnderMasks="all", ...
        FollowLinks="on", ...
        BlockType="Scope");
catch err
    warning("trainFurutaStabilization:ScopeDiscoveryFailed", ...
        "Could not discover Scope blocks before training: %s", err.message);
    return;
end

for idx = 1:numel(scopes)
    scope = scopes{idx};
    try
        close_system(scope);
    catch
    end
    try
        set_param(scope, OpenAtSimulationStart="off");
    catch
    end
end
end

function restoreTrainingModel(modelName, modelState)
if bdIsLoaded(modelName)
    set_param(modelName, FastRestart="off");
    set_param(modelName, SignalLogging=modelState.oldSignalLogging);
    set_param(modelName, SignalLoggingName=modelState.oldSignalLoggingName);
    set_param(modelName, FastRestart=modelState.oldFastRestart);
end
end

function writeRunConfig(cfg, evalCfg)
cfgPath = fullfile(cfg.Training.ConfigDir, "run_config.json");
evalCfgPath = fullfile(cfg.Training.ConfigDir, "eval_config.mat");

writeJson(cfgPath, cfg);
save(evalCfgPath, "evalCfg");
writetable(evalCfg.TrainingCases, ...
    fullfile(cfg.Training.ConfigDir, "training_eval_cases.csv"));
writetable(evalCfg.PostStageCases, ...
    fullfile(cfg.Training.ConfigDir, "post_stage_eval_cases.csv"));
end

function writeJson(path, value)
encoded = jsonencode(value, PrettyPrint=true);
fid = fopen(path, "w");
if fid < 0
    error("trainFurutaStabilizationDDPG:WriteJsonFailed", ...
        "Could not write JSON file: %s", path);
end
cleanupObj = onCleanup(@() fclose(fid));
fprintf(fid, "%s", encoded);
end

function writeEvaluationTables(postStageEval, cfg, stageIndex, stageName)
safeStageName = matlab.lang.makeValidName(stageName);
prefix = sprintf("stage_%02d_%s", stageIndex, safeStageName);

writetable(postStageEval.metrics, ...
    fullfile(cfg.Training.EvalDir, prefix + "_metrics.csv"));
writetable(postStageEval.summary, ...
    fullfile(cfg.Training.EvalDir, prefix + "_summary.csv"));
end
