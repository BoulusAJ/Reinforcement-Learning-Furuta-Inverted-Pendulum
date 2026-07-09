function trainFurutaDirectTD3WithConfig(cfg)
%TRAINFURUTADIRECTTD3WITHCONFIG Train direct TD3 from a prepared config.

scriptDir = fileparts(mfilename("fullpath"));
repoRoot = fileparts(scriptDir);
cd(repoRoot)
addpath(genpath(fullfile(repoRoot, "scripts")))

rng(0, "twister");

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

assignin("base", "curriculumParams", cfg.Training.Reset);
assignin("base", "rewardParams", cfg.Reward);
assignin("base", "safetyParams", cfg.Safety);

agent = createTrainingAgent(obsInfo, actInfo, cfg);
evalCfg = makeFurutaMathWorksStyleEvalConfig(cfg);

prepareRunOutputFolders(cfg);
writeRunConfig(cfg, evalCfg);
diaryCleanup = startTrainingDiary(cfg); %#ok<NASGU>

if cfg.Training.UseParallel
    pool = gcp("nocreate");
    if isempty(pool)
        pool = parpool("Processes", cfg.Training.RequestedWorkers);
    elseif pool.NumWorkers ~= cfg.Training.RequestedWorkers
        warning("trainFurutaDirectTD3WithConfig:ParallelPoolSizeMismatch", ...
            "Using existing pool with %d workers instead of requested %d workers.", ...
            pool.NumWorkers, cfg.Training.RequestedWorkers);
    end
end

trainOpts = rlTrainingOptions( ...
    MaxEpisodes=cfg.Training.MaxEpisodes, ...
    MaxStepsPerEpisode=ceil(cfg.Training.EpisodeDuration / cfg.Agent.SampleTime), ...
    Verbose=cfg.Training.Verbose, ...
    Plots=cfg.Training.PlotMode, ...
    ScoreAveragingWindowLength=cfg.Training.ScoreAveragingWindowLength, ...
    StopTrainingCriteria=cfg.Training.StopTrainingCriteria, ...
    SaveAgentCriteria=cfg.Training.SaveAgentCriteria, ...
    SaveAgentValue=cfg.Training.SaveAgentValue, ...
    SaveAgentDirectory=cfg.Training.SavedAgentDir, ...
    UseParallel=cfg.Training.UseParallel);

if cfg.Training.UseParallel
    trainOpts.ParallelizationOptions.Mode = cfg.Training.ParallelMode;
    trainOpts.ParallelizationOptions.DataToSendFromWorkers = "experiences";
    trainOpts.ParallelizationOptions.StepsUntilDataIsSent = cfg.Training.StepsUntilDataIsSent;
end

trainingStats = train(agent, env, trainOpts);

evalLog = struct();
evalLog.short = [];
evalLog.full = [];

if cfg.Evaluation.UseShortEvaluation
    fprintf("\nRunning short fixed evaluation (%d cases)...\n", height(evalCfg.ShortCases));
    evalLog.short = runFixedEvaluation(agent, obsInfo, actInfo, cfg, evalCfg, ...
        evalCfg.ShortCases, "short_final");
    writeEvaluationTables(evalLog.short, cfg, "short_final");
end

if cfg.Evaluation.UseFullEvaluation
    fprintf("\nRunning full fixed evaluation (%d cases)...\n", height(evalCfg.FullCases));
    evalLog.full = runFixedEvaluation(agent, obsInfo, actInfo, cfg, evalCfg, ...
        evalCfg.FullCases, "full_final");
    writeEvaluationTables(evalLog.full, cfg, "full_final");
end

save(fullfile(cfg.Training.OutputRoot, cfg.Training.FinalSaveName), ...
    "agent", "trainingStats", "cfg", "evalCfg", "evalLog");
end

function result = runFixedEvaluation(agent, obsInfo, actInfo, cfg, evalCfg, cases, evalSetName)
if isfield(cfg.Model, "EvaluationFile")
    load_system(cfg.Model.EvaluationFile);
elseif isfield(evalCfg, "ModelFile")
    load_system(evalCfg.ModelFile);
end
evalEnv = rlSimulinkEnv(evalCfg.ModelName, evalCfg.AgentBlock, obsInfo, actInfo);
evalEnv.ResetFcn = @localResetFcnFurutaCurriculum;
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

function agent = createTrainingAgent(obsInfo, actInfo, cfg)
useInitialAgent = isfield(cfg.Training, "UseInitialAgent") && cfg.Training.UseInitialAgent;

if ~useInitialAgent
    agent = createTD3AgentFuruta(obsInfo, actInfo, cfg.Agent);
    return;
end

initialAgentPath = string(cfg.Training.InitialAgentPath);
if strlength(initialAgentPath) == 0 || ~isfile(initialAgentPath)
    error("trainFurutaDirectTD3WithConfig:InitialAgentNotFound", ...
        "Initial agent file does not exist: %s", initialAgentPath);
end

loadedAgent = load(initialAgentPath, "agent");
if ~isfield(loadedAgent, "agent")
    error("trainFurutaDirectTD3WithConfig:InitialAgentMissingField", ...
        "Initial agent file does not contain a variable named 'agent': %s", initialAgentPath);
end

agent = loadedAgent.agent;
agent = applyAgentOptionsFromConfig(agent, cfg.Agent);
agent = resetInitialAgentExperienceBufferIfRequested(agent, cfg);
end

function agent = applyAgentOptionsFromConfig(agent, agentCfg)
newOptions = createTD3OptionsFuruta(agentCfg);

if isprop(agent, "AgentOptions")
    optionsPropertyName = "AgentOptions";
elseif isprop(agent, "Options")
    optionsPropertyName = "Options";
else
    warning("trainFurutaDirectTD3WithConfig:AgentOptionsPropertyMissing", ...
        "Loaded agent has no public AgentOptions property. Config TD3 options were not reapplied.");
    return;
end

try
    agent.(optionsPropertyName) = newOptions;
    fprintf("Applied TD3 options from cfg to loaded initial agent (%s): ExplorationStd=%.4g, ExplorationStdMin=%.4g, NumWarmStartSteps=%d.\n", ...
        optionsPropertyName, agentCfg.ExplorationNoiseStd, agentCfg.ExplorationNoiseStdMin, agentCfg.NumWarmStartSteps);
catch err
    warning("trainFurutaDirectTD3WithConfig:ApplyLoadedAgentOptionsFailed", ...
        "Could not apply cfg TD3 options to loaded initial agent. MATLAB reported: %s", err.message);
end
end

function agent = resetInitialAgentExperienceBufferIfRequested(agent, cfg)
resetBuffer = isfield(cfg.Training, "ResetInitialAgentExperienceBuffer") && ...
    cfg.Training.ResetInitialAgentExperienceBuffer;

if ~resetBuffer
    return;
end

if ~isprop(agent, "ExperienceBuffer")
    warning("trainFurutaDirectTD3WithConfig:ExperienceBufferPropertyMissing", ...
        "Could not reset initial agent experience buffer because the loaded agent has no public ExperienceBuffer property.");
    return;
end

try
    buffer = agent.ExperienceBuffer;
    if ismethod(buffer, "reset")
        reset(buffer);
        try
            agent.ExperienceBuffer = buffer;
        catch
            % Some MATLAB releases expose a handle-like replay buffer with a
            % protected setter. In that case reset(buffer) is already enough.
        end
        fprintf("Reset initial agent experience buffer using its reset method.\n");
        return;
    end
catch err
    warning("trainFurutaDirectTD3WithConfig:ExperienceBufferResetMethodFailed", ...
        "Could not reset initial agent experience buffer using a reset method: %s", err.message);
end

try
    agent.ExperienceBuffer = [];
    fprintf("Cleared initial agent experience buffer by assigning [].\n");
catch err
    warning("trainFurutaDirectTD3WithConfig:ExperienceBufferClearFailed", ...
        "Could not clear initial agent experience buffer. Training will continue with the loaded buffer. MATLAB reported: %s", err.message);
end
end

function cleanupObj = startTrainingDiary(cfg)
cleanupObj = [];

if ~isfield(cfg.Training, "UseDiary") || ~cfg.Training.UseDiary
    return;
end

diaryPath = fullfile(cfg.Training.OutputRoot, "training_console.log");
diary(diaryPath);
cleanupObj = onCleanup(@() diary("off"));
fprintf("Training console diary: %s\n", diaryPath);
end

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

function modelState = prepareModelForTraining(cfg)
modelName = cfg.Model.Name;

if cfg.Training.RunInBackground
    if isfield(cfg.Model, "TrainingFile")
        load_system(cfg.Model.TrainingFile);
    else
        load_system(modelName);
    end
else
    if isfield(cfg.Model, "TrainingFile")
        open_system(cfg.Model.TrainingFile);
    else
        open_system(modelName);
    end
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
    warning("trainFurutaDirectTD3WithConfig:ScopeDiscoveryFailed", ...
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
writetable(evalCfg.ShortCases, ...
    fullfile(cfg.Training.ConfigDir, "short_eval_cases.csv"));
writetable(evalCfg.FullCases, ...
    fullfile(cfg.Training.ConfigDir, "full_eval_cases.csv"));
end

function writeJson(path, value)
encoded = jsonencode(value, PrettyPrint=true);
fid = fopen(path, "w");
if fid < 0
    error("trainFurutaDirectTD3WithConfig:WriteJsonFailed", ...
        "Could not write JSON file: %s", path);
end
cleanupObj = onCleanup(@() fclose(fid));
fprintf(fid, "%s", encoded);
end

function writeEvaluationTables(evalResult, cfg, evalSetName)
writetable(evalResult.metrics, ...
    fullfile(cfg.Training.EvalDir, evalSetName + "_metrics.csv"));
writetable(evalResult.summary, ...
    fullfile(cfg.Training.EvalDir, evalSetName + "_summary.csv"));
end
